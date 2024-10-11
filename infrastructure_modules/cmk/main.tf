########################################
## KMS
########################################
module "kms" {
  source = "../../resource_modules/identity/kms"

  description             = local.description
  key_usage               = var.key_usage
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = true
  enable_default_policy   = true
  key_owners              = var.key_owners
  key_administrators      = var.key_administrators
  key_users               = var.key_users
  key_service_users       = var.key_service_users
  policy                  = var.policy
  key_statements          = var.policy_statements
  tags                    = var.tags
}
