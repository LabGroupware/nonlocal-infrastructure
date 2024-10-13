## Metatada ##
variable "region" {}

variable "profile_name" {}

variable "account_id" {}

variable "env" {}

variable "app_name" {}

variable "tags" {
  type = map(string)
}

variable "region_tag" {
  type = map(any)

  default = {
    "us-east-1"      = "ue1"
    "us-west-1"      = "uw1"
    "eu-west-1"      = "ew1"
    "eu-central-1"   = "ec1"
    "ap-northeast-1" = "apne1"
  }
}

variable "environment_tag" {
  type = map(any)

  default = {
    "prod"    = "prod"
    "qa"      = "qa"
    "staging" = "staging"
    "dev"     = "dev"
  }
}

## IAM ##
variable "cluster_iam_role_additional_policies" {
  description = "Additional IAM policies to attach to the EKS cluster role"
  type        = map(string)
}

## Access Entry ##
variable "create_admin_access_entry" {
  description = "Create an admin access entry in the security group"
  type        = bool
}

variable "cluster_admin_role" {
  description = "IAM role to attach to the EKS cluster to allow full access"
  type        = string
}

variable "additional_accesss_entries" {
  description = "Additional access entries to add to the security group"
  type = map(object({
    principal_arn     = string
    kubernetes_groups = list(string)
    policy_associations = map(object({
      policy_arn = string
      access_scope = object({
        type       = string
        namespaces = list(string)
      })
    }))
  }))
}

## EKS ##
variable "create_eks" {}
variable "cluster_version" {
  description = "Kubernetes version to use for the EKS cluster."
  type        = string
}
variable "cluster_name" {}
variable "cluster_enabled_log_types" {
  description = "A list of the desired control plane logs to enable. For more information, see Amazon EKS Control Plane Logging documentation (https://docs.aws.amazon.com/eks/latest/userguide/control-plane-logs.html)"
  type        = list(string)
  default     = ["audit", "api", "authenticator"]
}
variable "subnets" {
  type = list(string)
}
variable "cluster_endpoint_public_access_cidrs" {
  type        = list(string)
  description = "Value of the CIDR block that can access the public endpoint of the EKS cluster"
  default     = ["0.0.0.0/0"]
}
variable "cluster_service_ipv4_cidr" {
  description = "CIDR block for the Kubernetes service IPs"
  type        = string
  default     = "172.20.0.0/16"
}
variable "cloudwatch_log_group_retention_in_days" {
  description = "Number of days to retain log events. If cluster_enabled_log_types is empty, this will be ignored."
  type        = number
}
variable "vpc_id" {}

variable "node_instance_default_keypair" {
  description = "The key pair to use for SSH access to the EC2 instances"
  type        = string
}

