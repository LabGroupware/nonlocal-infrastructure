module "keys" {
  source = "../../../../../infrastructure_modules/key-pair"

  application_name = var.application_name
  env              = var.env
  region           = var.region

  private_dir      = "${path.module}/../.keys"
  need_bastion_key = var.need_bastion_key
  need_eks_node_key = var.need_eks_node_key
}

