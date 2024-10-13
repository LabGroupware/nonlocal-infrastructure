# ELB -> Istio Ingress

locals {
  ##############################################
  # ELB
  ##############################################
  lb_ssl_policy              = "ELBSecurityPolicy-2016-08"
  lb_target_group_http_port  = 30080
  lb_target_group_https_port = 30443

  ##############################################
  # AWS LB Controller
  ##############################################
  eks_repository = "https://aws.github.io/eks-charts"

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
  name               = var.cluster_name
  internal           = var.nlb_ingress_internal
  load_balancer_type = "network"

  subnets = var.lb_subnet_ids

  enable_deletion_protection = false

  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

resource "aws_lb_target_group" "http" {
  name              = format("%s-http", var.cluster_name)
  port              = local.lb_target_group_http_port
  protocol          = "TCP"
  vpc_id            = var.vpc_id
  proxy_protocol_v2 = var.proxy_protocol_v2
}

resource "aws_lb_target_group" "https" {
  name              = format("%s-https", var.cluster_name)
  port              = local.lb_target_group_https_port
  protocol          = "TCP"
  vpc_id            = var.vpc_id
  proxy_protocol_v2 = var.proxy_protocol_v2
}

resource "aws_lb_listener" "ingress_443" {
  load_balancer_arn = aws_lb.ingress.arn
  port              = 443
  protocol          = "TLS"
  certificate_arn   = aws_acm_certificate.public.arn
  ssl_policy        = local.lb_ssl_policy
  alpn_policy       = "HTTP2Preferred"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.https.arn
  }
}

resource "aws_lb_listener" "ingress_80" {
  load_balancer_arn = aws_lb.ingress.arn
  port              = 80
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.http.arn
  }
}

resource "aws_api_gateway_vpc_link" "nlb" {
  count = var.enable_vpc_link ? 1 : 0

  name        = var.cluster_name
  description = var.cluster_name
  target_arns = [
    aws_lb.ingress.arn
  ]
}

##############################################
# Private DNS
##############################################
resource "aws_route53_zone" "private" {
  name = var.cluster_private_zone

  vpc {
    vpc_id = var.vpc_id
  }
}

resource "aws_route53_record" "nlb" {
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
    value = 30021
  }

  set {
    name  = "service.ports[0].protocol"
    value = "TCP"
  }


  set {
    name  = "service.ports[1].name"
    value = "http2"
  }

  set {
    name  = "service.ports[1].port"
    value = 80
  }

  set {
    name  = "service.ports[1].targetPort"
    value = 80
  }

  set {
    name  = "service.ports[1].nodePort"
    value = local.lb_target_group_http_port
  }

  set {
    name  = "service.ports[1].protocol"
    value = "TCP"
  }


  set {
    name  = "service.ports[2].name"
    value = "https"
  }

  set {
    name  = "service.ports[2].port"
    value = 443
  }

  set {
    name  = "service.ports[2].targetPort"
    value = 443
  }

  set {
    name  = "service.ports[2].nodePort"
    value = local.lb_target_group_https_port
  }

  set {
    name  = "service.ports[2].protocol"
    value = "TCP"
  }

  depends_on = [
    module.eks,
    helm_release.istio_base,
    helm_release.istiod
  ]
}


resource "kubectl_manifest" "istio_target_group_binding_http" {
  yaml_body = <<YAML
apiVersion: elbv2.k8s.aws/v1beta1
kind: TargetGroupBinding
metadata:
  name: istio-ingress
  namespace: ${local.istio_namespace}
spec:
  serviceRef:
    name: istio-ingressgateway
    port: http2
  targetGroupARN: ${aws_lb_target_group.http.arn}
YAML


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

resource "helm_release" "kiali-server" {
  name             = "kiali-server"
  chart            = "kiali-server"
  repository       = local.kiali_repository
  namespace        = "istio-system"
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

  # set {
  #   name  = "external_services.tracing.enabled"
  #   value = true
  # }

  # set {
  #   name  = "external_services.tracing.in_cluster_url"
  #   value = "http://jaeger-query.jaeger.svc.cluster.local:80"
  # }

  # set {
  #   name  = "external_services.tracing.use_grpc"
  #   value = false
  # }

  # set {
  #   name  = "external_services.prometheus.url"
  #   value = "http://prometheus-kube-prometheus-prometheus.prometheus.svc.cluster.local:9090"
  # }

  # set {
  #   name  = "external_services.grafana.enabled"
  #   value = true
  # }

  # set {
  #   name  = "external_services.grafana.url"
  #   value = "http://prometheus-grafana.prometheus.svc.cluster.local:80"
  # }


  depends_on = [
    module.eks,
    helm_release.istio_base,
    helm_release.istiod
  ]
}

resource "kubectl_manifest" "kiali_gateway" {
  yaml_body = <<YAML
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: kiali-gateway
  namespace: ${local.istio_namespace}
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      # number: 443
      # name: https
      # protocol: HTTPS
      name: http
      number: 80
      protocol: HTTP
    hosts:
    - ${var.kiali_virtual_service_host}
    # tls:
    #   mode: SIMPLE
    #   credentialName: kiali-certificate
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
  - ${var.kiali_virtual_service_host}
  gateways:
  - kiali-gateway
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: kiali
        port:
          number: 20001
YAML

  depends_on = [
    module.eks,
    helm_release.istio_base,
    helm_release.istiod
  ]
}
