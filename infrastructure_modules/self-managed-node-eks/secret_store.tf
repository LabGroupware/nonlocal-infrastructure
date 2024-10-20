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
