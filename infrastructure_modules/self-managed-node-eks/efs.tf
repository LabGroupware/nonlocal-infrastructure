## EFS CSI Role and Policy
module "efs_csi_iam_role" {
  source = "../../resource_modules/identity/iam/modules/iam-role-for-service-accounts-eks"

  create_role = var.create_eks && var.enable_efs_csi

  role_name             = format("%s-efs-csi", var.cluster_name)
  role_description      = "IAM role for EFS CSI Driver"
  role_path             = local.iam_role_path
  attach_efs_csi_policy = true
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:efs-csi-controller-sa"]
    }
  }
}

resource "aws_eks_addon" "efs_eks_addon" {
  count      = var.enable_efs_csi ? 1 : 0
  depends_on = [module.efs_csi_iam_role]

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  cluster_name             = var.cluster_name
  addon_name               = "aws-efs-csi-driver"
  service_account_role_arn = module.efs_csi_iam_role.iam_role_arn
}

##########################################################################################
# File System
##########################################################################################
# 1. EFS 標準アクセス向けファイルシステム
resource "aws_efs_file_system" "efs_standard" {
  creation_token = "efs-standard"
  encrypted      = true
  lifecycle_policy {
    transition_to_ia = "AFTER_60_DAYS"
  }
}

# 2. EFS 低頻度アクセス向けファイルシステム
resource "aws_efs_file_system" "efs_infrequent_access" {
  creation_token = "efs-infrequent-access"
  encrypted      = true
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }
}

# 3. 開発用（低コスト）EFS
resource "aws_efs_file_system" "efs_dev" {
  creation_token = "efs-dev"
  encrypted      = true
}

# 4. 共有データアクセス向け（TLS対応）EFS
resource "aws_efs_file_system" "efs_secure" {
  creation_token = "efs-secure"
  encrypted      = true
}

##########################################################################################
# Security Group
##########################################################################################
resource "aws_security_group" "efs" {
  name        = local.efs_security_group_name
  description = local.efs_security_group_description
  vpc_id      = var.vpc_id
  ingress {
    from_port = 2049
    to_port   = 2049
    protocol  = "tcp"
    security_groups = [
      module.eks.node_security_group_id,
      # module.eks.cluster_security_group_id # クラスタからもアクセスを許可する場合はコメントアウトを外す
    ]
  }

  # 外部に対してのアクセスを許可する場合は以下のコメントアウトを外す
  # egress {
  #   from_port   = 0
  #   to_port     = 0
  #   protocol    = "-1"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }
}

##########################################################################################
# Mount Targets
##########################################################################################
resource "aws_efs_mount_target" "efs_standard_mount" {
  file_system_id = aws_efs_file_system.efs_standard.id

  for_each        = toset(var.subnets)
  subnet_id       = each.value
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_mount_target" "efs_infrequent_access_mount" {
  file_system_id = aws_efs_file_system.efs_infrequent_access.id

  for_each        = toset(var.subnets)
  subnet_id       = each.value
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_mount_target" "efs_dev_mount" {
  file_system_id = aws_efs_file_system.efs_dev.id

  for_each        = toset(var.subnets)
  subnet_id       = each.value
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_mount_target" "efs_secure_mount" {
  file_system_id = aws_efs_file_system.efs_secure.id

  for_each        = toset(var.subnets)
  subnet_id       = each.value
  security_groups = [aws_security_group.efs.id]
}

##########################################################################################
# Storage Class
##########################################################################################
resource "kubernetes_storage_class_v1" "efs_standard" {
  metadata {
    name = "efs-standard"
  }

  storage_provisioner = "efs.csi.aws.com"

  parameters = {
    provisioningMode = "efs-ap"
    fileSystemId     = aws_efs_file_system.efs_standard.id
    directoryPerms   = "777"
    gidRangeStart    = "1000"
    gidRangeEnd      = "2000"
    gidAllocate      = "true"
  }

  allow_volume_expansion = true
  volume_binding_mode    = "Immediate"
  reclaim_policy         = "Retain"
}

resource "kubernetes_storage_class_v1" "efs_infrequent_access" {
  metadata {
    name = "efs-infrequent-access"
  }

  storage_provisioner = "efs.csi.aws.com"

  parameters = {
    provisioningMode = "efs-ap"
    fileSystemId     = aws_efs_file_system.efs_infrequent_access.id
    directoryPerms   = "777"
    gidRangeStart    = "1000"
    gidRangeEnd      = "2000"
    gidAllocate      = "true"
  }

  allow_volume_expansion = true
  volume_binding_mode    = "Immediate"
  reclaim_policy         = "Retain"
}
resource "kubernetes_storage_class_v1" "efs_dev" {
  metadata {
    name = "efs-dev"
  }

  storage_provisioner = "efs.csi.aws.com"

  parameters = {
    provisioningMode = "efs-ap"
    fileSystemId     = aws_efs_file_system.efs_dev.id
    directoryPerms   = "777"
    gidRangeStart    = "1000"
    gidRangeEnd      = "2000"
    gidAllocate      = "true"
  }

  allow_volume_expansion = true
  volume_binding_mode    = "Immediate"
  reclaim_policy         = "Delete"
}

resource "kubernetes_storage_class_v1" "efs_secure" {
  metadata {
    name = "efs-secure"
  }

  storage_provisioner = "efs.csi.aws.com"

  parameters = {
    provisioningMode = "efs-ap"
    fileSystemId     = aws_efs_file_system.efs_secure.id
    directoryPerms   = "777"
    gidRangeStart    = "1000"
    gidRangeEnd      = "2000"
    gidAllocate      = "true"
  }

  allow_volume_expansion = true
  volume_binding_mode    = "Immediate"
  reclaim_policy         = "Retain"
  mount_options          = ["tls"]
}
