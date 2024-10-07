## EKS ##
################################################################################
# Cluster
################################################################################
output "cluster_name" {
  description = "The name of the EKS cluster."
  value       = module.eks_cluster.cluster_name
}

output "cluster_id" {
  description = "The id of the EKS cluster."
  value       = module.eks_cluster.cluster_id
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = module.eks_cluster.cluster_oidc_issuer_url
}

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster."
  value       = module.eks_cluster.cluster_arn
}

output "cluster_certificate_authority_data" {
  description = "Nested attribute containing certificate-authority-data for your cluster. This is the base64 encoded certificate data required to communicate with your cluster."
  value       = module.eks_cluster.cluster_certificate_authority_data
}

output "cluster_endpoint" {
  description = "The endpoint for your EKS Kubernetes API."
  value       = module.eks_cluster.cluster_endpoint
}

output "cluster_version" {
  description = "The Kubernetes server version for the EKS cluster."
  value       = module.eks_cluster.cluster_version
}

output "cluster_platform_version" {
  description = "Platform version for the cluster"
  value       = module.eks_cluster.cluster_platform_version
}

output "cluster_status" {
  description = "Status of the EKS cluster. One of `CREATING`, `ACTIVE`, `DELETING`, `FAILED`"
  value       = module.eks_cluster.cluster_status
}

################################################################################
# Cluster Security Group
################################################################################
output "cluster_primary_security_group_id" {
  description = "Cluster security group that was created by Amazon EKS for the cluster. Managed node groups use this security group for control-plane-to-data-plane communication. Referred to as 'Cluster security group' in the EKS console"
  value       = module.eks_cluster.cluster_primary_security_group_id
}

output "cluster_security_group_arn" {
  description = "Amazon Resource Name (ARN) of the cluster security group"
  value       = module.eks_cluster.cluster_security_group_arn
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster."
  value       = module.eks_cluster.cluster_security_group_id
}

################################################################################
# Node Security Group
################################################################################
output "node_security_group_arn" {
  description = "Amazon Resource Name (ARN) of the node shared security group"
  value       = module.eks_cluster.node_security_group_arn
}

output "node_security_group_id" {
  description = "ID of the node shared security group"
  value       = module.eks_cluster.node_security_group_id
}

################################################################################
# IRSA
################################################################################
output "oidc_provider" {
  description = "The OpenID Connect identity provider (issuer URL without leading `https://`)"
  value       = module.eks_cluster.oidc_provider
}
output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider if `enable_irsa = true`"
  value       = module.eks_cluster.oidc_provider_arn
}

output "cluster_tls_certificate_sha1_fingerprint" {
  description = "The SHA1 fingerprint of the public key of the cluster's certificate"
  value       = module.eks_cluster.cluster_tls_certificate_sha1_fingerprint
}

################################################################################
# IAM Role
################################################################################
output "cluster_iam_role_name" {
  description = "IAM role name of the EKS cluster."
  value       = module.eks_cluster.cluster_iam_role_name
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN of the EKS cluster."
  value       = module.eks_cluster.cluster_iam_role_arn
}

output "cluster_iam_role_unique_id" {
  description = "Stable and unique string identifying the IAM role"
  value       = module.eks_cluster.cluster_iam_role_unique_id
}

################################################################################
# EKS Addons
################################################################################

output "cluster_addons" {
  description = "Map of attribute maps for all EKS cluster addons enabled"
  value       = module.eks_cluster.cluster_addons
}

################################################################################
# EKS Identity Provider
################################################################################

output "cluster_identity_providers" {
  description = "Map of attribute maps for all EKS identity providers enabled"
  value       = module.eks_cluster.cluster_identity_providers
}

################################################################################
# CloudWatch Log Group
################################################################################
output "cloudwatch_log_group_name" {
  description = "Name of cloudwatch log group created"
  value       = module.eks_cluster.cloudwatch_log_group_name
}

