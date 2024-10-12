# Default provider
provider "aws" {
  alias = "id-retriever"

  region  = var.region
  profile = var.profile_name
}

# Retrieve the current account ID
data "aws_caller_identity" "this" {
  provider = aws.id-retriever
}
provider "aws" {
  region = var.region
  # profile = var.profile_name

  assume_role {
    role_arn = "arn:aws:iam::${data.aws_caller_identity.this.account_id}:role/${var.cluster_admin_role}"
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}
