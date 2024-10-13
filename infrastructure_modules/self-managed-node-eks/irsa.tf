############################################
# IAM Role for IRSA
############################################
module "iam_eks_role" {
  source = "../../resource_modules/identity/iam/modules/iam-role-for-service-accounts-eks"

  create_role = var.create_eks

  for_each = var.additional_irsa_roles

  role_name        = each.value.role_name
  role_description = "IAM role for IRSA for ${each.value.role_name}"
  role_path        = local.iam_role_path
  role_policy_arns = each.value.role_policy_arns
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = [for v in each.value.cluster_service_accounts : "${v.namespace}:${v.service_account}"]
    }
  }
}

############################################
# Kubernetes Service Account for IRSA
############################################
resource "kubernetes_service_account_v1" "irsa_sa" {
  depends_on = [module.iam_eks_role]

  for_each = {
    for role_key, role in var.additional_irsa_roles : "${role_key}" => {
      for each_key, sa in role.cluster_service_accounts : "${role_key}-${sa.namespace}-${sa.service_account}" => {
        role_key                = role_key
        namespace               = sa.namespace
        service_account         = sa.service_account
        labels                  = sa.labels
        image_pull_secret_names = try(sa.image_pull_secret_names, [])
      }
    }
  }

  metadata {
    name      = each.value.service_account
    namespace = each.value.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = module.iam_eks_role[each.value.role_key].iam_role_arn
    }
    labels = each.value.labels
  }
  dynamic "image_pull_secret" {
    for_each = each.value.image_pull_secret_names
    content {
      name = image_pull_secret.value
    }
  }
}
