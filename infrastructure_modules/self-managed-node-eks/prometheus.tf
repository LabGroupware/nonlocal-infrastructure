locals {
  prometheus_repository = "https://prometheus-community.github.io/helm-charts"
  metrics_namespace     = "metrics"
}

############################################
# Helm Chart for Prometheus
############################################

resource "helm_release" "prometheus" {
  count = var.enable_prometheus ? 1 : 0

  name             = "prometheus"
  chart            = "kube-prometheus-stack"
  repository       = local.prometheus_repository
  namespace        = local.metrics_namespace
  create_namespace = true

  version = var.prometheus_version


  values = [
    "${file("${var.helm_dir}/prometheus/values.yml")}"
  ]


  depends_on = [
    module.eks,
    kubernetes_storage_class_v1.block_general,
  ]
}

