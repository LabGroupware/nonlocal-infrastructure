locals {
  cert_manager_repository = "https://charts.jetstack.io"
  cert_manager_namespace  = "cert-manager"
}

############################################
# IAM Role for Cert Manager
############################################
data "aws_iam_policy_document" "cert_manager_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values = [
        "system:serviceaccount:${local.cert_manager_namespace}:cert-manager"
      ]
    }

    principals {
      identifiers = [module.eks.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "cert_manager_role" {
  assume_role_policy = data.aws_iam_policy_document.cert_manager_role.json
  name               = format("%s-cert-manager", var.cluster_name)
  path               = local.iam_role_path
}

data "aws_iam_policy_document" "cert_manager_policy" {
  version = "2012-10-17"

  statement {
    effect = "Allow"
    actions = [
      "route53:GetChange",
    ]

    resources = [
      "arn:aws:route53:::change/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:ListResourceRecordSets"
    ]

    resources = [
      "arn:aws:route53:::hostedzone/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "route53:ListHostedZonesByName"
    ]
    resources = [
      "*"
    ]
  }
}

resource "aws_iam_policy" "cert_manager_policy" {
  name        = format("%s-cert-manager", var.cluster_name)
  path        = local.iam_role_path
  description = var.cluster_name

  policy = data.aws_iam_policy_document.cert_manager_policy.json
}

resource "aws_iam_policy_attachment" "cert_manager_policy" {
  name = format("%s-cert-manager", var.cluster_name)
  roles = [
    aws_iam_role.cert_manager_role.name
  ]

  policy_arn = aws_iam_policy.cert_manager_policy.arn
}

############################################
# Helm Chart for Cert Manager
############################################
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  chart            = "cert-manager"
  repository       = local.cert_manager_repository
  namespace        = local.cert_manager_namespace
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "cert-manager"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.cert_manager_role.arn
  }

  depends_on = [
    module.eks
  ]
}

resource "kubectl_manifest" "cluster_issuer" {

  yaml_body = <<YAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-issuer
spec:
  acme:
    email: ${var.admin_email}
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-issuer
    solvers:
    - selector:
        dnsZones:
          - ${var.route53_zone_domain_name}
      dns01:
        route53: {}
YAML

  depends_on = [
    module.eks,
    helm_release.cert_manager
  ]
}
