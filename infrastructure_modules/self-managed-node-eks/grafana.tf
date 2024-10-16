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

  # set {
  #   name  = "datasources.prometheus"
  #   value = jsonencode({
  #     name      = "Prometheus"
  #     type      = "prometheus"
  #     url       = "https://aps-workspaces.us-west-2.amazonaws.com/workspaces/YOUR_WORKSPACE_ID"  # AWS Managed Prometheusのエンドポイント
  #     access    = "proxy"
  #     isDefault = true
  #   })
  # }

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

##################################################
# Cognito
##################################################
# resource "aws_cognito_user_pool_client" "admin_user_pool_grafana" {
#   count = var.enable_prometheus ? 1 : 0

#   name         = "grafana-client"
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
#     "https://${aws_grafana_workspace.grafana[count.index].endpoint}/login/generic_oauth",
#   ]
#   logout_urls = [
#     "https://${aws_grafana_workspace.grafana[count.index].endpoint}/logout",
#   ]
# }

# TODO: ADMIN ROLEへのアサインメントを実装

# resource "aws_grafana_role_association" "grafana" {
#   count = var.enable_prometheus ? 1 : 0

#   role         = "ADMIN"
#   user_ids     = ["USER_ID_1", "USER_ID_2"]
#   workspace_id = aws_grafana_workspace.grafana[count.index].id
# }


# GF_AUTH_GENERIC_OAUTH_ALLOW_SIGN_UP=true
# GF_AUTH_GENERIC_OAUTH_API_URL=https://<your domain>.auth.eu-west-1.amazoncognito.com/oauth2/userInfo
# GF_AUTH_GENERIC_OAUTH_AUTH_URL=https://<your domain>.auth.eu-west-1.amazoncognito.com/oauth2/authorize
# GF_AUTH_GENERIC_OAUTH_TOKEN_URL=https://<your domain>.auth.eu-west-1.amazoncognito.com/oauth2/token
# GF_AUTH_GENERIC_OAUTH_CLIENT_ID=<copy from aws console>
# GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=<copy from aws console>
# GF_AUTH_GENERIC_OAUTH_ENABLED=true
# GF_AUTH_GENERIC_OAUTH_NAME=GreatCognito
# GF_AUTH_GENERIC_OAUTH_SCOPES=openid profile email
