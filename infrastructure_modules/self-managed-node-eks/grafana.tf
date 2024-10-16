##################################################
# Managed Grafana
##################################################
# resource "aws_grafana_workspace" "grafana" {

#   count = var.enable_prometheus ? 1 : 0

#   account_access_type      = var.prometheus_access_type
#   authentication_providers = var.grafana_authentication_providers
#   permission_type          = var.grafana_permission_type
#   role_arn                 = aws_iam_role.grafana[count.index].arn

#   data_sources              = var.grafana_datasources
#   notification_destinations = var.grafana_notification_destinations

#   vpc_configuration {
#     subnet_ids         = var.grafana_subnets
#     security_group_ids = [module.eks.node_security_group_id]
#   }
# }

# resource "aws_iam_role" "grafana" {

#   count = var.enable_prometheus ? 1 : 0

#   name = format("%s-managed-grafana", var.cluster_name)
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Sid    = ""
#         Principal = {
#           Service = "grafana.amazonaws.com"
#         }
#       },
#     ]
#   })
# }

# resource "aws_grafana_workspace_saml_configuration" "saml_config" {
#   editor_role_values = ["editor"]
#   idp_metadata_url   = aws_cognito_user_pool_client.admin_user_pool_grafana.
#   workspace_id       = aws_grafana_workspace.example.id
# }

# resource "aws_grafana_role_association" "grafana" {
#   count = var.enable_prometheus ? 1 : 0

#   role         = "ADMIN"
#   user_ids     = ["USER_ID_1", "USER_ID_2"]
#   workspace_id = aws_grafana_workspace.grafana[count.index].id
# }


##################################################
# Cognito
##################################################
resource "aws_cognito_user_pool_client" "admin_user_pool_grafana" {
  count = var.enable_prometheus ? 1 : 0

  name         = "grafana-client"
  user_pool_id = var.cognito_user_pool_id
  explicit_auth_flows = [
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_ADMIN_USER_PASSWORD_AUTH",
    "ALLOW_USER_SRP_AUTH",
  ]
  generate_secret                      = true
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["email", "openid", "profile", "aws.cognito.signin.user.admin"]
  supported_identity_providers         = ["COGNITO"]
  callback_urls = [
    "https://${var.grafana_virtual_service_host}/login/generic_oauth",
  ]
  logout_urls = [
    "https://${var.grafana_virtual_service_host}/logout",
  ]
}

##################################################
# Role for Grafana
##################################################

