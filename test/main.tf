locals {
  ng = {
    node_labels = "node-role.kubernetes.io/worker=test"
    # node_taints = "node-role.kubernetes.io/worker=:NoSchedule"
  }

  label_falg = lookup(local.ng, "node_labels", null) != null ? format("--node-labels=%s", local.ng.node_labels) : ""
  taint_flag = lookup(local.ng, "node_taints", null) != null ? format("--register-with-taints=%s", local.ng.node_taints) : ""
}

output "label_falg" {
  value = local.label_falg
}

output "taint_flag" {
  value = local.taint_flag
}
