locals {
  key_values = concat(
    var.need_bastion_key ? ["bastion"] : [],
    var.need_eks_node_key ? ["eks-node"] : [],
  )

  key_names = {
    for key in local.key_values : key => "${var.region_tag[var.region]}-${var.env}-${var.application_name}-${key}-${data.external.hostname.result["hostname"]}-${random_bytes.bytes.hex}"
  }

  key_tags = {
    for key in local.key_values : key => {
      Terraform   = true
      Application = var.application_name
      Environment = var.env
      Hostname    = data.external.hostname.result["hostname"]
      Keyname     = key
    }
  }
}

data "external" "hostname" {
  program = ["bash", "${path.module}/get_hostname.sh"]
}
