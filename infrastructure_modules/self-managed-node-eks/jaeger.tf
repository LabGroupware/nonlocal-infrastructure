locals {
  jaeger_repository = "https://jaegertracing.github.io/helm-charts"
  jaeger_namespace  = "jaeger"
}

resource "helm_release" "jaeger" {
  count = var.enable_jaeger ? 1 : 0

  name       = "jaeger"
  repository = local.jaeger_repository
  chart      = "jaeger"
  namespace  = local.jaeger_namespace
  version = var.jaeger_version
  create_namespace = true

  depends_on = [
    module.eks,
  ]
}

resource "kubectl_manifest" "gaeger_virtual_service" {

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
        host: jaeger-query.${local.jaeger_namespace}.svc.cluster.local
        port:
          number: 80
YAML

  depends_on = [
    module.eks,
    helm_release.istio_base,
    helm_release.istiod
  ]

}
