# TODO: Setup Managed Prometheus and Grafana
########################################
## EKS
########################################
module "eks" {
  source = "./resource_modules/container/eks"

  create = var.create_eks
  # 作成される全リソースに付与されるタグ
  tags = var.tags

  ################################################################################
  # Cluster
  ################################################################################
  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  # ["audit", "api", "authenticator", "controllerManager", "scheduler"]から選択
  # https://docs.aws.amazon.com/eks/latest/userguide/control-plane-logs.htmlを参考にして調整
  cluster_enabled_log_types = var.cluster_enabled_log_types
  # アクセスエントリを使用するためのAPI
  # aws-auth ConfigMapによる認証のためのCONFIG_MAP
  authentication_mode = "API_AND_CONFIG_MAP"

  # コントロールプレーンのセキュリティグループに追加するセキュリティグループの ID のリスト(外部で作成したセキュリティグループを追加する場合に使用)
  # コントロールプレーンに関わる設定のため, 通常は指定しない
  # cluster_additional_security_group_ids = []

  # コントロールプレーンのサブネット ID のリスト, 指定しない場合は、subnet_ids に指定されたサブネットにコントロールプレーンも配置される
  # 通常は指定しないが, NodeGroup と異なるサブネットに配置する場合に指定する
  # control_plane_subnet_ids = []

  # NodeGroupが配置されるサブネット ID のリスト, control_plane_subnet_ids を指定しない場合, コントロールプレーンもここに配置される
  # 通常はprivateサブネットを指定する
  subnet_ids = var.subnets

  # 通常外部からIAM認証を使用して実行するので, VPC内からはkebectlなど実行する必要もないため
  cluster_endpoint_private_access = false
  # クラスタのAPIエンドポイントに対しては, リモートでアクセス(kubectl)をしたいため
  cluster_endpoint_public_access = true
  # 可能であれば, hostのCIDRを限定する
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  cluster_ip_family = "ipv4"
  # クラスタ内のサービスのIPアドレス範囲
  cluster_service_ipv4_cidr = var.cluster_service_ipv4_cidr

  # External encryption key
  # 変更した際は, 既存のクラスタを削除して再作成する必要がある
  create_kms_key = false
  cluster_encryption_config = {
    resources        = ["secrets"]
    provider_key_arn = module.cluster_encryption_kms.key_arn
  }

  # iam roleを作成する場合(create_iam_role=true)でかつ, enable_cluster_encryption_config=trueの場合
  # この設定をtrueにすると, 作成したiam roleに対して, KMS関連のポリシーがアタッチされる
  attach_cluster_encryption_policy = true

  # クラスタのみに付与するタグ
  # cluster_tags = {}

  # EKSがクラスターのコントロールプレーンやノードの通信を保護するために自動で作成.
  # その後, タグを付与するが, 通常はデフォルトのtrueで問題ない
  create_cluster_primary_security_group_tags = true

  # クラスターの作成、更新、削除にかかるタイムアウトの設定を定義
  # 通常はデフォルトのまま(タイムアウトなし)で問題ない
  # cluster_timeouts = {}

  # クラスター作成後に自己管理のアドオンを自動的にブートストラップするかどうか.
  # aws-cni, kube-proxy, CoreDNSなどが含まれる
  # デフォルトはtrue(null)になっている
  # bootstrap_self_managed_addons = null

  ########################################
  ## Access Entries
  ########################################
  # aws-auth ConfigMapが非推奨になったため, access_entriesを使用する
  access_entries = local.access_entries

  # 作成したTerraformユーザーに対して, クラスタの管理権限を付与するかどうか
  # 作成ユーザーによる変更を行いたくないため, falseに設定する
  enable_cluster_creator_admin_permissions = false

