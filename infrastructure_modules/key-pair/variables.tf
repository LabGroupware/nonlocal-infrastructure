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

variable "private_dir" {
  description = "The directory to store the private keys."
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
