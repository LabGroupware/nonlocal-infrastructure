variable "profile_name" {
  description = "The AWS profile to use"
  type        = string
}

variable "cluster_admin_role" {
  description = "The name of the IAM role to create for the cluster admin"
  type        = string
}