  ########################################
  ## CloudWatch Logging
  ########################################
  # loggingが有効な場合, CloudWatch LogGroupを設定する
  # しなければ, 自動で作成される
  create_cloudwatch_log_group            = local.create_cloudwatch_log_group
  cloudwatch_log_group_retention_in_days = var.cloudwatch_log_group_retention_in_days
  cloudwatch_log_group_kms_key_id        = local.create_cloudwatch_log_group ? module.cluster_logging_kms.key_arn : null
  cloudwatch_log_group_class             = "STANDARD"
  cloudwatch_log_group_tags              = {}

  ########################################
  ## Security Group
  ########################################
  create_cluster_security_group = true
  # module内で作成するため
  cluster_security_group_id              = ""
  vpc_id                                 = var.vpc_id
  cluster_security_group_name            = local.cluster_security_group_name
  cluster_security_group_use_name_prefix = false
  cluster_security_group_description     = local.cluster_security_group_description
  cluster_security_group_tags            = {}
  # Node Security Groupへのアクセスを許可するための追加ルール
  # デフォルトで443のNodeからのingressが許可されている
  cluster_security_group_additional_rules = {
    # egress_nodes_ephemeral_ports_tcp = {
    #   description                = "Cluster API to K8S services running on nodes"
    #   protocol                   = "tcp"
    #   from_port                  = 1025
    #   to_port                    = 65535
    #   type                       = "egress"
    #   source_node_security_group = true
    # }
  }

  ################################################################################
  ## EKS IPV6 CNI Policy
  ################################################################################
  create_cni_ipv6_iam_policy = false

  ################################################################################
  ## Node Security Group
  ################################################################################
  create_node_security_group = true
  # module内で作成するため
  node_security_group_id              = ""
  node_security_group_name            = local.node_security_group_name
  node_security_group_use_name_prefix = false
  node_security_group_description     = local.node_security_group_description
  # defaultでは以下のルールが設定される
  # 1. 443(tcp)のClusterからのingressが許可されている(Cluster API to node groups)
  # 2. 10250(tcp)のClusterからのingressが許可されている(Cluster API to node kubelets)
  # 3. 53(tcp, udp)のselfからのingressが許可されている(Node to node CoreDNS)
  node_security_group_additional_rules = {
    # ingress_self_all = {
    #   description = "Node to node all ports/protocols"
    #   protocol    = "-1"
    #   from_port   = 0
    #   to_port     = 0
    #   type        = "ingress"
    #   self        = true
    # },
  }
  # node_security_group_enable_recommended_rulesをtrueにすると, 以下のルールが追加される
  # 1. Node to node ingress on ephemeral ports(1025-65535)
  # 2. Cluster API to node 4443/tcp webhook(metrics-server)
  # 3. Cluster API to node 6443/tcp webhook(prometheus-adapter)
  # 4. Cluster API to node 8443/tcp webhook(Karpenter)
  # 5. Cluster API to node 9443/tcp webhook(ALB controller, NGINX)
  # 6. Allow all egress
  node_security_group_enable_recommended_rules = true
  node_security_group_tags                     = {}
  # 機械学習などのワークロードを実行する場合の最適化
  enable_efa_support = false

  ################################################################################
  ## IRSA
  ################################################################################
  enable_irsa                     = true
  include_oidc_root_ca_thumbprint = true

  ################################################################################
  ## Cluster IAM Role
  ################################################################################

  ################################################################################
  ## EKS Addons
  ################################################################################
  cluster_addons = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni                = {}
  }
  cluster_addons_timeouts = {}

  ################################################################################
  ## EKS Identity Provider
  ################################################################################
  # 外部の認証システム(OIDCやSAMLなど)で行いたいときに使用
  cluster_identity_providers = {}

  ################################################################################
  ## Self Managed Node Group
  ################################################################################
  # self_managed_node_groupsのほうが優先される
  # use KMS key to encrypt EKS worker node's root EBS volumes
  self_managed_node_group_defaults = {
    key_name                 = var.node_instance_keypair.key_name
    use_name_prefix          = false

    # iam_role_additional_policies = {}
  }
  self_managed_node_groups = local.node_groups
}

