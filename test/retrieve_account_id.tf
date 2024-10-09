provider "aws" {
  alias = "id-retriever"

  region  = "ap-northeast-1"
  profile = "terraform"
}

# Retrieve the current account ID
data "aws_caller_identity" "current" {
  provider = aws.id-retriever
}

provider "aws" {
  region = "ap-northeast-1"
  # profile = var.profile_name

  assume_role {
    role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/terraform-builder"
  }
}
