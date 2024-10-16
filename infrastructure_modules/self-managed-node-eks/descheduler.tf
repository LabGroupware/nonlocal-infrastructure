locals {
  descheduler_repository = "https://kubernetes-sigs.github.io/descheduler"
}

resource "helm_release" "descheduler" {
  count = var.enable_descheduler ? 1 : 0

  name             = "descheduler"
  repository       = local.descheduler_repository
  chart            = "descheduler"
  namespace        = "kube-system"
  create_namespace = true


  set {
    name  = "cronJobApiVersion"
    value = "batch/v1beta1"
  }

  depends_on = [
    module.eks,
  ]
}
