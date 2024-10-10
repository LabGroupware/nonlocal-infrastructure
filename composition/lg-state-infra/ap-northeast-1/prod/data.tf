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
  # EKS
  ########################################
  ## EKS ##
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets
  cluster_name    = "eks-${var.region_tag[var.region]}-${var.env}-${var.app_name}"

  eks_tags = {
    Environment = var.env
    Application = var.app_name
  }

  # specify AWS Profile if you want kubectl to use a named profile to authenticate instead of access key and secret access key
  kubeconfig_aws_authenticator_env_variables = var.authenticate_using_aws_profile == true ? {
    AWS_PROFILE = var.profile_name
  } : {}

  aws_auth_roles = var.authenticate_using_role == true ? concat(var.aws_auth_roles, [
    {
      rolearn  = "arn:aws:iam::${data.aws_caller_identity.this.account_id}:role/${var.role_name}"
      username = "k8s_terraform_builder"
      groups   = ["system:masters"]
    },
    {
      rolearn  = "arn:aws:iam::${data.aws_caller_identity.this.account_id}:role/Developer"
      username = "k8s-developer"
      groups   = ["k8s-developer"]
    },
    {
      rolearn  = "arn:aws:iam::${data.aws_caller_identity.this.account_id}:role/FullAdmin"
      username = "k8s_admin"
      groups   = ["system:masters"]
    },
  ]) : var.aws_auth_roles
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
