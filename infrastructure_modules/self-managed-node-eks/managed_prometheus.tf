# locals {
#   prometheus_repository = "https://prometheus-community.github.io/helm-charts"
#   metrics_namespace     = "metrics"
# }

# ############################################
# # Managed Prometheus
# ############################################
# resource "aws_cloudwatch_log_group" "prometheus" {
#   count             = var.enable_prometheus ? 1 : 0
#   name              = format("%s-prometheus", var.cluster_name)
#   retention_in_days = 1
# }

# resource "aws_prometheus_workspace" "main" {
#   count = var.enable_prometheus ? 1 : 0
#   alias = var.cluster_name

#   logging_configuration {
#     log_group_arn = "${aws_cloudwatch_log_group.prometheus[count.index].arn}:*"
#   }
# }

# ############################################
# # IAM Role for Prometheus
# ############################################
# data "aws_iam_policy_document" "prometheus_role" {
#   statement {
#     actions = ["sts:AssumeRoleWithWebIdentity"]
#     effect  = "Allow"

#     condition {
#       test     = "StringEquals"
#       variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
#       values = [
#         "system:serviceaccount:${local.metrics_namespace}:managed-prometheus"
#       ]
#     }

#     principals {
#       identifiers = [module.eks.oidc_provider_arn]
#       type        = "Federated"
#     }
#   }
# }

# resource "aws_iam_role" "prometheus_role" {
#   assume_role_policy = data.aws_iam_policy_document.prometheus_role.json
#   name               = format("%s-managed-prometheus", var.cluster_name)
#   path               = local.iam_role_path
# }


# data "aws_iam_policy_document" "prometheus_policy" {
#   version = "2012-10-17"

#   statement {

#     effect = "Allow"
#     actions = [
#       "aps:QueryMetrics",
#       "aps:GetSeries",
#       "aps:GetLabels",
#       "aps:GetMetricMetadata",
#       "aps:RemoteWrite"
#     ]

#     resources = [
#       "*"
#     ]
#   }
# }

# resource "aws_iam_policy" "prometheus_policy" {
#   name        = format("%s-managed-prometheus", var.cluster_name)
#   path        = local.iam_role_path
#   description = var.cluster_name

#   policy = data.aws_iam_policy_document.prometheus_policy.json
# }

# resource "aws_iam_policy_attachment" "prometheus_policy" {
#   name = format("%s-managed-prometheus", var.cluster_name)
#   roles = [
#     aws_iam_role.prometheus_role.name
#   ]

#   policy_arn = aws_iam_policy.prometheus_policy.arn
# }

# ############################################
# # Helm Chart for Prometheus
# ############################################

# resource "helm_release" "prometheus" {
#   count = var.enable_prometheus ? 1 : 0

#   name             = "prometheus"
#   chart            = "kube-prometheus-stack"
#   repository       = local.prometheus_repository
#   namespace        = local.metrics_namespace
#   create_namespace = true

#   version = var.prometheus_version

#   set {
#     name  = "prometheus.serviceAccount.name"
#     value = "managed-prometheus"
#   }

#   set {
#     name  = "prometheus.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
#     value = aws_iam_role.prometheus_role.arn
#   }

#   set {
#     name  = "prometheus.prometheusSpec.remoteWrite[0].url"
#     value = format("%sapi/v1/remote_write", aws_prometheus_workspace.main[0].prometheus_endpoint)
#   }

#   set {
#     name  = "prometheus.prometheusSpec.remoteWrite[0].sigv4.region"
#     value = var.region
#   }

#   set {
#     name  = "prometheus.prometheusSpec.remoteWrite[0].queue_config.max_samples_per_send"
#     value = "1000"
#   }

#   set {
#     name  = "prometheus.prometheusSpec.remoteWrite[0].queue_config.max_shards"
#     value = "200"
#   }

#   set {
#     name  = "prometheus.prometheusSpec.remoteWrite[0].queue_config.capacity"
#     value = "2500"
#   }


#   values = [
#     "${file("${var.helm_dir}/prometheus/values.yml")}"
#   ]


#   depends_on = [
#     module.eks
#   ]
# }