data "aws_iam_policy_document" "grafana_role" {
  count = var.enable_prometheus ? 1 : 0

  version = "2012-10-17"
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values = [
        "system:serviceaccount:${local.metrics_namespace}:grafana"
      ]
    }

    principals {
      identifiers = [module.eks.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "grafana_role" {
  count = var.enable_prometheus ? 1 : 0

  assume_role_policy = data.aws_iam_policy_document.grafana_role[0].json
  name               = format("%s-grafana", var.cluster_name)
  path               = local.iam_role_path
}

data "aws_iam_policy_document" "grafana_policy" {
  count   = var.enable_prometheus ? 1 : 0
  version = "2012-10-17"

  statement {

    effect = "Allow"
    actions = [
      "aps:QueryMetrics",
      "aps:GetSeries",
      "aps:GetLabels",
      "aps:GetMetricMetadata"
    ]

    resources = [
      "*"
    ]
  }
}

resource "aws_iam_policy" "grafana_policy" {
  count       = var.enable_prometheus ? 1 : 0
  name        = format("%s-grafana", var.cluster_name)
  path        = local.iam_role_path
  description = var.cluster_name

  policy = data.aws_iam_policy_document.grafana_policy[0].json
}

resource "aws_iam_policy_attachment" "grafana_policy" {
  count = var.enable_prometheus ? 1 : 0
  name  = format("%s-grafana", var.cluster_name)
  roles = [
    aws_iam_role.grafana_role[0].name
  ]

  policy_arn = aws_iam_policy.grafana_policy[0].arn
}

##################################################
# Helm Grafana
##################################################
locals {
  grafana_repository = "https://grafana.github.io/helm-charts"
}

resource "helm_release" "grafana" {
  count = var.enable_prometheus ? 1 : 0

  name             = "grafana"
  namespace        = local.metrics_namespace
  chart            = "grafana"
  repository       = local.grafana_repository
  version          = var.grafana_version
  create_namespace = true

  # OAuth Config
  set {
    name  = "grafana\\.ini.auth.disable_login_form"
    value = "true"
  }

  set {
    name  = "grafana\\.ini.auth.disable_signout_menu"
    value = "true"
  }

  set {
    name  = "grafana\\.ini.auth\\.anonymous.enabled"
    value = "false"
  }
  set {
    name  = "grafana\\.ini.auth\\.generic_oauth.enabled"
    value = "true"
  }

  set {
    name  = "grafana\\.ini.auth\\.generic_oauth.client_id"
    value = aws_cognito_user_pool_client.admin_user_pool_grafana[0].id
  }

  # set {
  #   name  = "grafana\\.ini.auth\\.generic_oauth.client_secret"
  #   value = aws_cognito_user_pool_client.admin_user_pool_grafana[0].client_secret
  # }

  # set {
  #   name  = "env[0].name"
  #   value = "GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET"
  # }

  # set {
  #   name  = "env[0].value"
  #   value = aws_cognito_user_pool_client.admin_user_pool_grafana[0].client_secret
  # }

  set {
    name  = "env.GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET"
    value = aws_cognito_user_pool_client.admin_user_pool_grafana[0].client_secret
  }

  set {
    name  = "grafana\\.ini.auth\\.generic_oauth.scopes"
    value = "openid profile email aws.cognito.signin.user.admin"
  }

  set {
    name  = "grafana\\.ini.auth\\.generic_oauth.auth_url"
    value = format("https://%s/oauth2/authorize", var.auth_domain)
  }

  set {
    name  = "grafana\\.ini.auth\\.generic_oauth.token_url"
    value = format("https://%s/oauth2/token", var.auth_domain)
  }

  set {
    name  = "grafana\\.ini.auth\\.generic_oauth.api_url"
    value = format("https://%s/oauth2/userInfo", var.auth_domain)
  }

  set {
    name  = "grafana\\.ini.server.root_url"
    value = format("https://%s/", var.grafana_virtual_service_host)
  }

  set {
    name  = "serviceAccount.name"
    value = "grafana"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.grafana_role[0].arn
  }

  set {
    name  = "grafana\\.ini.auth.sigv4_auth_enabled"
    value = "true"
  }

  set {
    name  = "grafana\\.ini.auth.sigv4_auth_region"
    value = var.region
  }

  set {
    name  = "service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "adminUser"
    value = "admin"
  }

  set {
    name  = "adminPassword"
    value = "YOUR_SECURE_PASSWORD"
  }

  # set {
  #   name  = "plugins[0]"
  #   value = "grafana-amazon-cloudwatch-datasource"
  # }

  set {
    name  = "datasources.datasources\\.yaml.apiVersion"
    value = "1"
  }

  set {
    name  = "datasources.datasources\\.yaml.datasources[0].name"
    value = "Amazon Managed Prometheus"
  }

  set {
    name  = "datasources.datasources\\.yaml.datasources[0].type"
    value = "prometheus"
  }

  #   set {
  #   name  = "datasources.datasources\\.yaml.datasources[0].type"
  #   value = "grafana-amazonprometheus-datasource"
  # }

  set {
    name  = "datasources.datasources\\.yaml.datasources[0].url"
    value = format("%s", aws_prometheus_workspace.main[0].prometheus_endpoint) #api/v1/queryは自動で付与される
  }

  set {
    name  = "datasources.datasources\\.yaml.datasources[0].access"
    value = "proxy"
  }

  set {
    name  = "datasources.datasources\\.yaml.datasources[0].jsonData.sigV4Auth"
    value = "true"
  }

  set {
    name  = "datasources.datasources\\.yaml.datasources[0].jsonData.sigV4AuthType"
    value = "default"
  }

  set {
    name  = "datasources.datasources\\.yaml.datasources[0].jsonData.sigV4Region"
    value = var.region
  }

  depends_on = [
    module.eks,
  ]
}

resource "kubectl_manifest" "grafana_virtual_service" {

  count = var.enable_prometheus ? 1 : 0

  yaml_body = <<YAML
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: grafana
  namespace: ${local.istio_namespace}
spec:
  hosts:
  - ${var.grafana_virtual_service_host}
  gateways:
  - public-gateway
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: grafana.${local.metrics_namespace}.svc.cluster.local
        port:
          number: 80
YAML

  depends_on = [
    module.eks,
    helm_release.istio_base,
    helm_release.istiod
  ]
}
