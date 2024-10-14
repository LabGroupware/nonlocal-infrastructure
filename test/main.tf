locals {
  bootstrap_extra_args = format("--kubelet-extra-args%s%s",
    lookup(ng, "node_labels", null) != null ? format(" --node-labels=%s", ng.node_labels) : "",
    lookup(ng, "node_taints", null) != null ? format(" --register-with-taints=%s", ng.node_taints) : "",
  )
}
