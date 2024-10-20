locals {
  secrets_store_csi_driver_repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  secret_store_namespace              = "secret-store"
}

############################################
# Helm
############################################
resource "helm_release" "secrets-store-csi-driver" {
  name       = "secrets-store-csi-driver"
  repository = local.secrets_store_csi_driver_repository
  chart      = "secrets-store-csi-driver"
  version    = var.secret_stores_csi_version
  namespace  = "kube-system"
  timeout    = 10 * 60

  set {
    name  = "syncSecret.enabled"
    value = "true"
  }

  set {
    name  = "enableSecretRotation"
    value = "true"
  }

  set {
    name  = "rotationPollInterval"
    value = "3600s"
  }
}

############################################
# AWS Provider For Secrets Manager, Parameter Store
############################################
data "kubectl_file_documents" "aws-secrets-manager" {
  content = file("${var.helm_dir}/secret-csi/aws-provider-installer.yml")
}

resource "kubectl_manifest" "aws-secrets-manager" {
  for_each  = data.kubectl_file_documents.aws-secrets-manager.manifests
  yaml_body = each.value
}

############################################
# IAM Role for Secrets Store
############################################
data "aws_iam_policy_document" "secrets_csi_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      # values   = [for sa in var.namespace_service_accounts : "system:serviceaccount:${sa}"]
      values   = ["system:serviceaccount:${local.secret_store_namespace}:secrets-csi-role"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    principals {
      identifiers = [module.eks.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

# Role
resource "aws_iam_role" "secrets_csi" {
  assume_role_policy = data.aws_iam_policy_document.secrets_csi_assume_role_policy.json
  name               = "secrets-csi-role"
}

# Policy
resource "aws_iam_policy" "secrets_csi" {
  name = "secrets-csi-policy"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = ["${data.aws_secretsmanager_secret.secrets_csi.arn}"]
    }]
  })
}

data "aws_secretsmanager_secret" "secrets_csi" {
  name = "<SECRET-NAME>"
}

# Policy Attachment
resource "aws_iam_role_policy_attachment" "secrets_csi" {
  policy_arn = aws_iam_policy.secrets_csi.arn
  role       = aws_iam_role.secrets_csi.name
}

# Service Account
resource "kubectl_manifest" "secrets_csi_sa" {
  yaml_body = <<YAML
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-service-account
  namespace: my-namespace
  annotations:
    eks.amazonaws.com/role-arn: ${aws_iam_role.secrets_csi.arn}
YAML

  depends_on = [kubernetes_namespace.my-namespace]
}
