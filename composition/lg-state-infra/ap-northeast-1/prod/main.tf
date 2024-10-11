# TODO: NodeのLabel, Taintの設定修正
# TODO: Block Device Mountの確認
# TODO: Access Entryの作成
# TODO: EBS, EFSのPersistent Volumeの設定を追記する
# TODO: IRSAの設定を追記する
# TODO: BasionからEKS Nodeへのアクセスを許可するための設定を追記する
# (security group + instance profile(iam role))
# TODO: PrometheusとGrafanaの設定を追記する
# TODO: SMを使ったSecretの設定を追記する

########################################
# VPC
########################################
module "vpc" {
  source = "../../../../infrastructure_modules/vpc" # using infra module VPC which acts like a facade to many sub-resources

  name                                 = var.app_name
  cidr                                 = var.cidr
  azs                                  = var.azs
  cluster_name                         = var.cluster_name
  private_subnets                      = var.private_subnets
  public_subnets                       = var.public_subnets
  database_subnets                     = var.database_subnets
  enable_dns_hostnames                 = var.enable_dns_hostnames
  enable_dns_support                   = var.enable_dns_support
  enable_nat_gateway                   = var.enable_nat_gateway
  single_nat_gateway                   = var.single_nat_gateway
  enable_flow_log                      = var.enable_flow_log
  create_flow_log_cloudwatch_iam_role  = var.create_flow_log_cloudwatch_iam_role
  create_flow_log_cloudwatch_log_group = var.create_flow_log_cloudwatch_log_group
  flow_log_max_aggregation_interval    = var.flow_log_max_aggregation_interval

  ## Public Security Group ##
  public_ingress_with_cidr_blocks = var.public_ingress_with_cidr_blocks

  ## Public Bastion Security Group ##
  public_bastion_ingress_with_cidr_blocks = var.public_bastion_ingress_with_cidr_blocks

  create_eks                                                         = var.create_eks
  databse_computed_ingress_with_eks_worker_source_security_group_ids = local.databse_computed_ingress_with_eks_worker_source_security_group_ids

  ## Common tag metadata ##
  env      = var.env
  app_name = var.app_name
  tags     = local.vpc_tags
  region   = var.region
}

########################################
# Bastion
########################################
module "bastion" {
  source = "../../../../infrastructure_modules/bastion"

  instance_name       = local.bastion_instance_name
  instance_type       = var.bastion_instance_type
  instance_keypair    = data.aws_key_pair.bastion_key_pair.key_name
  instance_monitoring = var.bastion_instance_monitoring
  bastion_subnet_id   = module.vpc.public_subnets[0]
  bastion_sg_ids      = [module.vpc.public_bastion_security_group_id]
  bastion_tags        = local.bastion_tags
  bastion_eip_tags    = local.bastion_eip_tags
}

########################################
# EKS
########################################
module "eks" {
  source = "../../../../infrastructure_modules/self-managed-node-eks"

  ## General ##
  region   = var.region
  env      = var.env
  app_name = var.app_name
  tags     = local.eks_tags

  ## IAM ##
  cluster_iam_role_additional_policies = {}

  ## Access Entry ##
  cluster_admin_role = ""

  ## EKS ##
  create_eks                             = var.create_eks
  cluster_version                        = var.cluster_version
  cluster_name                           = var.cluster_name
  cluster_enabled_log_types              = var.cluster_enabled_log_types
  subnets                                = module.vpc.private_subnets
  cloudwatch_log_group_retention_in_days = var.cloudwatch_log_group_retention_in_days
  vpc_id                                 = module.vpc.vpc_id

  ## Key Pair ##
  node_instance_default_keypair = data.aws_key_pair.eks_node_key_pair.key_name

  ## Node Group ##
  node_groups = var.node_groups
}
