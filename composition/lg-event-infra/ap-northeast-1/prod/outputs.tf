########################################
# VPC
########################################
output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "vpc_instance_tenancy" {
  description = "Tenancy of instances spin up within VPC"
  value       = module.vpc.vpc_instance_tenancy
}

output "vpc_enable_dns_support" {
  description = "Whether or not the VPC has DNS support"
  value       = module.vpc.vpc_enable_dns_support
}

output "vpc_enable_dns_hostnames" {
  description = "Whether or not the VPC has DNS hostname support"
  value       = module.vpc.vpc_enable_dns_hostnames
}

output "vpc_main_route_table_id" {
  description = "The ID of the main route table associated with this VPC"
  value       = module.vpc.vpc_main_route_table_id
}

output "vpc_secondary_cidr_blocks" {
  description = "List of secondary CIDR blocks of the VPC"
  value       = module.vpc.vpc_secondary_cidr_blocks
}

output "private_subnets" {
  description = "List of private subnets"
  value       = module.vpc.private_subnets
}

output "private_subnets_cidr_blocks" {
  description = "List of cidr_blocks of private subnets"
  value       = module.vpc.private_subnets_cidr_blocks
}

output "private_route_table_ids" {
  description = "List of IDs of private route tables"
  value       = module.vpc.private_route_table_ids
}

output "public_subnets" {
  description = "List of public subnets"
  value       = module.vpc.public_subnets
}

output "public_subnets_cidr_blocks" {
  description = "List of cidr_blocks of public subnets"
  value       = module.vpc.public_subnets_cidr_blocks
}

output "public_route_table_ids" {
  description = "List of IDs of public route tables"
  value       = module.vpc.public_route_table_ids
}

output "database_subnets" {
  description = "List of IDs of database subnets"
  value       = module.vpc.database_subnets
}

output "database_subnet_arns" {
  description = "List of ARNs of database subnets"
  value       = module.vpc.database_subnet_arns
}

output "database_subnets_cidr_blocks" {
  description = "List of cidr_blocks of database subnets"
  value       = module.vpc.database_subnets_cidr_blocks
}

output "database_route_table_ids" {
  description = "List of IDs of database route tables"
  value       = module.vpc.database_route_table_ids
}

output "database_subnet_group" {
  description = "ID of database subnet group"
  value       = module.vpc.database_subnet_group
}

output "nat_ids" {
  description = "List of allocation ID of Elastic IPs created { Gateway"
  value       = module.vpc.nat_ids
}

output "nat_public_ips" {
  description = "List of public Elastic IPs created { Gateway"
  value       = module.vpc.nat_public_ips
}

output "natgw_ids" {
  description = "List { IDs"
  value       = module.vpc.natgw_ids
}

output "igw_id" {
  description = "The ID of the Internet Gateway"
  value       = module.vpc.igw_id
}

output "public_network_acl_id" {
  description = "ID of the public network ACL"
  value       = module.vpc.public_network_acl_id
}

output "private_network_acl_id" {
  description = "ID of the private network ACL"
  value       = module.vpc.private_network_acl_id
}

output "database_network_acl_id" {
  description = "ID of the database network ACL"
  value       = module.vpc.database_network_acl_id
}

## Public Security Group ##
output "public_security_group_id" {
  value = module.vpc.public_security_group_id
}

output "public_security_group_vpc_id" {
  value = module.vpc.public_security_group_vpc_id
}

output "public_security_group_owner_id" {
  value = module.vpc.public_security_group_owner_id
}

output "public_security_group_name" {
  value = module.vpc.public_security_group_name
}

## Private Security Group ##
output "private_security_group_id" {
  value = module.vpc.private_security_group_id
}

output "private_security_group_vpc_id" {
  value = module.vpc.private_security_group_vpc_id
}

output "private_security_group_owner_id" {
  value = module.vpc.private_security_group_owner_id
}

output "private_security_group_name" {
  value = module.vpc.private_security_group_name
}

## Database Security Group ##
output "database_security_group_id" {
  value = module.vpc.database_security_group_id
}

output "database_security_group_vpc_id" {
  value = module.vpc.database_security_group_vpc_id
}

output "database_security_group_owner_id" {
  value = module.vpc.database_security_group_owner_id
}

output "database_security_group_name" {
  value = module.vpc.database_security_group_name
}


########################################
# EKS
########################################
## EKS ##
output "eks_cluster_name" {
  description = "The name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "eks_cluster_id" {
  description = "The id of the EKS cluster."
  value       = module.eks.cluster_id
}

output "eks_cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster."
  value       = module.eks.cluster_arn
}

output "eks_cluster_certificate_authority_data" {
  description = "Nested attribute containing certificate-authority-data for your cluster. This is the base64 encoded certificate data required to communicate with your cluster."
  value       = module.eks.cluster_certificate_authority_data
}

output "eks_cluster_endpoint" {
  description = "The endpoint for your EKS Kubernetes API."
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = module.eks.cluster_oidc_issuer_url
}

output "eks_cluster_version" {
  description = "The Kubernetes server version for the EKS cluster."
  value       = module.eks.cluster_version
}

