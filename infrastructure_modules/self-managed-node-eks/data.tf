# current account ID
data "aws_caller_identity" "this" {}

locals {
  ########################################
  ## EKS IAM Role
  ########################################
  cluster_iam_role_name        = "EKS${var.cluster_name}Role"
  cluster_iam_role_description = "IAM role for EKS cluster ${var.cluster_name}"
  cluster_iam_role_tags = merge(
    tomap({
      "Name" = local.cluster_iam_role_name
    })
  )
  cluster_encryption_policy_name        = "EKS${var.cluster_name}ClusterEncryption"
  cluster_encryption_policy_description = "EKS cluster encryption policy for cluster ${var.cluster_name}"
  cluster_encryption_policy_path        = "/${var.app_name}/${var.env}/${var.region_tag[var.region]}/"
  cluster_encryption_policy_tags = merge(
    tomap({
      "Name" = local.cluster_encryption_policy_name
    })
  )
  dataplane_wait_duration = "30s"

  ########################################
  ## Access Entry
  ########################################
  executors = {
    executor = {
      principal_arn     = "arn:aws:iam::${data.aws_caller_identity.this.account_id}:user/${var.profile_name}"
      type              = "STANDARD"
      kubernetes_groups = []

      policy_associations = {
        "cluster-autoscaler" = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }
  admin_access_entry = var.create_admin_access_entry ? {
    cluster-administrator = {
      principal_arn     = data.aws_iam_role.admin[0].arn
      type              = "STANDARD"
      kubernetes_groups = []

      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
  } } : {}
  additional_access_entries = {
    for access_entry in var.additional_accesss_entries : access_entry.key => {
      principal_arn     = access_entry.value.principal_arn
      type              = "STANDARD"
      kubernetes_groups = access_entry.value.kubernetes_groups

      policy_associations = {
        for policy_association in access_entry.value.policy_associations : policy_association.key => {
          policy_arn   = policy_association.value.policy_arn
          access_scope = policy_association.value.access_scope
        }
      }
    }
  }
  access_entries = merge(local.executors, local.admin_access_entry, local.additional_access_entries)

  ########################################
  ##  KMS for K8s secret's DEK (data encryption key) encryption
  ########################################
  k8s_secret_kms_key_name                    = "alias/cmk-${var.region_tag[var.region]}-${var.env}-k8s-secret-dek"
  k8s_secret_kms_key_description             = "Kms key used for encrypting K8s secret DEK (data encryption key)"
  k8s_secret_kms_key_deletion_window_in_days = "30"
  k8s_secret_kms_key_tags = merge(
    var.tags,
    tomap({
      "Name" = local.k8s_secret_kms_key_name
    })
  )

  ########################################
  ##  KMS For EKS CloudWatch logging
  ########################################
  eks_cloudwatch_kms_key_name                    = "alias/cmk-${var.region_tag[var.region]}-${var.env}-eks-cloudwatch-logs"
  eks_cloudwatch_kms_key_description             = "Kms key used for encrypting EKS CloudWatch logs"
  eks_cloudwatch_kms_key_deletion_window_in_days = "30"
  eks_cloudwatch_kms_key_tags = merge(
    var.tags,
    tomap({
      "Name" = local.eks_cloudwatch_kms_key_name
    })
  )

  ########################################
  ##  EKS CloudWatch logging
  ########################################
  create_cloudwatch_log_group = var.create_eks && length(var.cluster_enabled_log_types) > 0 ? true : false

  ########################################
  ## EKS Security Group
  ########################################
  cluster_security_group_name        = "scg-${var.app_name}-${var.region_tag[var.region]}-${var.env}-cluster"
  cluster_security_group_description = "Security group for cluster subnets"

  ########################################
  ## EKS Node Security Group
  ########################################
  node_security_group_name        = "scg-${var.app_name}-${var.region_tag[var.region]}-${var.env}-node"
  node_security_group_description = "Security group for node subnets"

  iam_role_path = "/${var.app_name}/${var.env}/${var.region_tag[var.region]}/"
  ########################################
  ## EKS Node Group
  ########################################
  node_instance_name_prefix = "instance-${var.app_name}-${var.region_tag[var.region]}-${var.env}-"
  node_groups = { for ng in var.node_groups : ng.name => {
    create_autoscaling_group         = ng.create_autoscaling_group
    name                             = format("%s%s", local.node_instance_name_prefix, try(ng.name, "default"))
    use_name_prefix                  = false
    key_name                         = try(ng.key_name, var.node_instance_default_keypair)
    subnet_ids                       = var.subnets
    max_size                         = try(ng.max_size, 3)
    min_size                         = try(ng.min_size, 1)
    desired_size                     = try(ng.desired_size, 1)
    capacity_rebalance               = try(ng.capacity_rebalance, null)
    wait_for_capacity_timeout        = try(ng.wait_for_capacity_timeout, null)
    health_check_grace_period        = try(ng.health_check_grace_period, null)
    default_cooldown                 = try(ng.default_cooldown, null)
    default_instance_warmup          = try(ng.default_instance_warmup, null)
    ignore_failed_scaling_activities = try(ng.ignore_failed_scaling_activities, null)
    termination_policies             = try(ng.termination_policies, [])
    suspended_processes              = try(ng.suspended_processes, [])
    max_instance_lifetime            = try(ng.max_instance_lifetime, null)
    enabled_metrics                  = try(ng.enabled_metrics, [])
    metrics_granularity              = try(ng.metrics_granularity, null)
    service_linked_role_arn          = try(ng.service_linked_role_arn, null)
    initial_lifecycle_hooks          = try(ng.initial_lifecycle_hooks, [])
    instance_refresh = try(ng.instance_refresh, {
      strategy = "Rolling"
      preferences = {
        min_healthy_percentage = 66
      }
    })
    use_mixed_instances_policy = try(ng.use_mixed_instances_policy, false)
    mixed_instances_policy     = try(ng.mixed_instances_policy, null)

    ################################################################################
    # User Data
    ################################################################################
    ami_type = try(ng.ami_type, "AL2_x86_64")
    # for unmanaged nodes, taints and labels work only with extra-arg, not ASG tags
    bootstrap_extra_args = format("--kubelet-extra-args%s%s",
      lookup(ng, "node_labels", null) != null ? format(" --node-labels=%s", ng.node_labels) : "",
      lookup(ng, "node_taints", null) != null ? format(" --register-with-taints=%s", ng.node_taints) : "",
    )
    # bootstrap_extra_args     = "--kubelet-extra-args '--node-labels=${ng.node_labels}  --register-with-taints=${ng.node_taints}'"
    pre_bootstrap_user_data  = try(ng.pre_bootstrap_user_data, "")
    post_bootstrap_user_data = try(ng.post_bootstrap_user_data, "")
    cloudinit_pre_nodeadm    = try(ng.cloudinit_pre_nodeadm, [])
    cloudinit_post_nodeadm   = try(ng.cloudinit_post_nodeadm, [])


    ################################################################################
    # Launch Template
    ################################################################################
    create_launch_template          = true
    launch_template_id              = ""
    launch_template_name            = "EKSNode${var.cluster_name}LaunchTemplate-${try(ng.name, "default")}"
    launch_template_use_name_prefix = false
    # use Default version(Nodeグループが使用するLaunch Templateのバージョンを指定)
    launch_template_version = null
    # デフォルトで使用されるテンプレートのバージョンを指定(Default: null(Latest))
    launch_template_default_version = try(ng.launch_template_default_version, null)
    # 起動テンプレートが更新された際に新しいバージョンを自動的にデフォルトバージョンとして設定する(Default: true)
    update_launch_template_default_version = try(ng.update_launch_template_default_version, true)
    launch_template_description            = "Launch template for EKS node group ${var.cluster_name} ${try(ng.name, "default")}"
    launch_template_tags                   = {}
    # この起動テンプレートで作成される以下のリソースにタグを付ける
    tag_specifications = ["instance", "volume", "network-interface"]
    # ami_typeの指定により, 自動で決定されるため指定不要
    ami_id                             = null
    instance_type                      = try(ng.instance_type, "m3.medium")
    block_device_mappings              = try(ng.block_device_mappings, {})
    capacity_reservation_specification = try(ng.capacity_reservation_specification, {})
    cpu_options                        = try(ng.cpu_options, {})
    credit_specification               = try(ng.credit_specification, {})
    elastic_gpu_specifications         = try(ng.elastic_gpu_specifications, [])
    elastic_inference_accelerator      = try(ng.elastic_inference_accelerator, {})
    enclave_options                    = try(ng.enclave_options, {})
    # インスタンスを停止する際にメモリ(RAM)の内容をEBSルートボリュームに保存し、後で再開するときにその状態を復元して起動する機能
    # k8sがオーケストレーションするので不要
    hibernation_options = {}
    # instance_typeの指定により, 自動で決定されるため指定不要
    instance_requirements   = {}
    instance_market_options = try(ng.instance_market_options, {})
    license_specifications  = try(ng.license_specifications, {})
    metadata_options = try(ng.metadata_options, {
      http_endpoint               = "enabled"
      http_tokens                 = "required"
      http_put_response_hop_limit = 2
    })
    monitoring         = false
    enable_efa_support = try(ng.enable_efa_support, false)
    # EKSを利用するため, ほとんどの場合は不要のため
    network_interfaces       = []
    placement                = {}
    maintenance_options      = {}
    private_dns_name_options = {}

    ################################################################################
    # IAM Role
    ################################################################################
    # 1, IAMロールの作成
    # 2. EC2がこのロールをassume可能になるようポリシーを付与
    # 3. AmazonEKS_CNI_Policy, AmazonEKSWorkerNodePolicy, AmazonEC2ContainerRegistryReadOnlyのポリシーを付与
    # 4. iam_role_additional_policiesで指定したポリシーを付与
    # 5. iam_role_policy_statementsで指定したポリシーインラインポリシーとして付与
    create_iam_instance_profile = true
    iam_role_name               = "EKSNode${var.cluster_name}Role-${try(ng.name, "default")}"
    iam_role_use_name_prefix    = false
    iam_role_description        = "IAM role for EKS node group ${var.cluster_name} ${try(ng.name, "default")}"
    iam_role_path               = local.iam_role_path
    iam_role_tags = merge(
      tomap({
        "Name" = "EKSNode${var.cluster_name}Role-${try(ng.name, "default")}"
      })
    )
    iam_role_attach_cni_policy = true
    iam_role_additional_policies = try(ng.iam_role_additional_policies, {
      auto_scaler_policy = "arn:aws:iam::aws:policy/AutoScalingFullAccess"
    })
    create_iam_role_policy     = true
    iam_role_policy_statements = try(ng.iam_role_policy_statements, [])

    ################################################################################
    # Access Entry
    ################################################################################
    # 作成したroleもしくは指定したroleに対して、EKSクラスタへのEC2_LINUX or EC2_WINDOWSタイプのアクセスエントリを付与
    create_access_entry = true
    iam_role_arn        = ""

    create_schedule = try(ng.create_schedule, true)
    schedules       = try(ng.schedules, {})

    tags = {
      "unmanaged-node"                    = "true"
      "k8s.io/cluster-autoscaler/enabled" = try(ng.create_autoscaling_group ? "true" : "false", "true")
      "InstanceName"                      = format("%s%s", local.node_instance_name_prefix, try(ng.name, "default"))
    }
  } }
}

############################################
## IAM Role
############################################
data "aws_iam_role" "admin" {
  count = var.create_admin_access_entry ? 1 : 0

  name = var.cluster_admin_role
}
