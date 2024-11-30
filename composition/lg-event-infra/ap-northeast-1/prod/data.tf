locals {
  tags = {
    Environment = var.env
    Application = var.app_name
    Terraform   = true
  }

  ########################################
  # VPC
  ########################################
  vpc_name = "vpc-${var.region_tag[var.region]}-${var.env}-${var.app_name}"
  vpc_tags = merge(
    local.tags,
    tomap({
      "VPC-Name" = local.vpc_name
    })
  )

  # add three ingress rules from EKS worker SG to DB SG only when creating EKS cluster
  databse_computed_ingress_with_eks_worker_source_security_group_ids = var.create_eks ? [
    # {
    #   rule                     = "mongodb-27017-tcp"
    #   source_security_group_id = module.eks.node_security_group_id
    #   description              = "mongodb-27017 from EKS SG in private subnet"
    # },
    # {
    #   rule                     = "mongodb-27018-tcp"
    #   source_security_group_id = module.eks.node_security_group_id
    #   description              = "mongodb-27018 from EKS SG in private subnet"

    # },
    # {
    #   rule                     = "mongodb-27019-tcp"
    #   source_security_group_id = module.eks.node_security_group_id
    #   description              = "mongodb-27019 from EKS SG in private subnet"
    # }
  ] : []

  ########################################
  # Bastion
  ########################################
  bastion_instance_name = "bastion-host-${var.region_tag[var.region]}-${var.env}-${var.app_name}"
  bastion_tags = merge(
    local.tags,
    tomap({
      "Instance-Name" = local.bastion_instance_name
    })
  )
  bastion_eip_tags = merge(
    local.tags,
    tomap({
      "Instance-Name" = local.bastion_instance_name
    })
  )

  ########################################
  # Cognito
  ########################################
  admin_pool_name = "admin-${var.region_tag[var.region]}-${var.env}-${var.app_name}"
  cognito_tags = merge(
    local.tags,
    tomap({
      "Pool-Name" = local.admin_pool_name
    })
  )

  ########################################
  # EKS
  ########################################

  eks_tags = {
    Environment = var.env
    Application = var.app_name
  }
}

data "external" "hostname" {
  program = ["bash", "-c", <<EOT
    hostname=$(hostname)
    echo "{\"hostname\": \"$hostname\"}"
  EOT
  ]
}

data "aws_key_pair" "bastion_key_pair" {
  filter {
    name   = "tag:Application"
    values = [var.app_name]
  }

  filter {
    name   = "tag:Environment"
    values = [var.env]
  }

  filter {
    name   = "tag:Hostname"
    values = [data.external.hostname.result["hostname"]]
  }

  filter {
    name   = "tag:Keyname"
    values = ["bastion"]
  }
}

data "aws_key_pair" "eks_node_key_pair" {
  filter {
    name   = "tag:Application"
    values = [var.app_name]
  }

  filter {
    name   = "tag:Environment"
    values = [var.env]
  }

  filter {
    name   = "tag:Hostname"
    values = [data.external.hostname.result["hostname"]]
  }

  filter {
    name   = "tag:Keyname"
    values = ["eks-node"]
  }
}
