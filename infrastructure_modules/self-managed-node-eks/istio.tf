# ELB -> Istio Ingress

locals {
  ##############################################
  # ELB
  ##############################################
  lb_ssl_policy               = "ELBSecurityPolicy-2016-08"
  lb_target_group_status_port = 30021
  # lb_target_group_http_port   = 30080
  lb_target_group_https_port = 30443

  ##############################################
  # AWS LB Controller
  ##############################################
  eks_repository = "https://aws.github.io/eks-charts"

  ##############################################
  # Private Certificate Secret
  ##############################################
  cert_secret_name = "tls-secret"

  ##############################################
  # Istio
  ##############################################
  istio_namespace  = "istio-system"
  istio_repository = "https://istio-release.storage.googleapis.com/charts"

  ##############################################
  # Kiali
  ##############################################
  kiali_repository = "https://kiali.org/helm-charts"
}

##############################################
# Route53 + ACM
##############################################
data "aws_route53_zone" "route53_zone" {
  name = var.route53_zone_domain_name
}

resource "aws_acm_certificate" "public" {
  domain_name               = var.acm_domain_name
  subject_alternative_names = var.subject_alternative_names
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.public.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  type            = each.value.type
  ttl             = var.aws_route53_record_ttl

  zone_id = data.aws_route53_zone.route53_zone.id

  depends_on = [aws_acm_certificate.public]
}

