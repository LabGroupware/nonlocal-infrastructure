# AWS EC2 Instance Terraform Module
# Bastion Host - EC2 Instance that will be created in VPC Public Subnet
module "bastion_ec2" {
  source = "../../resource_modules/compute/ec2"

  name                   = var.instance_name
  ami                    = data.aws_ami.amzlinux2.id
  instance_type          = var.instance_type
  key_name               = var.instance_keypair
  monitoring             = var.instance_monitoring
  subnet_id              = var.bastion_subnet_id
  vpc_security_group_ids = var.bastion_sg_ids
  tags                   = var.bastion_tags
}

# Create Elastic IP for Bastion Host
# Resource - depends_on Meta-Argument
resource "aws_eip" "bastion_eip" {
  instance = module.bastion_ec2.id
  domain   = "vpc"
  tags     = var.bastion_eip_tags
}