## Self Managed Node Group ##
variable "node_groups" {
  description = "Map of self-managed node group definitions to create"
  type        = any
}
# variable "node_groups" {
#   description = "Map of self-managed node group definitions to create"
#   type = list(object({
#     create_autoscaling_group = bool
#     name                     = string
#     ami_type                 = string
#     instance_type            = string
#     desired_size             = number
#     min_size                 = number
#     max_size                 = number
#     key_name                 = optional(string)
#     # スポットインスタンスが中断される可能性がある場合, ASGが自動的にインスタンスを入れ替える仕組みを提供
#     capacity_rebalance = optional(bool)
#     # Auto Scaling Groupが望ましいキャパシティを達成するまでのタイムアウトを指定
#     wait_for_capacity_timeout = optional(string)
#     # インスタンスが起動後にヘルスチェックを開始するまでの猶予時間を設定
#     health_check_grace_period = optional(number)
#     # スケールイン/スケールアウトアクションの後にASGが次のスケーリングアクションを実行するまでの待機時間を指定
#     default_cooldown = optional(number)
#     # 新しく起動したインスタンスがAuto Scaling Groupに参加してから, スケーリングアクションに含まれるまでのウォームアップ期間
#     default_instance_warmup = optional(number)
#     # 失敗したスケーリングアクティビティを無視して続行するかどうか
#     ignore_failed_scaling_activities = optional(bool)
#     # Auto Scaling グループ内のインスタンスを終了する方法を決定するポリシーのリスト
#     # どのインスタンスから終了するかを決定するために使用される
#     termination_policies = optional(list(string))
#     # 自動スケーリングプロセスの一時停止を指定する設定
#     suspended_processes = optional(list(string))
#     # インスタンスが存在できる最大期間を指定する設定
#     max_instance_lifetime = optional(number)
#     # 収集するメトリクスのリスト
#     enabled_metrics = optional(list(string))
#     # メトリクスの収集間隔を指定する設定(`1Minute`のみサポート)
#     metrics_granularity = optional(string)
#     # Auto Scaling Groupに関連するサービスにリンクされたロールのARNを指定
#     service_linked_role_arn = optional(string)
#     # ノードがクラスターに参加する前に設定など
#     initial_lifecycle_hooks = optional(list(map(string)))
#     # ノードのセキュリティパッチやソフトウェアの更新を適用するためにノードのリフレッシュが必要な場合
#     # Defaultでも min_healthy_percentage = 66で, RollingUpdateでのみ設定されている
#     instance_refresh = optional(object({
#       strategy = string
#       preferences = object({
#         checkpoint_delay       = number
#         checkpoint_percentages = list(number)
#         instance_warmup        = number
#         max_healthy_percentage = number
#         min_healthy_percentage = number
#         skip_matching          = bool
#         auto_rollback          = bool
#         alarm_specification = object({
#           alarms = list(string)
#         })
#         scale_in_protected_instances = string
#         standby_instances            = string
#       })
#       triggers = list(string)
#     }))
#     # 複数のインスタンスタイプを組み合わせ, リソースの利用効率を高めつつ, コスト削減を図りたい場合
#     # 複数のNodeGroupを作成での対応が冗長になる場合
#     # (ほとんど同じスペックではあるが, 2割はspotインスタンスで安く済ませたいなど)
#     # ただし, k8sとの連携は不可なので, 可能な限り複数のNodeGroupを作成することを推奨
#     use_mixed_instances_policy = optional(bool)
#     mixed_instances_policy = optional(object({
#       instances_distribution = object({
#         on_demand_allocation_strategy            = string
#         on_demand_base_capacity                  = number
#         on_demand_percentage_above_base_capacity = number
#         spot_allocation_strategy                 = string
#         spot_instance_pools                      = number
#         spot_max_price                           = string
#       })
#       launch_template = object({
#         launch_template_specification = object({
#           launch_template_id   = string
#           launch_template_name = string
#           version              = string
#         })
#         override = list(object({
#           instance_type = string
#           instance_requirements = object({
#             accelerator_count = object({
#               min = number
#               max = number
#             })
#             accelerator_manufacturers = list(string)
#             accelerator_names         = list(string)
#             accelerator_total_memory_mib = object({
#               min = number
#               max = number
#             })
#             accelerator_types      = list(string)
#             allowed_instance_types = list(string)
#             bare_metal             = string
#             baseline_ebs_bandwidth_mbps = object({
#               min = number
#               max = number
#             })
#             burstable_performance                                   = string
#             cpu_manufacturers                                       = list(string)
#             excluded_instance_types                                 = list(string)
#             instance_generations                                    = list(string)
#             local_storage                                           = string
#             local_storage_types                                     = list(string)
#             max_spot_price_as_percentage_of_optimal_on_demand_price = number
#             memory_gib_per_vcpu = object({
#               min = number
#               max = number
#             })
#             memory_mib = object({
#               min = number
#               max = number
#             })
#             network_bandwidth_gbps = object({
#               min = number
#               max = number
#             })
#             network_interface_count = object({
#               min = number
#               max = number
#             })
#             on_demand_max_price_percentage_over_lowest_price = number
#             require_hibernate_support                        = string
#             spot_max_price_percentage_over_lowest_price      = number
#             total_local_storage_gb = object({
#               min = number
#               max = number
#             })
#             vcpu_count = object({
#               min = number
#               max = number
#             })
#           })
#           launch_template_specification = object({
#             launch_template_id   = string
#             launch_template_name = string
#             version              = string
#           })
#           weighted_capacity = number
#         }))
#       })
#     }))
#     schedules = optional(map(object({
#       min_size     = number
#       max_size     = number
#       desired_size = number
#       start_time   = string
#       end_time     = string
#       time_zone    = string
#       recurrence   = string
#     })))
#     iam_role_additional_policies           = optional(map(string))
#     iam_role_policy_statements             = optional(list(any))
#     launch_template_default_version        = optional(string)
#     update_launch_template_default_version = optional(bool)
#     block_device_mappings = optional(list(object({
#       device_name = string
#       ebs = object({
#         delete_on_termination = bool
#         encrypted             = bool
#         iops                  = number
#         kms_key_id            = string
#         snapshot_id           = string
#         volume_size           = number
#         volume_type           = string
#       })
#       no_device = string
#       virtual_name = string
#     })))
#     # 予約インスタンスを使用する場合は以下の設定を追加
#     capacity_reservation_specification = optional(object({
#       capacity_reservation_preference = string
#       capacity_reservation_target = optional(object({
#         capacity_reservation_id                 = optional(string)
#         capacity_reservation_resource_group_arn = optional(string)
#       }))
#     }))
#     # CPUの使用限界を設定する場合は以下の設定を追加(サポートしていないInstanceTypeもある)
#     cpu_options = optional(object({
#       core_count       = optional(number)
#       threads_per_core = optional(number)
#     }))
#     # クレジットスペック(クレジットが尽きるとCPUが低下する(T2でDefault) or 追加課金される(T3でDefault)など)の設定を行う場合は以下の設定を追加
#     credit_specification = optional(object({
#       cpu_credits = optional(string)
#     }))
#     # グラフィックス集約型や機械学習などでの利用では特に有効だが, 現段階でWindowsのみ対応
#     elastic_gpu_specifications = optional(list(object({
#       type = optional(string)
#     })))
#     # GPUを使用することなく, ディープラーニング推論作業のコスト効率を大幅に向上
#     elastic_inference_accelerator = optional(map(string))
#     # AWSのNitroシステム上で動作する分離された, セキュリティに特化した環境を提供する技術であるNitro Enclavesを使用するための設定オプション
#     enclave_options = optional(object({
#       enabled = optional(bool)
#     }))
#     # Spotインスタンスを使用したい場合
#     instance_market_options = optional(object({
#       market_type = string
#       spot_options = object({
#         block_duration_minutes         = number
#         instance_interruption_behavior = string
#         max_price                      = string
#         spot_instance_type             = string
#         valid_until                    = string
#       })
#     }))
#     # ライセンスポリシーをEC2インスタンスに適用する場合
#     license_specifications = optional(list(object({
#       license_configuration_arn = string
#     })))
#     metadata_options = optional(object({
#       # インスタンスメタデータサービスへのHTTPエンドポイントを有効にするかどうか
#       http_endpoint = string
#       # インスタンスメタデータリクエストで必要とされるトークンの使用を要求するかどうか
#       http_tokens = string
#       # メタデータAPIへのリクエストがどれだけのネットワークホップを超えることが許可されるか
#       http_put_response_hop_limit = number
#       # インスタンスメタデータサービスへのIPv6を使用したHTTPアクセスを有効にするか
#       http_protocol_ipv6 = string
#       # インスタンスメタデータサービスからのインスタンスタグへのアクセスを有効にするかどうか
#       instance_metadata_tags = string
#     }))
#     # Auto Scaling Group内にあらかじめウォームアップされたインスタンスを保持するための設定
#     warm_pool = optional(object({
#       instance_reuse_policy       = string
#       max_group_prepared_capacity = number
#       min_size                    = number
#       pool_state                  = string
#     }))
#     # クラスターのシャットダウンやノードグループの削除時に, 適切な時間を持たせる必要がある場合(Defaultは10m)
#     delete_timeout = optional(string)
#     # Elastic Fabric Adapter (EFA) のサポートを有効にするための設定
#     enable_efa_support = optional(bool)
#     # ex. env=prod,unmanaged-node=true,k8s_namespace=prod
#     node_labels = optional(string)
#     # ex. prod-only=true:NoSchedule
#     node_taints = optional(string)

