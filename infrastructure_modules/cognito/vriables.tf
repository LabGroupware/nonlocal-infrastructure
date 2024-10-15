########################################
# Cognito
########################################
variable "has_root_domain_a_record" {
  type        = bool
  description = "Whether the root domain has an A record"
}

variable "sms_external_id" {
  type        = string
  description = "The external ID for the SMS role"
}

variable "admin_pool_name" {
  type        = string
  description = "The name of the admin cognito user pool"
}

variable "tags" {
  type = map(string)
}

variable "ses_domain" {
  type        = string
  description = "The domain verified in SES"
}

variable "cognito_from_address" {
  type        = string
  description = "The email address to use as the 'from' address in Cognito"
}

variable "route53_zone_domain_name" {
  type        = string
  description = "The domain name to use for the Route53 zone"
}

variable "auth_domain" {
  type        = string
  description = "The domain name to use for the Cognito user pool"
}

variable "admin_domain" {
  type        = string
  description = "The domain name for the admin"
}

variable "aws_route53_record_ttl" {
  type        = number
  description = "The TTL to use for the Route53 record"
}

variable "default_admin" {
  type = object({
    username      = string
    email         = string
    temp_password = string
  })
  description = "The default admin user"
}
