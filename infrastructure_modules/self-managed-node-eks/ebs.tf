## EBS CSI Role and Policy
module "ebs_csi_iam_role" {
  source = "../../resource_modules/identity/iam/modules/iam-role-for-service-accounts-eks"

  create_role = var.create_eks && var.enable_ebs_csi

  role_name             = format("%s-ebs-csi", var.cluster_name)
  role_description      = "IAM role for EBS CSI Driver"
  role_path             = local.iam_role_path
  attach_ebs_csi_policy = true
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

##########################################################################################
# Using Addon
##########################################################################################
resource "aws_eks_addon" "ebs_eks_addon" {
  count                    = var.enable_ebs_csi ? 1 : 0
  depends_on               = [module.ebs_csi_iam_role]
  cluster_name             = var.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = module.ebs_csi_iam_role.iam_role_arn
}

##########################################################################################
# Storage Class
##########################################################################################
resource "kubernetes_storage_class_v1" "block_general" {
  metadata {
    name = "block-general"
  }

  storage_provisioner = "ebs.csi.aws.com"

  parameters = {
    type      = "gp3"
    fsType    = "ext4"
    encrypted = "true"
  }

  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer"
  reclaim_policy         = "Delete"

  depends_on = [
    module.eks,
  ]
}

resource "kubernetes_storage_class_v1" "block_performance" {
  metadata {
    name = "block-performance"
  }

  storage_provisioner = "ebs.csi.aws.com"

  parameters = {
    type      = "io1"
    iopsPerGB = "50"
    fsType    = "xfs"
    encrypted = "true"
  }

  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer"
  reclaim_policy         = "Retain"

  depends_on = [
    module.eks,
  ]
}

resource "kubernetes_storage_class_v1" "block_backup" {
  metadata {
    name = "block-backup"
  }

  storage_provisioner = "ebs.csi.aws.com"

  parameters = {
    type      = "st1"
    fsType    = "ext4"
    encrypted = "true"
  }

  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer"
  reclaim_policy         = "Delete"

  depends_on = [
    module.eks,
  ]
}

resource "kubernetes_storage_class_v1" "block_devtest" {
  metadata {
    name = "block-devtest"
  }

  storage_provisioner = "ebs.csi.aws.com"

  parameters = {
    type      = "gp2"
    fsType    = "ext4"
    encrypted = "false"
  }

  allow_volume_expansion = true
  volume_binding_mode    = "Immediate"
  reclaim_policy         = "Delete"

  depends_on = [
    module.eks,
  ]
}