output "cloudwatch_log_group_arn" {
  description = "Arn of cloudwatch log group created"
  value       = module.eks_cluster.cloudwatch_log_group_arn
}

################################################################################
# Fargate Profile
################################################################################
output "fargate_profiles" {
  description = "Map of attribute maps for all EKS Fargate Profiles created"
  value       = module.eks_cluster.fargate_profiles
}

################################################################################
# EKS Managed Node Group
################################################################################

output "eks_managed_node_groups" {
  description = "Map of attribute maps for all EKS managed node groups created"
  value       = module.eks_cluster.eks_managed_node_groups
}

output "eks_managed_node_groups_autoscaling_group_names" {
  description = "List of the autoscaling group names created by EKS managed node groups"
  value       = module.eks_cluster.eks_managed_node_groups_autoscaling_group_names
}

################################################################################
# Self Managed Node Group
################################################################################
output "self_managed_node_groups" {
  description = "Map of attribute maps for all self managed node groups created"
  value       = module.eks_cluster.self_managed_node_groups
}

output "self_managed_node_groups_autoscaling_group_names" {
  description = "List of the autoscaling group names created by self-managed node groups"
  value       = module.eks_cluster.self_managed_node_groups_autoscaling_group_names
}

################################################################################
# Additional
################################################################################
output "aws_auth_configmap_yaml" {
  description = "A kubernetes configuration to authenticate to this EKS cluster."
  value       = module.eks_cluster.aws_auth_configmap_yaml
}


# ## IRSA ##
## cluster autoscale iam role ##
output "cluster_autoscaler_iam_assumable_role_arn" {
  description = "ARN of IAM role"
  value       = module.cluster_autoscaler_iam_assumable_role.arn
}

output "cluster_autoscaler_iam_assumable_role_name" {
  description = "Name of IAM role"
  value       = module.cluster_autoscaler_iam_assumable_role.name
}

output "cluster_autoscaler_iam_assumable_role_path" {
  description = "Path of IAM role"
  value       = module.cluster_autoscaler_iam_assumable_role.path
}

## cluster autoscale iam policy ##
output "cluster_autoscaler_iam_policy_id" {
  description = "The policy's ID."
  value       = module.cluster_autoscaler_iam_policy.id
}

output "cluster_autoscaler_iam_policy_arn" {
  description = "The ARN assigned by AWS to this policy."
  value       = module.cluster_autoscaler_iam_policy.arn
}

output "cluster_autoscaler_iam_policy_description" {
  description = "The description of the policy."
  value       = module.cluster_autoscaler_iam_policy.description
}

output "cluster_autoscaler_iam_policy_name" {
  description = "The name of the policy."
  value       = module.cluster_autoscaler_iam_policy.name
}

output "cluster_autoscaler_iam_policy_path" {
  description = "The path of the policy in IAM."
  value       = module.cluster_autoscaler_iam_policy.path
}

output "cluster_autoscaler_iam_policy" {
  description = "The policy document."
  value       = module.cluster_autoscaler_iam_policy.policy
}

########################################
# EFS MOUNT TARGET SG
########################################
output "efs_mount_target_security_group_id" {
  value = module.efs_security_group.this_security_group_id
}

output "efs_mount_target_security_group_vpc_id" {
  value = module.efs_security_group.this_security_group_vpc_id
}

output "efs_mount_target_security_group_name" {
  value = module.efs_security_group.this_security_group_name
}

########################################
# EFS
########################################
output "efs_id" {
  value = module.efs.efs_id
}

output "efs_arn" {
  value = module.efs.efs_arn
}

output "efs_dns_name" {
  value = module.efs.efs_dns_name
}

output "efs_mount_target_id" {
  value = module.efs.efs_mount_target_id
}

output "efs_mount_target_dns_name" {
  value = module.efs.efs_mount_target_dns_name
}

output "efs_mount_target_network_interface_id" {
  value = module.efs.efs_mount_target_network_interface_id
}