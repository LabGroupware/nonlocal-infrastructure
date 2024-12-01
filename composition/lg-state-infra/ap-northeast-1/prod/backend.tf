terraform {
  backend "s3" {
    bucket         = "s3-apne1-lg-state-prod-terraform-backend-119eab4d"
    region         = "ap-northeast-1"
    key            = "lg-state-infra/ap-northeast-1/prod/terraform.tfstate"
    dynamodb_table = "dynamo-apne1-lg-state-prod-terraform-state-lock"
    encrypt        = true
  }
}
