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

resource "kubectl_manifest" "prometheus_virtual_service" {

  count = var.enable_prometheus ? 1 : 0

  yaml_body = <<YAML
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: prometheus
  namespace: ${local.istio_namespace}
spec:
  hosts:
  - ${var.prometheus_virtual_service_host}
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
    helm_release.grafana,
    helm_release.istio_base,
    helm_release.istiod
  ]
}