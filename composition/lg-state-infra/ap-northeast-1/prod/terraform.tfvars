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
# Cognito
########################################
sms_external_id          = "815abf0b-a51b-4b97-bf7e-c98b23d920ce" # random UUID
has_root_domain_a_record = false
ses_domain               = "cresplanex.org"
cognito_from_address     = "noreply@cresplanex.org"
auth_domain              = "auth.admin.cresplanex.org"
admin_domain             = "admin.cresplanex.org"
default_admin = {
  email         = "k.hayashi@cresplanex.com"
  username      = "k.hayashi"
  temp_password = "Password123!"
}

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
lb_client_keep_alive                   = 3600
lb_idle_timeout                        = 600
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
    # Domain Common Node Group
    create_autoscaling_group = true
    name                     = "domain-common"
    ami_type                 = "AL2023_ARM_64_STANDARD"
    use_mixed_instances_policy = true
    instance_type            = "c7g.2xlarge"
    mixed_instances_policy = {
      instances_distribution = {
        on_demand_allocation_strategy            = "prioritized"
        on_demand_base_capacity                  = 4 # 最低0台はオンデマンドで確保
        on_demand_percentage_above_base_capacity = 0
        spot_allocation_strategy                 = "capacity-optimized"
        spot_instance_pools                      = 0
      }
    }
    desired_size             = 4
    min_size                 = 4
    max_size                 = 4
    block_device_mappings    = {}
    node_labels              = "for=domain-common"
    node_taints              = "for=domain-common:NoSchedule"
  },
  {
    # User Profile Node Group
    create_autoscaling_group = true
    name                     = "user-profile"
    ami_type                 = "AL2023_ARM_64_STANDARD"
    use_mixed_instances_policy = true
    instance_type            = "m7g.xlarge"
    mixed_instances_policy = {
      instances_distribution = {
        on_demand_allocation_strategy            = "prioritized"
        on_demand_base_capacity                  = 1 # 最低0台はオンデマンドで確保
        on_demand_percentage_above_base_capacity = 0
        spot_allocation_strategy                 = "capacity-optimized"
        spot_instance_pools                      = 0
      }
    }
    desired_size             = 1
    min_size                 = 1
    max_size                 = 1
    block_device_mappings    = {}
    node_labels              = "for=user-profile"
    node_taints              = "for=user-profile:NoSchedule"
  },
  {
    # User Preference Node Group
    create_autoscaling_group = true
    name                     = "user-preference"
    ami_type                 = "AL2023_ARM_64_STANDARD"
    use_mixed_instances_policy = true
    instance_type            = "m7g.xlarge"
    mixed_instances_policy = {
      instances_distribution = {
        on_demand_allocation_strategy            = "prioritized"
        on_demand_base_capacity                  = 1 # 最低0台はオンデマンドで確保
        on_demand_percentage_above_base_capacity = 0
        spot_allocation_strategy                 = "capacity-optimized"
        spot_instance_pools                      = 0
      }
    }
    desired_size             = 1
    min_size                 = 1
    max_size                 = 1
    block_device_mappings    = {}
    node_labels              = "for=user-preference"
    node_taints              = "for=user-preference:NoSchedule"
  },
  {
    # Organization Node Group
    create_autoscaling_group = true
    name                     = "organization"
    ami_type                 = "AL2023_ARM_64_STANDARD"
    use_mixed_instances_policy = true
    instance_type            = "m7g.xlarge"
    mixed_instances_policy = {
      instances_distribution = {
        on_demand_allocation_strategy            = "prioritized"
        on_demand_base_capacity                  = 1 # 最低0台はオンデマンドで確保
        on_demand_percentage_above_base_capacity = 0
        spot_allocation_strategy                 = "capacity-optimized"
        spot_instance_pools                      = 0
      }
    }
    desired_size             = 1
    min_size                 = 1
    max_size                 = 1
    block_device_mappings    = {}
    node_labels              = "for=organization"
    node_taints              = "for=organization:NoSchedule"
  },
  {
    # Team Node Group
    create_autoscaling_group = true
    name                     = "team"
    ami_type                 = "AL2023_ARM_64_STANDARD"
    use_mixed_instances_policy = true
    instance_type            = "m7g.xlarge"
    mixed_instances_policy = {
      instances_distribution = {
        on_demand_allocation_strategy            = "prioritized"
        on_demand_base_capacity                  = 1 # 最低0台はオンデマンドで確保
        on_demand_percentage_above_base_capacity = 0
        spot_allocation_strategy                 = "capacity-optimized"
        spot_instance_pools                      = 0
      }
    }
    desired_size             = 1
    min_size                 = 1
    max_size                 = 1
    block_device_mappings    = {}
    node_labels              = "for=team"
    node_taints              = "for=team:NoSchedule"
  },
  {
    # Storage Node Group
    create_autoscaling_group = true
    name                     = "storage"
    ami_type                 = "AL2023_ARM_64_STANDARD"
    use_mixed_instances_policy = true
    instance_type            = "m7g.xlarge"
    mixed_instances_policy = {
      instances_distribution = {
        on_demand_allocation_strategy            = "prioritized"
        on_demand_base_capacity                  = 1 # 最低0台はオンデマンドで確保
        on_demand_percentage_above_base_capacity = 0
        spot_allocation_strategy                 = "capacity-optimized"
        spot_instance_pools                      = 0
      }
    }
    desired_size             = 1
    min_size                 = 1
    max_size                 = 1
    block_device_mappings    = {}
    node_labels              = "for=storage"
    node_taints              = "for=storage:NoSchedule"
  },
  {
    # Plan Node Group
    create_autoscaling_group = true
    name                     = "plan"
    ami_type                 = "AL2023_ARM_64_STANDARD"
    use_mixed_instances_policy = true
    instance_type            = "m7g.xlarge"
    mixed_instances_policy = {
      instances_distribution = {
        on_demand_allocation_strategy            = "prioritized"
        on_demand_base_capacity                  = 1 # 最低0台はオンデマンドで確保
        on_demand_percentage_above_base_capacity = 0
        spot_allocation_strategy                 = "capacity-optimized"
        spot_instance_pools                      = 0
      }
    }
    desired_size             = 1
    min_size                 = 1
    max_size                 = 1
    block_device_mappings    = {}
    node_labels              = "for=plan"
    node_taints              = "for=plan:NoSchedule"
  },
  {
    # Auth Node Group
    create_autoscaling_group = true
    name                     = "auth"
    ami_type                 = "AL2023_ARM_64_STANDARD"
    use_mixed_instances_policy = true
    instance_type            = "t4g.medium"
    mixed_instances_policy = {
      instances_distribution = {
        on_demand_allocation_strategy            = "prioritized"
        on_demand_base_capacity                  = 1 # 最低0台はオンデマンドで確保
        on_demand_percentage_above_base_capacity = 0
        spot_allocation_strategy                 = "capacity-optimized"
        spot_instance_pools                      = 0
      }
    }
    desired_size             = 1
    min_size                 = 1
    max_size                 = 1
    block_device_mappings    = {}
    node_labels              = "for=auth"
    node_taints              = "for=auth:NoSchedule"
  },
  {
    # Web Gateway Node Group
    create_autoscaling_group = true
    name                     = "web-gateway"
    ami_type                 = "AL2023_ARM_64_STANDARD"
    use_mixed_instances_policy = true
    instance_type            = "m7g.xlarge"
    mixed_instances_policy = {
      instances_distribution = {
        on_demand_allocation_strategy            = "prioritized"
        on_demand_base_capacity                  = 1 # 最低0台はオンデマンドで確保
        on_demand_percentage_above_base_capacity = 0
        spot_allocation_strategy                 = "capacity-optimized"
        spot_instance_pools                      = 0
      }
    }
    desired_size             = 1
    min_size                 = 1
    max_size                 = 1
    block_device_mappings    = {}
    node_labels              = "for=web-gateway"
    node_taints              = "for=web-gateway:NoSchedule"
  },
  {
    # Tracking Node Group
    create_autoscaling_group = true
    name                     = "tracking"
    ami_type                 = "AL2023_ARM_64_STANDARD"
    use_mixed_instances_policy = true
    instance_type            = "t4g.2xlarge"
    mixed_instances_policy = {
      instances_distribution = {
        on_demand_allocation_strategy            = "prioritized"
        on_demand_base_capacity                  = 1 # 最低0台はオンデマンドで確保
        on_demand_percentage_above_base_capacity = 0
        spot_allocation_strategy                 = "capacity-optimized"
        spot_instance_pools                      = 0
      }
    }
    desired_size             = 1
    min_size                 = 1
    max_size                 = 1
    block_device_mappings    = {}
    node_labels              = "for=tracking"
    node_taints              = "for=tracking:NoSchedule"
  },
  {
    # Connect Node Group
    create_autoscaling_group = true
    name                     = "connect"
    ami_type                 = "AL2023_x86_64_STANDARD"
    use_mixed_instances_policy = true
    instance_type            = "t3.medium"
    mixed_instances_policy = {
      instances_distribution = {
        on_demand_allocation_strategy            = "prioritized"
        on_demand_base_capacity                  = 1 # 最低0台はオンデマンドで確保
        on_demand_percentage_above_base_capacity = 50
        spot_allocation_strategy                 = "capacity-optimized"
        spot_instance_pools                      = 0
      }
    }
    desired_size             = 1
    min_size                 = 1
    max_size                 = 3
    block_device_mappings    = {}
    node_labels              = "for=connect"
    node_taints              = "for=connect:NoSchedule"
  },
  {
    # Other Group
    create_autoscaling_group = true
    name                     = "other"
    ami_type                 = "AL2023_ARM_64_STANDARD"
    use_mixed_instances_policy = true
    instance_type            = "t4g.2xlarge"
    mixed_instances_policy = {
      instances_distribution = {
        on_demand_allocation_strategy            = "prioritized"
        on_demand_base_capacity                  = 1
        on_demand_percentage_above_base_capacity = 0
        spot_allocation_strategy                 = "capacity-optimized"
        spot_instance_pools                      = 0
      }
    }
    desired_size             = 1
    min_size                 = 1
    max_size                 = 1
    block_device_mappings    = {}
    node_labels              = "for=other"
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
istio_ingress_min_pods     = 2
istio_ingress_max_pods     = 5
kiail_version              = "1.89.7"
kiali_virtual_service_host = "kiali.state.api.cresplanex.org"
##############################################
# Prometheus + Grafana
##############################################
enable_prometheus            = true
prometheus_version           = "65.2.0"
prometheus_virtual_service_host = "prometheus.state.api.cresplanex.org"
grafana_virtual_service_host = "grafana.state.api.cresplanex.org"
grafana_version              = "8.5.4"
##############################################
# Jaeger
##############################################
enable_jaeger               = true
jaeger_version              = "3.3.0"
jaeger_virtual_service_host = "jaeger.state.api.cresplanex.org"
##############################################
# Node termination handler
##############################################
enable_node_termination_handler  = false
node_termination_handler_version = "0.21.0"
##############################################
# Descheduler
##############################################
enable_descheduler = false
##############################################
# Secret Manager
##############################################
secret_stores_csi_version = "1.4.6"
