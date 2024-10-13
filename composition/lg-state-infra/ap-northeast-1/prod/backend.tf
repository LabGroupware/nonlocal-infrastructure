terraform {
  backend "s3" {
    bucket         = "s3-apne1-lg-state-prod-terraform-backend-5d1790bc"
    region         = "ap-northeast-1"
    profile        = "terraform"
    key            = "lg-state-infra/ap-northeast-1/prod/terraform.tfstate"
    dynamodb_table = "dynamo-apne1-lg-state-prod-terraform-state-lock"
    encrypt        = true
  }
}