#     # User data that is injected into the user data script ahead of the EKS bootstrap script.`
#     pre_bootstrap_user_data = optional(string)
#     # User data that is appended to the user data script after of the EKS bootstrap script.`
#     post_bootstrap_user_data = optional(string)
#     # Array of cloud-init document parts that are created before the nodeadm document part
#     cloudinit_pre_nodeadm = optional(list(object({
#       content      = string
#       content_type = optional(string)
#       filename     = optional(string)
#       merge_type   = optional(string)
#     })))
#     # Array of cloud-init document parts that are created after the nodeadm document part
#     cloudinit_post_nodeadm = optional(list(object({
#       content      = string
#       content_type = optional(string)
#       filename     = optional(string)
#       merge_type   = optional(string)
#     })))
#   }))
# }

########################################
##  IRSA
########################################
variable "additional_irsa_roles" {
  description = "Additional IAM roles to create for IRSA"
  type = map(object({
    role_name        = string
    role_policy_arns = map(string)
    cluster_service_accounts = map(object({
      namespace               = string
      service_account         = string
      lables                  = map(string)
      image_pull_secret_names = optional(list(string))
    }))
  }))
}

########################################
##  EBS CSI Driver
########################################
variable "enable_ebs_csi" {
  description = "Enable EBS CSI Driver"
  type        = bool
}

########################################
##  EFS CSI Driver
########################################
variable "enable_efs_csi" {
  description = "Enable EFS CSI Driver"
  type        = bool
}

