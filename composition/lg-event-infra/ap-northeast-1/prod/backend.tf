terraform {
  backend "s3" {
    bucket         = "s3-apne1-lg-event-prod-terraform-backend-bc93829b"
    region         = "ap-northeast-1"
    key            = "lg-event-infra/ap-northeast-1/prod/terraform.tfstate"
    dynamodb_table = "dynamo-apne1-lg-event-prod-terraform-state-lock"
    encrypt        = true
  }
}
