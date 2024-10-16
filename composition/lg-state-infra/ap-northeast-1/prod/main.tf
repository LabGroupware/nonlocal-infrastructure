# TODO: EFSのPersistent Volumeの設定を追記する
# TODO: Storage Classの設定を追記する
# TODO: PrometheusとGrafanaの設定を追記する
# TODO: SMを使ったSecretの設定を追記する
# TODO: 自己証明書の更新CronJobの有効性を検証する
# TODO: LBからのヘルスチェック
# TODO: EFKスタックの設定を追記する
# TODO: argoCDの設定を追記する

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

module "cognito" {
  source = "../../../../infrastructure_modules/cognito"

  sms_external_id          = var.sms_external_id
  has_root_domain_a_record = var.has_root_domain_a_record
  admin_pool_name          = local.admin_pool_name
  tags                     = local.cognito_tags
  ses_domain               = var.ses_domain
  cognito_from_address     = var.cognito_from_address
  route53_zone_domain_name = var.route53_zone_domain_name
  auth_domain              = var.auth_domain
  admin_domain             = var.admin_domain
  aws_route53_record_ttl   = var.aws_route53_record_ttl
  default_admin            = var.default_admin
}

########################################
# EKS
########################################
module "eks" {
  source = "../../../../infrastructure_modules/self-managed-node-eks"

  ## General ##
  account_id   = data.aws_caller_identity.this.account_id
  profile_name = var.profile_name
  region       = var.region
  env          = var.env
  app_name     = var.app_name
  tags         = local.eks_tags

  ## IAM ##
  cluster_iam_role_additional_policies = {}

  ## Access Entry ##
  create_admin_access_entry  = var.create_admin_access_entry
  cluster_admin_role         = var.cluster_admin_role
  additional_accesss_entries = var.additional_accesss_entries

  ## EKS ##
  create_eks                             = var.create_eks
  cluster_version                        = var.cluster_version
  cluster_name                           = var.cluster_name
  cluster_enabled_log_types              = var.cluster_enabled_log_types
  subnets                                = module.vpc.private_subnets
  cloudwatch_log_group_retention_in_days = var.cloudwatch_log_group_retention_in_days
  vpc_id                                 = module.vpc.vpc_id
  vpc_cidr_block                         = module.vpc.vpc_cidr_block
  bastion_sg_id                          = module.vpc.public_bastion_security_group_id

  ## Key Pair ##
  node_instance_default_keypair = data.aws_key_pair.eks_node_key_pair.key_name

  ## Node Group ##
  node_groups = var.node_groups

  ## IRSA ##
  additional_irsa_roles = var.additional_irsa_roles

  ## EBS CSI Driver ##
  enable_ebs_csi = var.enable_ebs_csi

  ## EFS CSI Driver ##
  enable_efs_csi = var.enable_efs_csi

  ## Helm ##
  helm_dir = "${path.module}/helm"

  ## Istio ##
  ##############################################
  # ACM + Route53
  ##############################################
  route53_zone_domain_name  = var.route53_zone_domain_name
  acm_domain_name           = var.acm_domain_name
  subject_alternative_names = var.subject_alternative_names
  aws_route53_record_ttl    = 300
  ##############################################
  # ELB
  ##############################################
  lb_ingress_internal  = false
  lb_security_group_id = module.vpc.public_security_group_id
  lb_subnet_ids        = module.vpc.public_subnets
  proxy_protocol_v2    = false
  enable_vpc_link      = false
  #########################
  # Route53 Config
  #########################
  public_root_domain_name = var.public_root_domain_name
  cluster_private_zone    = var.cluster_private_zone
  ##############################################
  # Istio
  ##############################################
  istio_version              = var.istio_version
  istio_ingress_min_pods     = var.istio_ingress_min_pods
  istio_ingress_max_pods     = var.istio_ingress_max_pods
  kiail_version              = var.kiail_version
  kiali_virtual_service_host = var.kiali_virtual_service_host
  ##############################################
  # Prometheus + Grafana
  ##############################################
  enable_prometheus            = var.enable_prometheus
  prometheus_version           = var.prometheus_version
  grafana_virtual_service_host = var.grafana_virtual_service_host
  grafana_version              = var.grafana_version
  cognito_user_pool_id         = module.cognito.cognito_user_pool_id
  ##############################################
  # Jaeger
  ##############################################
  enable_jaeger               = var.enable_jaeger
  jaeger_version              = var.jaeger_version
  jaeger_virtual_service_host = var.jaeger_virtual_service_host
}
