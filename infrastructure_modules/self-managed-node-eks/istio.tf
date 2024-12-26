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
  # Istio Ingress Certificate Secret
  ##############################################
  cert_secret_name = "istio-ingressgateway-certs"

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

  client_keep_alive = var.lb_client_keep_alive
  idle_timeout      = var.lb_idle_timeout

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
      "ec2:CreateSecurityGroup",
      "ec2:CreateTags",
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
      "ec2:DeleteSecurityGroup",
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

  values = [
    "${file("${var.helm_dir}/aws-load-balancer-controller/values.yml")}"
  ]

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

  set {
    name  = "autoscaleEnabled"
    value = "true"
  }

  set {
    name  = "autoscaleMin"
    value = 1
  }

  set {
    name  = "autoscaleMax"
    value = 5
  }

  set {
    name  = "resources.requests.cpu"
    value = "500m"
  }

  set {
    name  = "resources.requests.memory"
    value = "1Gi"
  }

  set {
    name  = "cpu.targetAverageUtilization"
    value = 75
  }

  depends_on = [
    module.eks,
    helm_release.istio_base
  ]
}

##############################################
# Istio Ingress Cert
##############################################
resource "kubectl_manifest" "istio_cert" {
  yaml_body = <<YAML
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ${local.cert_secret_name}
  namespace: istio-system
spec:
  secretName: ${local.cert_secret_name}
  issuerRef:
    kind: ClusterIssuer
    name: letsencrypt-issuer
  commonName: "*.${var.public_root_domain_name}"
  dnsNames:
  - "*.${var.public_root_domain_name}"
  - "${var.public_root_domain_name}"
  acme:
    config:
    - dns01:
        provider: aws-route53
      domains:
      - "*.${var.public_root_domain_name}"
      - "${var.public_root_domain_name}"
YAML

  depends_on = [
    module.eks,
    kubectl_manifest.cluster_issuer
  ]
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
    name  = "resources.requests.cpu"
    value = "1500m"
  }

  set {
    name  = "resources.requests.memory"
    value = "2Gi"
  }

  set {
    name  = "resources.limits.cpu"
    value = "1500m"
  }

  set {
    name  = "resources.limits.memory"
    value = "2Gi"
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

##################################################
# Cognito
##################################################
# resource "aws_cognito_user_pool_client" "admin_user_pool_kiali" {
#   name         = "kiali-client"
#   user_pool_id = var.cognito_user_pool_id
#   explicit_auth_flows = [
#     "ALLOW_REFRESH_TOKEN_AUTH",
#     "ALLOW_USER_PASSWORD_AUTH",
#     "ALLOW_ADMIN_USER_PASSWORD_AUTH",
#     "ALLOW_USER_SRP_AUTH",
#   ]
#   generate_secret                      = true
#   allowed_oauth_flows_user_pool_client = true
#   allowed_oauth_flows                  = ["code"]
#   allowed_oauth_scopes                 = ["email", "openid", "profile", "aws.cognito.signin.user.admin"]
#   supported_identity_providers         = ["COGNITO"]
#   callback_urls = [
#     "https://${var.kiali_virtual_service_host}/kiali",
#   ]
# }

# ##############################################
# # Kiali
# ##############################################

# resource "helm_release" "kiali_server" {
#   name             = "kiali-server"
#   chart            = "kiali-server"
#   repository       = local.kiali_repository
#   namespace        = local.istio_namespace
#   create_namespace = true

#   version = var.kiail_version

#   set {
#     name  = "server.web_fqdn"
#     value = var.kiali_virtual_service_host
#   }

#   # set {
#   #   name  = "auth.strategy"
#   #   value = "anonymous"
#   # }

#   set {
#     name  = "auth.strategy"
#     value = "openid"
#   }

#   set {
#     name  = "auth.openid.client_id"
#     value = aws_cognito_user_pool_client.admin_user_pool_kiali.id
#   }

#   set {
#     name  = "auth.openid.client_secret"
#     value = aws_cognito_user_pool_client.admin_user_pool_kiali.client_secret
#   }

#   set {
#     name  = "auth.openid.issuer_uri"
#     value = "https://${var.cognito_endpoint}"
#   }

#   set {
#     name  = "auth.openid.scopes[0]"
#     value = "openid"
#   }

#   set {
#     name  = "auth.openid.scopes[1]"
#     value = "email"
#   }

#   set {
#     name  = "auth.openid.scopes[2]"
#     value = "profile"
#   }

#   set {
#     name  = "auth.openid.scopes[3]"
#     value = "aws.cognito.signin.user.admin"
#   }

#   # RBACありの挙動が異常なので無効化
#   # TODO: 修正
#   set {
#     name  = "auth.openid.disable_rbac"
#     value = "true"
#   }

#   # ログインユーザーは閲覧のみ
#   set {
#     name  = "deployment.view_only_mode"
#     value = "true"
#   }

#   set {
#     name  = "auth.openid.username_claim"
#     value = "email"
#   }

#   set {
#     name  = "external_services.tracing.enabled"
#     value = true
#   }

#   set {
#     name  = "external_services.tracing.use_grpc"
#     value = false
#   }

#   set {
#     name  = "external_services.tracing.in_cluster_url"
#     value = "http://jaeger-query.${local.tracing_namespace}.svc.cluster.local:80"
#   }

#   set {
#     name  = "external_services.prometheus.url"
#     value = "http://prometheus-kube-prometheus-prometheus.${local.metrics_namespace}.svc.cluster.local:9090"
#   }

#   set {
#     name  = "external_services.grafana.enabled"
#     value = true
#   }

#   set {
#     name  = "external_services.grafana.url"
#     value = "http://grafana.${local.metrics_namespace}.svc.cluster.local:80"
#   }

#   set {
#     name  = "external_services.grafana.in_cluster_url"
#     value = "http://grafana.${local.metrics_namespace}.svc.cluster.local:80"
#   }

#   # level=info msg="Failed to authenticate request" client=auth.client.api-key error="[api-key.invalid] API key is invalid"
#   # set {
#   #   name  = "external_services.grafana.auth.type"
#   #   value = "basic"
#   # }

#   # set {
#   #   name  = "external_services.grafana.auth.username"
#   #   value = "admin"
#   # }

#   # set {
#   #   name  = "external_services.grafana.auth.password"
#   #   value = "YOUR_SECURE_PASSWORD"
#   # }

#   # set {
#   #   name  = "external_services.grafana.auth.type"
#   #   value = "bearer"
#   # }

#   # set {
#   #   name  = "external_services.grafana.auth.token"
#   #   value = ""
#   # }

#   # set {
#   #   name  = "external_services.grafana.auth.use_kiali_token"
#   #   value = true
#   # }

#   set {
#     name  = "external_services.grafana.dashboards[0].name"
#     value = "kubernetes-cluster-monitoring"
#   }

#   set {
#     name  = "external_services.grafana.dashboards[1].name"
#     value = "node-exporter-full"
#   }

#   set {
#     name  = "external_services.grafana.dashboards[2].name"
#     value = "prometheus-overview"
#   }

#   set {
#     name  = "external_services.grafana.dashboards[3].name"
#     value = "kubernetes-pod"
#   }

#   set {
#     name  = "external_services.grafana.dashboards[4].name"
#     value = "node-exporter"
#   }

#   set {
#     name  = "external_services.grafana.dashboards[5].name"
#     value = "cluster-monitoring-for-kubernetes"
#   }

#   set {
#     name  = "external_services.grafana.dashboards[6].name"
#     value = "k8s-cluster-summary"
#   }

#   set {
#     name  = "external_services.grafana.dashboards[7].name"
#     value = "kubernetes-cluster"
#   }

#   values = [
#     "${file("${var.helm_dir}/kiali/values.yml")}"
#   ]


#   depends_on = [
#     module.eks,
#     helm_release.istio_base,
#     helm_release.istiod,
#   ]
# }

# Auth RBAC
# resource "kubernetes_cluster_role_binding_v1" "admin_kiali_binding" {
#   metadata {
#     name = "kiali-admin-binding"
#   }

#   role_ref {
#     api_group = "rbac.authorization.k8s.io"
#     kind      = "ClusterRole"
#     name      = "kiali"
#     # name      = "kiali-viewer" # view_only_mode: falseの場合はkiali
#   }

#   subject {
#     kind      = "User"
#     name      = var.admin_email
#     api_group = "rbac.authorization.k8s.io"
#   }

#   depends_on = [helm_release.kiali_server]
# }

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
    helm_release.istiod,
    kubectl_manifest.istio_cert
  ]
}

# resource "kubectl_manifest" "kiali_virtual_service" {
#   yaml_body = <<YAML
# apiVersion: networking.istio.io/v1alpha3
# kind: VirtualService
# metadata:
#   name: kiali
#   namespace: ${local.istio_namespace}
# spec:
#   hosts:
#     - "${var.kiali_virtual_service_host}"
#   gateways:
#     - public-gateway
#   http:
#     - match:
#       - uri:
#           prefix: /
#       route:
#       - destination:
#           host: kiali.${local.istio_namespace}.svc.cluster.local
#           port:
#             number: 20001
# YAML

#   depends_on = [
#     module.eks,
#     helm_release.kiali_server,
#     helm_release.istio_base,
#     helm_release.istiod
#   ]
# }
