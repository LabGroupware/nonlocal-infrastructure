## Metatada ##
variable "region" {}

variable "profile_name" {}

variable "account_id" {}

variable "env" {}

variable "app_name" {}

variable "tags" {
  type = map(string)
}

variable "region_tag" {
  type = map(any)

  default = {
    "us-east-1"      = "use1"
    "us-west-1"      = "usw1"
    "eu-west-1"      = "euw1"
    "eu-central-1"   = "euc1"
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

## IAM ##
variable "cluster_iam_role_additional_policies" {
  description = "Additional IAM policies to attach to the EKS cluster role"
  type        = map(string)
}

## Access Entry ##
variable "create_admin_access_entry" {
  description = "Create an admin access entry in the security group"
  type        = bool
}

variable "cluster_admin_role" {
  description = "IAM role to attach to the EKS cluster to allow full access"
  type        = string
}

variable "additional_accesss_entries" {
  description = "Additional access entries to add to the security group"
  type = map(object({
    principal_arn     = string
    kubernetes_groups = list(string)
    policy_associations = map(object({
      policy_arn = string
      access_scope = object({
        type       = string
        namespaces = list(string)
      })
    }))
  }))
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
}
variable "vpc_id" {}
variable "vpc_cidr_block" {}

variable "bastion_sg_id" {
  type = string
}

variable "node_instance_default_keypair" {
  description = "The key pair to use for SSH access to the EC2 instances"
  type        = string
}

## Self Managed Node Group ##
variable "node_groups" {
  description = "Map of self-managed node group definitions to create"
  type        = any
}

########################################
##  IRSA
########################################
variable "additional_irsa_roles" {
  description = "Additional IAM roles to create for IRSA"
  type = map(object({
    role_name        = string
    role_policy_arns = map(string)
    cluster_service_accounts = map(object({
      namespace               = string
      service_account         = string
      lables                  = map(string)
      image_pull_secret_names = optional(list(string))
    }))
  }))
}

########################################
##  EBS CSI Driver
########################################
variable "enable_ebs_csi" {
  description = "Enable EBS CSI Driver"
  type        = bool
}

########################################
##  EFS CSI Driver
########################################
variable "enable_efs_csi" {
  description = "Enable EFS CSI Driver"
  type        = bool
}

########################################
## Helm
########################################
variable "helm_dir" {
  description = "The directory containing the Helm charts to install"
  type        = string
}

# --- Istio ---
##############################################
# ACM + Route53
##############################################
variable "route53_zone_domain_name" {
  type        = string
  description = "The domain name to use for the Route53 zone"
}
variable "acm_domain_name" {
  type        = string
  description = "The domain name to use for the ACM certificate"
}
variable "subject_alternative_names" {
  type        = list(string)
  description = "The subject alternative names to use for the ACM certificate"
}
variable "aws_route53_record_ttl" {
  type        = number
  description = "The TTL to use for the Route53 record"
  default     = 300
}

##############################################
# ELB
##############################################
variable "lb_ingress_internal" {
  type        = bool
  description = "Indicates whether the Network Load Balancer (ELB) for the EKS cluster should be internal, restricting access to within the AWS network."
  default     = false
}

variable "lb_security_group_id" {
  type        = string
  description = "The security group ID to use for the load balancer"
}

variable "lb_subnet_ids" {
  type        = list(string)
  description = "The subnet IDs to use for the load balancer(Public Subnets)"
}

variable "lb_client_keep_alive" {
  type        = number
  description = "The time in seconds that the connection is allowed to be idle before it is closed by the load balancer."
}

variable "lb_idle_timeout" {
  type        = number
  description = "The time in seconds that the connection is allowed to be idle before it is closed by the load balancer."
}

variable "proxy_protocol_v2" {
  type        = bool
  description = "Enables or disables Proxy Protocol v2 on the Network Load Balancer, used for preserving client IP addresses and other connection information."
  default     = false
}

variable "enable_vpc_link" {
  type        = bool
  description = "Create VPC Link associated to Network Load Balancing (For API Gateway to communicate with EKS)"
  default     = false
}

#########################
# Route53 Config
#########################
variable "public_root_domain_name" {
  type        = string
  description = "The public DNS zone name for the EKS cluster in AWS Route53. This zone is used for external DNS resolution for the cluster."
}

variable "cluster_private_zone" {
  type        = string
  description = "The private DNS zone name for the EKS cluster in AWS Route53. This zone is used for internal DNS resolution within the cluster."
  default     = "k8s.cluster"
}

##############################################
# Istio
##############################################

variable "istio_version" {
  type        = string
  description = "The version of Istio to install"
}

variable "istio_ingress_min_pods" {
  type        = number
  description = "The minimum number of pods for the Istio ingress gateway"
  default     = 1
}

variable "istio_ingress_max_pods" {
  type        = number
  description = "The maximum number of pods for the Istio ingress gateway"
  default     = 5
}

variable "kiail_version" {
  type        = string
  description = "The version of Kiali to install"
}

variable "kiali_virtual_service_host" {
  type        = string
  description = "The hostname for the Kiali virtual service, a part of Istio's service mesh visualization. It provides insights into the mesh topology and performance."
}

variable "auth_domain" {
  type        = string
  description = "The domain name to use for the Cognito user pool"
}

variable "admin_email" {
  type        = string
  description = "The email address of the admin user"
}

##############################################
# Prometheus + Grafana
##############################################
variable "enable_prometheus" {
  type        = bool
  description = "Enable managed Prometheus"
}
variable "prometheus_version" {
  type        = string
  description = "The version of Prometheus to install"
}
variable "prometheus_virtual_service_host" {
  type        = string
  description = "The hostname for the Prometheus virtual service, used in Istio routing. This host is used to access Prometheus for monitoring metrics."
}
variable "grafana_virtual_service_host" {
  type        = string
  description = "The hostname for the Grafana virtual service, used in Istio routing. This host is used to access Grafana dashboards for monitoring metrics."
}

variable "grafana_version" {
  type        = string
  description = "The version of Grafana to install"
}

variable "cognito_user_pool_id" {
  type        = string
  description = "The ID of the Cognito user pool"
}

variable "cognito_endpoint" {
  type        = string
  description = "Cognito User Pool Endpoint"
}

##############################################
# Jaeger
##############################################
variable "enable_jaeger" {
  type        = bool
  description = "Enable Jaeger for distributed tracing"
}

variable "jaeger_version" {
  type        = string
  description = "The version of Jaeger to install"
}

variable "jaeger_virtual_service_host" {
  type        = string
  description = "The hostname for the Jaeger virtual service, used in Istio routing. This host is used to access Jaeger for distributed tracing."
}

##############################################
# Node termination handler
##############################################
variable "enable_node_termination_handler" {
  type        = bool
  description = "Enable the node termination handler"
}

variable "node_termination_handler_version" {
  type        = string
  description = "The version of the node termination handler to install"
}
##############################################
# Descheduler
##############################################
variable "enable_descheduler" {
  type        = bool
  description = "Enable the descheduler"
}
##############################################
# Secret Store CSI Driver
##############################################

variable "secret_stores_csi_version" {
  type        = string
  description = "The version of the Secret Store CSI Driver to install"
}