resource "aws_acm_certificate_validation" "cert_valid" {
  certificate_arn         = aws_acm_certificate.public.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

##############################################
# ELB
##############################################
resource "aws_lb" "ingress" {
  name     = var.cluster_name
  internal = var.lb_ingress_internal
  # load_balancer_type = "network"

  subnets = var.lb_subnet_ids
  security_groups = [
    var.lb_security_group_id
  ]
  enable_deletion_protection = false

  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# resource "aws_lb_target_group" "http" {
#   name              = format("%s-http", var.cluster_name)
#   port              = local.lb_target_group_http_port
#   protocol          = "TCP"
#   vpc_id            = var.vpc_id
#   proxy_protocol_v2 = var.proxy_protocol_v2
# }

resource "aws_lb_target_group" "https" {
  name              = format("%s-https", var.cluster_name)
  port              = local.lb_target_group_https_port
  protocol          = "HTTPS"
  vpc_id            = var.vpc_id
  proxy_protocol_v2 = var.proxy_protocol_v2

  health_check {
    enabled             = true
    interval            = 30
    matcher             = "200"
    path                = "/health/ready"
    port                = local.lb_target_group_status_port
    protocol            = "HTTPS"
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "ingress_443" {
  load_balancer_arn = aws_lb.ingress.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.public.arn
  ssl_policy        = local.lb_ssl_policy

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.https.arn
  }
}

resource "aws_lb_listener" "ingress_80" {
  load_balancer_arn = aws_lb.ingress.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_api_gateway_vpc_link" "lb" {
  count = var.enable_vpc_link ? 1 : 0

  name        = var.cluster_name
  description = var.cluster_name
  target_arns = [
    aws_lb.ingress.arn
  ]
}

##############################################
# DNS
##############################################

resource "aws_route53_record" "public_root" {
  zone_id = data.aws_route53_zone.route53_zone.zone_id
  name    = var.public_root_domain_name
  type    = "A"

  alias {
    name                   = aws_lb.ingress.dns_name
    zone_id                = aws_lb.ingress.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "public_sub" {
  zone_id = data.aws_route53_zone.route53_zone.zone_id
  name    = "*.${var.public_root_domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.ingress.dns_name
    zone_id                = aws_lb.ingress.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_zone" "private" {
  name = var.cluster_private_zone

  vpc {
    vpc_id = var.vpc_id
  }
}

resource "aws_route53_record" "lb" {
  zone_id = aws_route53_zone.private.zone_id
  name    = format("*.%s", var.cluster_private_zone)
  type    = "CNAME"
  ttl     = 30
  records = [aws_lb.ingress.dns_name]
}

##############################################
# IAM For AWS LB Controller
##############################################
data "aws_iam_policy_document" "aws_load_balancer_controller_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    principals {
      identifiers = [module.eks.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "alb_controller" {
  assume_role_policy = data.aws_iam_policy_document.aws_load_balancer_controller_assume_role.json
  name               = format("%s-alb-controller", var.cluster_name)
  path               = local.iam_role_path
}

data "aws_iam_policy_document" "aws_load_balancer_controller_policy" {
  version = "2012-10-17"

  statement {
    effect = "Allow"
    actions = [
      "iam:CreateServiceLinkedRole",
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAddresses",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeVpcs",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeInstances",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeTags",
      "ec2:GetCoipPoolUsage",
      "ec2:DescribeCoipPools",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeListenerCertificates",
      "elasticloadbalancing:DescribeSSLPolicies",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:DescribeTags",
      "elasticloadbalancing:SetWebAcl",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:AddListenerCertificates",
      "elasticloadbalancing:RemoveListenerCertificates",
      "elasticloadbalancing:ModifyRule"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets"
    ]
    resources = [
      "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags"
    ]
    resources = [
      "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
      "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
      "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
      "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
    ]
  }
}

resource "aws_iam_policy" "aws_load_balancer_controller_policy" {
  name        = format("%s-alb-controller-policy", var.cluster_name)
  path        = "/"
  description = var.cluster_name

  policy = data.aws_iam_policy_document.aws_load_balancer_controller_policy.json
}

resource "aws_iam_policy_attachment" "aws_load_balancer_controller_policy" {
  name = "aws_load_balancer_controller_policy"

  roles = [aws_iam_role.alb_controller.name]

  policy_arn = aws_iam_policy.aws_load_balancer_controller_policy.arn
}

##############################################
# AWS LB Controller
##############################################
resource "helm_release" "alb_ingress_controller" {
  name             = "aws-load-balancer-controller"
  repository       = local.eks_repository
  chart            = "aws-load-balancer-controller"
  namespace        = "kube-system"
  create_namespace = true

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = true
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.alb_controller.arn
  }

  set {
    name  = "region"
    value = var.region
  }


  set {
    name  = "vpcId"
    value = var.vpc_id

  }

  depends_on = [
    module.eks
  ]
}

##############################################
# Istio
##############################################

resource "helm_release" "istio_base" {
  name             = "istio-base"
  chart            = "base"
  repository       = local.istio_repository
  namespace        = local.istio_namespace
  create_namespace = true

  version = var.istio_version

  depends_on = [
    module.eks,
    helm_release.alb_ingress_controller
  ]
}

resource "helm_release" "istiod" {
  name             = "istio"
  chart            = "istiod"
  repository       = local.istio_repository
  namespace        = local.istio_namespace
  create_namespace = true

  version = var.istio_version

  depends_on = [
    module.eks,
    helm_release.istio_base
  ]
}

##############################################
# Self Signed Certificate
##############################################
resource "tls_private_key" "ca_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# CA証明書の作成
resource "tls_self_signed_cert" "ca_cert" {
  allowed_uses    = ["cert_signing", "key_encipherment", "digital_signature"]
  private_key_pem = tls_private_key.ca_key.private_key_pem
  subject {
    common_name  = var.public_root_domain_name
    organization = var.cluster_name
  }

  validity_period_hours = 365 * 24
  is_ca_certificate     = true
}

# ドメインの秘密鍵
resource "tls_private_key" "domain_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# ドメイン証明書の署名要求 (CSR) を生成
resource "tls_cert_request" "domain_csr" {
  private_key_pem = tls_private_key.domain_key.private_key_pem

  subject {
    common_name  = var.public_root_domain_name
    organization = var.cluster_name
  }

  dns_names = [
    var.public_root_domain_name,
    "*.${var.public_root_domain_name}"
  ]
}

# ドメイン証明書をCAで署名
resource "tls_locally_signed_cert" "signed_domain_cert" {
  cert_request_pem   = tls_cert_request.domain_csr.cert_request_pem
  ca_cert_pem        = tls_self_signed_cert.ca_cert.cert_pem
  ca_private_key_pem = tls_private_key.ca_key.private_key_pem

  allowed_uses          = ["key_encipherment", "digital_signature", "server_auth"]
  validity_period_hours = 30 * 24
}

# Kubernetes Secretに保存
resource "kubernetes_secret" "istio_tls_secret" {
  depends_on = [helm_release.istio_base]
  metadata {
    name      = local.cert_secret_name
    namespace = local.istio_namespace
  }

  data = {
    "tls.crt" = tls_locally_signed_cert.signed_domain_cert.cert_pem
    "tls.key" = tls_private_key.domain_key.private_key_pem
  }

  type = "kubernetes.io/tls"
}

##############################################
# Private Certificate CronJob
##############################################
# ConfigMapに証明書更新スクリプトを保存
resource "kubernetes_config_map_v1" "cert_renewal_script" {
  depends_on = [helm_release.istio_base]
  metadata {
    name      = "cert-renewal-script"
    namespace = local.istio_namespace
  }

  data = {
    "cert-renewal.sh" = <<EOT
#!/bin/bash
# 一時ディレクトリを作成
mkdir -p /tmp/certs

# CA秘密鍵と証明書の生成
openssl req -x509 -newkey rsa:2048 -days 365 -nodes \
  -keyout /tmp/certs/ca_key.pem \
  -out /tmp/certs/ca_cert.pem \
  -subj "/CN=${var.public_root_domain_name}/O=${var.cluster_name}" \
  -sha256

# ドメインの秘密鍵を生成
openssl genrsa -out /tmp/certs/domain_key.pem 2048

# ドメイン証明書のCSRを生成
openssl req -new -key /tmp/certs/domain_key.pem -out /tmp/certs/domain.csr -subj "/CN=${var.public_root_domain_name}/O=${var.cluster_name}"

# ドメイン証明書をCAで署名
openssl x509 -req -in /tmp/certs/domain.csr -CA /tmp/certs/ca_cert.pem -CAkey /tmp/certs/ca_key.pem -CAcreateserial \
  -out /tmp/certs/domain_cert.pem -days 365 -sha256 -extensions v3_req -extfile <(echo "[v3_req]\nsubjectAltName=DNS:${var.public_root_domain_name},DNS:*.${var.public_root_domain_name}")

# Kubernetes Secretの更新
kubectl create secret tls ${local.cert_secret_name} --key=/tmp/certs/domain_key.pem --cert=/tmp/certs/domain_cert.pem -n ${local.istio_namespace} --dry-run=client -o yaml | kubectl apply -f -
EOT
  }
}

resource "kubernetes_cron_job_v1" "cert_renewal_job" {
  depends_on = [helm_release.istio_base]
  metadata {
    name      = "cert-renewal-job"
    namespace = local.istio_namespace
  }

  spec {
    schedule = "0 0 */10 * *"
    job_template {
      metadata {
        name = "cert-renewal-job"
      }
      spec {
        template {
          metadata {
            name = "cert-renewal-job"
          }
          spec {
            container {
              name    = "cert-renewal"
              image   = "bitnami/kubectl:latest" # kubectlが含まれた軽量イメージ
              command = ["/bin/bash", "-c"]
              args    = ["/tmp/cert-renewal.sh"] # ConfigMapに保存されたスクリプトを実行
              volume_mount {
                name       = "script-volume"
                mount_path = "/tmp"
              }
            }
            restart_policy = "OnFailure"

            volume {
              name = "script-volume"
              config_map {
                name = kubernetes_config_map_v1.cert_renewal_script.metadata[0].name # ConfigMapの参照
              }
            }
          }
        }
      }
    }
  }
}

##############################################
# Istio Ingress
##############################################

resource "helm_release" "istio_ingress" {
  name             = "istio-ingressgateway"
  chart            = "gateway"
  repository       = local.istio_repository
  namespace        = local.istio_namespace
  create_namespace = true

  version = var.istio_version

  set {
    name  = "service.type"
    value = "NodePort"
  }

  set {
    name  = "autoscaling.minReplicas"
    value = var.istio_ingress_min_pods
  }

  set {
    name  = "autoscaling.maxReplicas"
    value = var.istio_ingress_max_pods
  }

  set {
    name  = "service.ports[0].name"
    value = "status-port"
  }

  set {
    name  = "service.ports[0].port"
    value = 15021
  }

  set {
    name  = "service.ports[0].targetPort"
    value = 15021
  }

  set {
    name  = "service.ports[0].nodePort"
    value = local.lb_target_group_status_port
  }

  set {
    name  = "service.ports[0].protocol"
    value = "TCP"
  }


  # set {
  #   name  = "service.ports[1].name"
  #   value = "http2"
  # }

  # set {
  #   name  = "service.ports[1].port"
  #   value = 80
  # }

  # set {
  #   name  = "service.ports[1].targetPort"
  #   value = 80
  # }

  # set {
  #   name  = "service.ports[1].nodePort"
  #   value = local.lb_target_group_http_port
  # }

  # set {
  #   name  = "service.ports[1].protocol"
  #   value = "TCP"
  # }


  set {
    name  = "service.ports[1].name"
    value = "https"
  }

  set {
    name  = "service.ports[1].port"
    value = 443
  }

  set {
    name  = "service.ports[1].targetPort"
    value = 443
  }

  set {
    name  = "service.ports[1].nodePort"
    value = local.lb_target_group_https_port
  }

  set {
    name  = "service.ports[1].protocol"
    value = "TCP"
  }

  depends_on = [
    module.eks,
    helm_release.istio_base,
    helm_release.istiod
  ]
}


# resource "kubectl_manifest" "istio_target_group_binding_http" {
#   yaml_body = <<YAML
# apiVersion: elbv2.k8s.aws/v1beta1
# kind: TargetGroupBinding
# metadata:
#   name: istio-ingress
#   namespace: ${local.istio_namespace}
# spec:
#   serviceRef:
#     name: istio-ingressgateway
#     port: http2
#   targetGroupARN: ${aws_lb_target_group.http.arn}
# YAML

#   depends_on = [
#     module.eks,
#     helm_release.istio_base,
#     helm_release.istiod
#   ]
# }

resource "kubectl_manifest" "istio_target_group_binding_https" {
  yaml_body = <<YAML
apiVersion: elbv2.k8s.aws/v1beta1
kind: TargetGroupBinding
metadata:
  name: istio-ingress-https
  namespace: ${local.istio_namespace}
spec:
  serviceRef:
    name: istio-ingressgateway
    port: https
  targetGroupARN: ${aws_lb_target_group.https.arn}
YAML

  depends_on = [
    module.eks,
    helm_release.istio_base,
    helm_release.istiod
  ]
}

##############################################
# Kiali
##############################################

resource "helm_release" "kiali-server" {
  name             = "kiali-server"
  chart            = "kiali-server"
  repository       = local.kiali_repository
  namespace        = local.istio_namespace
  create_namespace = true

  version = var.kiail_version

  set {
    name  = "server.web_fqdn"
    value = var.kiali_virtual_service_host
  }

  set {
    name  = "auth.strategy"
    value = "anonymous"
  }

  set {
    name  = "external_services.tracing.enabled"
    value = true
  }

  set {
    name  = "external_services.tracing.in_cluster_url"
    value = "http://jaeger-query.${local.jaeger_namespace}.svc.cluster.local:80"
  }

  set {
    name  = "external_services.prometheus.url"
    value = "http://prometheus-kube-prometheus-prometheus.${local.metrics_namespace}.svc.cluster.local:9090"
  }

  set {
    name  = "external_services.grafana.enabled"
    value = true
  }

  set {
    name  = "external_services.grafana.url"
    value = "http://grafana.${local.metrics_namespace}.svc.cluster.local:80"
  }


  depends_on = [
    module.eks,
    helm_release.istio_base,
    helm_release.istiod,
    kubernetes_secret.istio_tls_secret
  ]
}

resource "kubectl_manifest" "public_gateway" {
  yaml_body = <<YAML
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: public-gateway
  namespace: ${local.istio_namespace}
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 443
        protocol: HTTPS
        name: https
      tls:
        mode: SIMPLE
        credentialName: ${local.cert_secret_name}
      hosts:
        - "*"
YAML

  depends_on = [
    module.eks,
    helm_release.istio_base,
    helm_release.istiod
  ]
}

resource "kubectl_manifest" "kiali_virtual_service" {
  yaml_body = <<YAML
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: kiali
  namespace: ${local.istio_namespace}
spec:
  hosts:
    - "${var.kiali_virtual_service_host}"
  gateways:
    - public-gateway
  http:
    - match:
      - uri:
          prefix: /
      route:
      - destination:
          host: kiali.istio-system.svc.cluster.local
          port:
            number: 20001
YAML

  depends_on = [
    module.eks,
    helm_release.istio_base,
    helm_release.istiod
  ]
}
