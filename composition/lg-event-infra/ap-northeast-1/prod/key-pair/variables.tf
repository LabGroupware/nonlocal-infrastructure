############################################
## General variables ##
############################################
variable "env" {
  description = "The name of the environment."
  type        = string
}

variable "region" {
  type = string
}

variable "application_name" {
  description = "The name of the application."
  type        = string
}

############################################
## Key Pair Needs ##
############################################
variable "need_bastion_key" {
  description = "Whether to create a bastion host or not"
  type        = bool
}

variable "need_eks_node_key" {
  description = "Whether to create a key pair for EKS nodes or not"
  type        = bool
}
