########################################
# Environment setting
########################################
region           = "ap-northeast-1"
profile_name     = "terraform"
env              = "prod"
application_name = "lg-state-infra"
app_name         = "lg-state-infra"

########################################
# VPC
########################################
cidr                                 = "10.1.0.0/16"
azs                                  = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
public_subnets                       = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"] # 256 IPs per subnet
private_subnets                      = ["10.1.101.0/24", "10.1.102.0/24", "10.1.103.0/24"]
database_subnets                     = ["10.1.111.0/24", "10.1.112.0/24", "10.1.113.0/24"]
enable_dns_hostnames                 = "true"
enable_dns_support                   = "true"
enable_nat_gateway                   = "true" # need internet connection for worker nodes in private subnets to be able to join the cluster
single_nat_gateway                   = "true"
enable_flow_log                      = "false"
create_flow_log_cloudwatch_iam_role  = "false"
create_flow_log_cloudwatch_log_group = "false"
flow_log_max_aggregation_interval    = null


## Public Security Group ##
public_ingress_with_cidr_blocks = []

## Public Bastion Security Group ##
public_bastion_ingress_with_cidr_blocks = []

########################################
# Bastion
########################################
bastion_instance_type       = "t3.micro"
bastion_instance_monitoring = false

########################################
# EKS
########################################
create_eks                             = true
cluster_name                           = "LGStateApNortheast1Prod"
cluster_version                        = "1.30"
cluster_enabled_log_types              = ["audit", "api", "authenticator"]
cloudwatch_log_group_retention_in_days = 90
create_admin_access_entry              = true
cluster_admin_role                     = "ClusterAdmin"
additional_accesss_entries = {
  # "User1" = {
  #   principal_arn = "arn:aws:iam::123456789012:role/User1"
  #   kubernetes_groups = []
  #   policy_associations = {
  #     "AmazonEKS_CNI_Policy" = {
  #       policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
  #       access_scope = {
  #         type       = "namespace"
  #         namespaces = ["service1"]
  #       }
  #     }
  #   }
  # }
}
node_groups = [
  {
    create_autoscaling_group = true
    name                     = "app-1"
    ami_type                 = "AL2023_x86_64_STANDARD"
    instance_type            = "t3.medium"
    desired_size             = 2
    min_size                 = 1
    max_size                 = 5
    #   block_device_mappings = {
    #     device_name = "/dev/xvda"
    #     ebs = {
    #       volume_size           = 20
    #       volume_type           = "gp3"
    #       delete_on_termination = true
    #       encrypted             = true
    #     }
    #   }
    node_labels = "for=app"
    # node_taints = "for=app:NoSchedule"
    node_taints = ""
  }
]
########################################
# EKS IRSA
########################################
additional_irsa_roles = {
  # "app-1" = {
  #   role_name = "app-1"
  #   cluster_service_accounts = [
  #     {
  #       namespace         = "default"
  #       service_account   = "default"
  #       labels            = {}
  #       image_pull_secret = ""
  #     }
  #   ]
  #   role_policy_arns = [
  #     "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  #   ]
  # }
}
########################################
# EBS CSI Driver
########################################
enable_ebs_csi = true
########################################
##  EFS CSI Driver
########################################
enable_efs_csi = false
# --- Istio ---
##############################################
# ACM + Route53
##############################################
route53_zone_domain_name  = "cresplanex.org"
acm_domain_name           = "*.state.api.cresplanex.org"
subject_alternative_names = ["state.api.cresplanex.org"]
aws_route53_record_ttl    = 300
##############################################
# Route53 Config
##############################################
public_root_domain_name = "state.api.cresplanex.org"
cluster_private_zone    = "eks.local"
##############################################
# Istio
##############################################
istio_version              = "1.23.2"
istio_ingress_min_pods     = 1
istio_ingress_max_pods     = 5
kiail_version              = "1.89.7"
kiali_virtual_service_host = "kiali.state.api.cresplanex.org"