########################################
## KMS
########################################
module "cluster_encryption_kms" {
  source = "../../resource_modules/identity/kms"

  create = var.create_eks

  description             = local.k8s_secret_kms_key_description
  key_usage               = "ENCRYPT_DECRYPT"
  deletion_window_in_days = local.k8s_secret_kms_key_deletion_window_in_days
  enable_key_rotation     = true

  # Policy
  enable_default_policy = true
  key_owners            = []
  # add Cluster Admin?
  key_administrators = []
  # add Cluster role
  key_users         = ["cluster-role"]
  key_service_users = []
  # s3へのReadアクセスが必要な場合
  # policy = data.aws_iam_policy.s3_read_only_access_policy.json
  tags = local.k8s_secret_kms_key_tags
}

module "cluster_logging_kms" {
  source = "../../resource_modules/identity/kms"

  create = local.create_cloudwatch_log_group

  description             = local.eks_cloudwatch_kms_key_description
  key_usage               = "ENCRYPT_DECRYPT"
  deletion_window_in_days = local.eks_cloudwatch_kms_key_deletion_window_in_days
  enable_key_rotation     = true

  # Policy
  enable_default_policy = true
  policy                = data.aws_iam_policy_document.cloudwatch.json
  tags                  = local.eks_cloudwatch_kms_key_tags
}

# IRSA ##
# module "cluster_autoscaler_iam_assumable_role" {
#   source = "../../resource_modules/identity/iam/modules/iam-assumable-role-with-oidc"

#   create_role                   = var.create_eks ? true : false
#   role_name                     = local.cluster_autoscaler_iam_role_name
#   provider_url                  = replace(module.eks_cluster.cluster_oidc_issuer_url, "https://", "")
#   role_policy_arns              = [module.cluster_autoscaler_iam_policy.arn]
#   oidc_fully_qualified_subjects = ["system:serviceaccount:${var.cluster_autoscaler_service_account_namespace}:${var.cluster_autoscaler_service_account_name}"]
# }

# module "cluster_autoscaler_iam_policy" {
#   source = "../../resource_modules/identity/iam/modules/iam-policy"

#   create_policy = var.create_eks ? true : false
#   description   = local.cluster_autoscaler_iam_policy_description
#   name          = local.cluster_autoscaler_iam_policy_name
#   path          = local.cluster_autoscaler_iam_policy_path
#   policy        = data.aws_iam_policy_document.cluster_autoscaler.json
# }

## test_irsa_iam_assumable_role ##
# module "test_irsa_iam_assumable_role" {
#   source = "../../resource_modules/identity/iam/modules/iam-assumable-role-with-oidc"

#   create_role  = var.create_eks ? true : false
#   role_name    = local.test_irsa_iam_role_name
#   provider_url = replace(module.eks_cluster.cluster_oidc_issuer_url, "https://", "")
#   role_policy_arns = [
#     data.aws_iam_policy.s3_read_only_access_policy.arn # <------- reference AWS Managed IAM policy ARN
#   ]
#   oidc_fully_qualified_subjects = ["system:serviceaccount:${var.test_irsa_service_account_namespace}:${var.test_irsa_service_account_name}"]
# }

# Ref: https://docs.aws.amazon.com/efs/latest/ug/network-access.html
# module "efs_security_group" {
#   source = "../../resource_modules/compute/sg"

#   name        = local.efs_security_group_name
#   description = local.efs_security_group_description
#   vpc_id      = var.vpc_id

#   ingress_with_cidr_blocks                                 = local.efs_ingress_with_cidr_blocks
#   computed_ingress_with_cidr_blocks                        = local.efs_computed_ingress_with_cidr_blocks
#   number_of_computed_ingress_with_cidr_blocks              = local.efs_number_of_computed_ingress_with_cidr_blocks
#   computed_ingress_with_source_security_group_id           = local.efs_computed_ingress_with_source_security_group_id
#   number_of_computed_ingress_with_source_security_group_id = local.efs_computed_ingress_with_source_security_group_count

