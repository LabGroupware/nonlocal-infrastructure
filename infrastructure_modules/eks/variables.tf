## Metatada ##
variable "region" {}

variable "env" {}

variable "app_name" {}

variable "tags" {
  type = map(string)
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

variable "environment_tag" {
  type = map(any)

  default = {
    "prod"    = "prod"
    "qa"      = "qa"
    "staging" = "staging"
    "dev"     = "dev"
  }
}


## EKS ##
variable "create_eks" {}
variable "cluster_version" {
  description = "Kubernetes version to use for the EKS cluster."
  type        = string
}
variable "cluster_name" {}
variable "cluster_enabled_log_types" {
  description = "A list of the desired control plane logs to enable. For more information, see Amazon EKS Control Plane Logging documentation (https://docs.aws.amazon.com/eks/latest/userguide/control-plane-logs.html)"
  type        = list(string)
  default     = ["audit", "api", "authenticator"]
}
variable "subnets" {
  type = list(string)
}
variable "cluster_endpoint_public_access_cidrs" {
  type        = list(string)
  description = "Value of the CIDR block that can access the public endpoint of the EKS cluster"
  default     = ["0.0.0.0/0"]
}
variable "cluster_service_ipv4_cidr" {
  description = "CIDR block for the Kubernetes service IPs"
  type        = string
  default     = "172.20.0.0/16"
}
variable "cloudwatch_log_group_retention_in_days" {
  description = "Number of days to retain log events. If cluster_enabled_log_types is empty, this will be ignored."
  type        = number
  # default     = 90
}
variable "vpc_id" {}

## Key Pair ##
variable "node_instance_keypair" {
  description = "Kay pair to use for the EKS nodes"
  type        = string
}

## Self Managed Node Group ##
variable "node_groups" {
  description = "Map of self-managed node group definitions to create"
  type = list(object({
    create_autoscaling_group = bool
    name                     = string
    ami_type                 = string
    instance_type            = string
    desired_size             = number
    min_size                 = number
    max_size                 = number
    schedules = map(object({
      min_size     = number
      max_size     = number
      desired_size = number
      start_time   = string
      end_time     = string
      time_zone    = string
      recurrence   = string
    }))
    # volume_size       = number
    # volume_type       = string
    # volume_encrypted  = bool
    # volume_kms_key_id = string
    # tags              = map(string)
  }))
}
