locals {
  jaeger_repository = "https://jaegertracing.github.io/helm-charts"
  tracing_namespace = "tracing"
}

##################################################
# Cognito(For OAuth2)
##################################################
# resource "aws_cognito_user_pool_client" "admin_user_pool_jaeger" {
#   count = var.enable_jaeger ? 1 : 0

#   name         = "jaeger-client"
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
#     "https://${var.jaeger_virtual_service_host}/oauth2/callback",
#   ]
#   # logout_urls = [
#   #   "https://${var.jaeger_virtual_service_host}/logout",
#   # ]
# }

##################################################
# Coockie Secret(For OAuth2)
##################################################
# resource "random_password" "cookie_secret" {
#   count = var.enable_jaeger ? 1 : 0

#   length           = 32
#   special          = false
#   override_special = "_-"
# }

# resource "aws_secretsmanager_secret" "cookie_secret" {
#   count = var.enable_jaeger ? 1 : 0

#   name        = "jaeger-cookie-secret-for-oauth2"
#   description = "Cookie secret for jaeger oauth2"
# }

# resource "aws_secretsmanager_secret_version" "cookie_secret" {
#   count = var.enable_jaeger ? 1 : 0

#   secret_id     = aws_secretsmanager_secret.cookie_secret[0].id
#   secret_string = random_password.cookie_secret[0].result
# }

##################################################
# Jaeger
##################################################

resource "helm_release" "jaeger" {
  count = var.enable_jaeger ? 1 : 0

  name             = "jaeger"
  repository       = local.jaeger_repository
  chart            = "jaeger"
  namespace        = local.tracing_namespace
  version          = var.jaeger_version
  create_namespace = true

  # OAuth設定
  # set {
  #   name  = "query.oAuthSidecar.enabled"
  #   value = "true"
  # }

  # set {
  #   name  = "query.oAuthSidecar.args[0]"
  #   value = "--provider=oidc"
  # }

  # set {
  #   name  = "query.oAuthSidecar.args[1]"
  #   value = "--oidc-issuer-url=https://${var.cognito_endpoint}"
  # }

  # set {
  #   name  = "query.oAuthSidecar.args[2]"
  #   value = "--client-id=${aws_cognito_user_pool_client.admin_user_pool_jaeger[0].id}"
  # }

  # set {
  #   name  = "query.oAuthSidecar.args[3]"
  #   value = "--client-secret=${aws_cognito_user_pool_client.admin_user_pool_jaeger[0].client_secret}"
  # }

  # set {
  #   name  = "query.oAuthSidecar.args[4]"
  #   value = "--cookie-secure=true"
  # }

  # set {
  #   name  = "query.oAuthSidecar.args[5]"
  #   value = "--cookie-secret=${aws_secretsmanager_secret_version.cookie_secret[0].secret_string}"
  # }

  # set {
  #   name  = "query.oAuthSidecar.args[6]"
  #   value = "--redirect-url=https://${var.jaeger_virtual_service_host}/oauth2/callback"
  # }

  # set {
  #   name  = "query.oAuthSidecar.args[7]"
  #   value = "--email-domain=*"
  # }

  # set {
  #   name  = "query.oAuthSidecar.args[8]"
  #   value = "--cookie-name=_oauth2_proxy"
  # }

  # set {
  #   name  = "query.oAuthSidecar.args[9]"
  #   value = "--upstream=http://127.0.0.1:16686"
  # }

  # set {
  #   name  = "query.oAuthSidecar.args[10]"
  #   value = "http-address=:4180"
  # }

  # set {
  #   name  = "query.oAuthSidecar.args[11]"
  #   value = "--skip-provider-button=true"
  # }

  # set {
  #   name  = "query.oAuthSidecar.args[12]"
  #   value = "--oidc-groups-claim=cognito:groups"
  # }

  # set {
  #   name  = "query.oAuthSidecar.args[13]"
  #   value = "--user-id-claim=email"
  # }

  values = [
    "${file("${var.helm_dir}/jaeger/values.yml")}"
  ]

  depends_on = [
    module.eks,
    kubernetes_storage_class_v1.block_general,
  ]
}

resource "kubectl_manifest" "jaeger_virtual_service" {

  count = var.enable_jaeger ? 1 : 0

  yaml_body = <<YAML
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: jaeger
  namespace: ${local.istio_namespace}
spec:
  hosts:
  - ${var.jaeger_virtual_service_host}
  gateways:
  - public-gateway
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: jaeger-query.${local.tracing_namespace}.svc.cluster.local
        port:
          number: 80
YAML

  depends_on = [
    module.eks,
    helm_release.jaeger,
    helm_release.istio_base,
    helm_release.istiod
  ]
}
