locals {
  cluster_autoscaler_repository = "https://kubernetes.github.io/autoscaler"
}

# IAM Policy for Cluster Autoscaler
module "cluster_autoscaler_iam_role" {
  source = "../../resource_modules/identity/iam/modules/iam-role-for-service-accounts-eks"

  create_role = var.create_eks

  role_name                        = format("%s-autoscaler", var.cluster_name)
  role_description                 = "IAM Role for Cluster Autoscaler"
  role_path                        = local.iam_role_path
  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_cluster_names = [var.cluster_name]
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cluster-autoscaler"]
    }
  }
}

locals {
  autoscaling_groups = flatten([
    for idx in range(length(keys(module.eks.self_managed_node_groups))) : [
      {
        name  = "autoscalingGroups[${idx}].name"
        value = values(module.eks.self_managed_node_groups)[idx].autoscaling_group_name
      },
      {
        name  = "autoscalingGroups[${idx}].maxSize"
        value = values(module.eks.self_managed_node_groups)[idx].autoscaling_group_max_size
      },
      {
        name  = "autoscalingGroups[${idx}].minSize"
        value = values(module.eks.self_managed_node_groups)[idx].autoscaling_group_min_size
      }
    ]
  ])
}

# Cluster Autoscaler
resource "helm_release" "cluster_autoscaler_release" {
  depends_on = [module.cluster_autoscaler_iam_role, module.eks]
  name       = "cluster-autoscaler"

  repository = local.cluster_autoscaler_repository
  chart      = "cluster-autoscaler"

  namespace = "kube-system"

  set {
    name  = "cloudProvider"
    value = "aws"
  }

  dynamic "set" {
    for_each = local.autoscaling_groups
    content {
      name  = set.value.name
      value = set.value.value
    }
  }

  set {
    name  = "awsRegion"
    value = var.region
  }

  set {
    name  = "rbac.serviceAccount.create"
    value = "true"
  }

  set {
    name  = "rbac.serviceAccount.name"
    value = "cluster-autoscaler"
  }

  set {
    name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.cluster_autoscaler_iam_role.iam_role_arn
  }
  # Additional Arguments (Optional) - To Test How to pass Extra Args for Cluster Autoscaler
  # set {
  #   name  = "extraArgs.scan-interval"
  #   value = "20s"
  # }
}