# --- Istio ---
##############################################
# ACM + Route53
##############################################
variable "route53_zone_domain_name" {
  type        = string
  description = "The domain name to use for the Route53 zone"
}
variable "acm_domain_name" {
  type        = string
  description = "The domain name to use for the ACM certificate"
}
variable "subject_alternative_names" {
  type        = list(string)
  description = "The subject alternative names to use for the ACM certificate"
}
variable "aws_route53_record_ttl" {
  type        = number
  description = "The TTL to use for the Route53 record"
  default     = 300
}

##############################################
# ELB
##############################################
variable "nlb_ingress_internal" {
  type        = bool
  description = "Indicates whether the Network Load Balancer (ELB) for the EKS cluster should be internal, restricting access to within the AWS network."
  default     = false
}

variable "lb_subnet_ids" {
  type        = list(string)
  description = "The subnet IDs to use for the load balancer(Public Subnets)"
}

variable "proxy_protocol_v2" {
  type        = bool
  description = "Enables or disables Proxy Protocol v2 on the Network Load Balancer, used for preserving client IP addresses and other connection information."
  default     = false
}

variable "enable_vpc_link" {
  type        = bool
  description = "Create VPC Link associated to Network Load Balancing (For API Gateway to communicate with EKS)"
  default     = false
}

#########################
# Route53 Config
#########################

variable "cluster_private_zone" {
  type        = string
  description = "The private DNS zone name for the EKS cluster in AWS Route53. This zone is used for internal DNS resolution within the cluster."
  default     = "k8s.cluster"
}

##############################################
# Istio
##############################################

variable "istio_version" {
  type        = string
  description = "The version of Istio to install"
}

variable "istio_ingress_min_pods" {
  type        = number
  description = "The minimum number of pods for the Istio ingress gateway"
  default     = 1
}

variable "istio_ingress_max_pods" {
  type        = number
  description = "The maximum number of pods for the Istio ingress gateway"
  default     = 5
}

variable "kiail_version" {
  type        = string
  description = "The version of Kiali to install"
}

variable "kiali_virtual_service_host" {
  type        = string
  description = "The hostname for the Kiali virtual service, a part of Istio's service mesh visualization. It provides insights into the mesh topology and performance."
}

##############################################
# Prometheus + Grafana
##############################################
# variable "enable_prometheus" {
#   type        = bool
#   description = "Enable managed Prometheus"
# }

# variable "grafana_virtual_service_host" {
#   type        = string
#   description = "The hostname for the Grafana virtual service, used in Istio routing. This host is used to access Grafana dashboards for monitoring metrics."
# }

# variable "prometheus_access_type" {
#   type        = string
#   description = "Specifies the access type for managed Prometheus. 'CURRENT_ACCOUNT' limits access to the current AWS account, ensuring isolated and secure access to the monitoring data."
#   default     = "CURRENT_ACCOUNT"
# }

# variable "grafana_permission_type" {
#   type        = string
#   description = "Defines the permission model for managed Grafana. 'SERVICE_MANAGED' allows AWS to manage permissions, simplifying the setup and management of Grafana."
#   default     = "SERVICE_MANAGED"
# }

# variable "grafana_authentication_providers" {
#   type        = list(string)
#   description = "A list of authentication providers for managed Grafana. For example, 'SAML' can be used for integrating with identity providers, ensuring secure and centralized user management."
#   default     = ["SAML"]
# }

# variable "grafana_datasources" {
#   type        = list(string)
#   description = "Specifies the data sources that managed Grafana can access. Includes options like 'CLOUDWATCH', 'PROMETHEUS', and 'XRAY', providing a wide range of data for comprehensive monitoring solutions."
#   default     = ["CLOUDWATCH", "PROMETHEUS", "XRAY"]
# }

# variable "grafana_notification_destinations" {
#   type        = list(string)
#   description = "Lists the notification channels supported by managed Grafana. For instance, 'SNS' allows Grafana to send alerts and notifications through AWS Simple Notification Service."
#   default     = ["SNS"]
# }

# variable "grafana_subnets" {
#   type        = list(string)
#   description = "The subnets to use for the managed Grafana workspace"
# }

# ##############################################
# # Jaeger
# ##############################################
# variable "enable_jaeger" {
#   type        = bool
#   description = "Enable Jaeger for distributed tracing"
# }

# variable "jaeger_virtual_service_host" {
#   type        = string
#   description = "The hostname for the Jaeger virtual service, used in Istio routing. This host is used to access Jaeger for distributed tracing."
# }

# ##############################################
# # Node termination handler
# ##############################################
# variable "node_termination_handler_toggle" {
#   type        = bool
#   description = "Enable the node termination handler"
# }
