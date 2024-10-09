# AWS EC2 Instance Terraform Outputs
# Public EC2 Instances - Bastion Host

## bastion_instance_public_instance_id
output "bastion_instance_public_instance_id" {
  description = "Public EC2 Instance ID"
  value       = module.bastion_ec2.id
}

## bastion_instance_public_ip
output "bastion_instance_eip" {
  description = "Elastic IP associated to the Bastion Host"
  value       = aws_eip.bastion_eip.public_ip
}