################################################################################
# Cluster Security Group
################################################################################
output "eks_cluster_security_group_arn" {
  description = "Amazon Resource Name (ARN) of the cluster security group"
  value       = module.eks.cluster_security_group_arn
}

output "eks_cluster_security_group_id" {
  description = "Cluster security group that was created by Amazon EKS for the cluster. Managed node groups use this security group for control-plane-to-data-plane communication. Referred to as 'Cluster security group' in the EKS console"
  value       = module.eks.cluster_primary_security_group_id
}

################################################################################
# Node Security Group
################################################################################
output "eks_node_security_group_arn" {
  description = "Amazon Resource Name (ARN) of the node shared security group"
  value       = module.eks.node_security_group_arn
}
output "eks_node_security_group_id" {
  description = "ID of the node shared security group"
  value       = module.eks.node_security_group_id
}

################################################################################
# IRSA
################################################################################
output "eks_oidc_provider" {
  description = "The OpenID Connect identity provider (issuer URL without leading `https://`)"
  value       = module.eks.oidc_provider
}
output "eks_oidc_provider_arn" {
  description = "The ARN of the OIDC Provider if `enable_irsa = true`"
  value       = module.eks.oidc_provider_arn
}

################################################################################
# IAM Role
################################################################################
output "eks_cluster_iam_role_name" {
  description = "IAM role name of the EKS cluster."
  value       = module.eks.cluster_iam_role_name
}

output "eks_cluster_iam_role_arn" {
  description = "IAM role ARN of the EKS cluster."
  value       = module.eks.cluster_iam_role_arn
}

################################################################################
# CloudWatch Log Group
################################################################################
output "eks_cloudwatch_log_group_name" {
  description = "Name of cloudwatch log group created"
  value       = module.eks.cloudwatch_log_group_name
}

output "cloudwatch_log_group_arn" {
  description = "Name of cloudwatch log group created"
  value       = module.eks.cloudwatch_log_group_arn
}

################################################################################
# Self Managed Node Group
################################################################################
output "eks_self_managed_node_groups" {
  description = "Map of attribute maps for all self managed node groups created"
  value       = module.eks.self_managed_node_groups
}

output "eks_self_managed_node_groups_autoscaling_group_names" {
  description = "List of the autoscaling group names created by self-managed node groups"
  value       = module.eks.self_managed_node_groups_autoscaling_group_names
}

################################################################################
# Additional
################################################################################
output "eks_aws_auth_configmap_yaml" {
  description = "A kubernetes configuration to authenticate to this EKS cluster."
  value       = module.eks.aws_auth_configmap_yaml
}

## IRSA ##
## cluster autoscale iam role ##
output "eks_cluster_autoscaler_iam_assumable_role_arn" {
  description = "ARN of IAM role"
  value       = module.eks.cluster_autoscaler_iam_assumable_role_arn
}

output "eks_cluster_autoscaler_iam_assumable_role_name" {
  description = "Name of IAM role"
  value       = module.eks.cluster_autoscaler_iam_assumable_role_name
}

output "eks_cluster_autoscaler_iam_assumable_role_path" {
  description = "Path of IAM role"
  value       = module.eks.cluster_autoscaler_iam_assumable_role_path
}

## cluster autoscale iam policy ##
output "eks_cluster_autoscaler_iam_policy_id" {
  description = "The policy's ID."
  value       = module.eks.cluster_autoscaler_iam_policy_id
}

output "eks_cluster_autoscaler_iam_policy_arn" {
  description = "The ARN assigned by AWS to this policy."
  value       = module.eks.cluster_autoscaler_iam_policy_arn
}

output "eks_cluster_autoscaler_iam_policy_description" {
  description = "The description of the policy."
  value       = module.eks.cluster_autoscaler_iam_policy_description
}

output "eks_cluster_autoscaler_iam_policy_name" {
  description = "The name of the policy."
  value       = module.eks.cluster_autoscaler_iam_policy_name
}

output "eks_cluster_autoscaler_iam_policy_path" {
  description = "The path of the policy in IAM."
  value       = module.eks.cluster_autoscaler_iam_policy_path
}

output "eks_cluster_autoscaler_iam_policy" {
  description = "The policy document."
  value       = module.eks.cluster_autoscaler_iam_policy
}

########################################
# EFS MOUNT TARGET SG
########################################
output "efs_mount_target_security_group_id" {
  value = module.eks.efs_mount_target_security_group_id
}

output "efs_mount_target_security_group_vpc_id" {
  value = module.eks.efs_mount_target_security_group_vpc_id
}

output "efs_mount_target_security_group_name" {
  value = module.eks.efs_mount_target_security_group_name
}

########################################
# EFS
########################################
output "efs_id" {
  value = module.eks.efs_id
}

output "efs_arn" {
  value = module.eks.efs_arn
}

output "efs_dns_name" {
  value = module.eks.efs_dns_name
}

output "efs_mount_target_id" {
  value = module.eks.efs_mount_target_id
}

output "efs_mount_target_dns_name" {
  value = module.eks.efs_mount_target_dns_name
}

output "efs_mount_target_network_interface_id" {
  value = module.eks.efs_mount_target_network_interface_id
}