#   egress_rules = ["all-all"]

#   tags = local.efs_security_group_tags
# }

# module "efs" {
#   source = "../../resource_modules/storage/efs"

#   ## EFS FILE SYSTEM ##
#   encrypted = local.efs_encrypted
#   tags      = local.efs_tags

#   ## EFS MOUNT TARGET ##
#   # mount_target_subnet_ids = var.efs_mount_target_subnet_ids
#   # security_group_ids      = [module.efs_security_group.security_group_id]
# }

# Create IAM Role
# resource "aws_iam_role" "eks_master_role" {
#   name = "${local.name}-eks-master-role"

#   assume_role_policy = <<POLICY
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Effect": "Allow",
#       "Principal": {
#         "Service": "eks.amazonaws.com"
#       },
#       "Action": "sts:AssumeRole"
#     }
#   ]
# }
# POLICY
# }

# # Associate IAM Policy to IAM Role
# resource "aws_iam_role_policy_attachment" "eks-AmazonEKSClusterPolicy" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
#   role       = aws_iam_role.eks_master_role.name
# }

# resource "aws_iam_role_policy_attachment" "eks-AmazonEKSVPCResourceController" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
#   role       = aws_iam_role.eks_master_role.name
# }

# resource "aws_iam_role" "eks_master_role" {
#   name        = "${local.name}-eks-master-role"
#   path        = var.iam_role_path
#   description = var.iam_role_description

#   assume_role_policy    = data.aws_iam_policy_document.assume_role_policy[0].json
#   permissions_boundary  = var.iam_role_permissions_boundary
#   force_detach_policies = true

#   tags = merge(var.tags, var.iam_role_tags)
# }

# # Policies attached ref https://docs.aws.amazon.com/eks/latest/userguide/service_IAM_role.html
# resource "aws_iam_role_policy_attachment" "this" {
#   for_each = { for k, v in {
#     AmazonEKSClusterPolicy         = local.create_outposts_local_cluster ? "${local.iam_role_policy_prefix}/AmazonEKSLocalOutpostClusterPolicy" : "${local.iam_role_policy_prefix}/AmazonEKSClusterPolicy",
#     AmazonEKSVPCResourceController = "${local.iam_role_policy_prefix}/AmazonEKSVPCResourceController",
#   } : k => v if local.create_iam_role }

#   policy_arn = each.value
#   role       = aws_iam_role.this[0].name
# }

# resource "aws_iam_role_policy_attachment" "additional" {
#   for_each = { for k, v in var.iam_role_additional_policies : k => v if local.create_iam_role }

#   policy_arn = each.value
#   role       = aws_iam_role.this[0].name
# }

# # Using separate attachment due to `The "for_each" value depends on resource attributes that cannot be determined until apply`
# resource "aws_iam_role_policy_attachment" "cluster_encryption" {
#   policy_arn = aws_iam_policy.cluster_encryption[0].arn
#   role       = aws_iam_role.this[0].name
# }

# resource "aws_iam_policy" "cluster_encryption" {
#   name        = var.cluster_encryption_policy_use_name_prefix ? null : local.cluster_encryption_policy_name
#   name_prefix = var.cluster_encryption_policy_use_name_prefix ? local.cluster_encryption_policy_name : null
#   description = var.cluster_encryption_policy_description
#   path        = var.cluster_encryption_policy_path

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = [
#           "kms:Encrypt",
#           "kms:Decrypt",
#           "kms:ListGrants",
#           "kms:DescribeKey",
#         ]
#         Effect   = "Allow"
#         Resource = var.cluster_encryption_config.provider_key_arn
#       },
#     ]
#   })

#   tags = merge(var.tags, var.cluster_encryption_policy_tags)
# }
