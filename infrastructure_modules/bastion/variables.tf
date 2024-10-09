
# AWS EC2 Instance Terraform Variables
variable "instance_name" {
  description = "Bastion Host EC2 Instance Name"
  type        = string
}

# AWS EC2 Instance Type
variable "instance_type" {
  description = "EC2 Instance Type"
  type        = string
}

# AWS EC2 Instance Key Pair
variable "instance_keypair" {
  description = "AWS EC2 Key pair that need to be associated with EC2 Instance"
  type        = string
}

variable "instance_monitoring" {
  description = "Enable Monitoring for EC2 Instance"
  type        = bool
}

variable "bastion_subnet_id" {
  description = "Subnet ID to be associated with Bastion Host"
  type        = string
}

variable "bastion_sg_ids" {
  description = "List of Security Group IDs to be associated with Bastion Host"
  type        = list(string)
}

variable "bastion_tags" {
  description = "Tags to be associated with Bastion Host"
  type        = map(string)
}

variable "bastion_eip_tags" {
  description = "Tags to be associated with Bastion Host Elastic IP"
  type        = map(string)
}
