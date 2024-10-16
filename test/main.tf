data "aws_ssoadmin_application_providers" "example" {}

locals {
  test = data.aws_ssoadmin_application_providers.example.id
}

output "aws_ssoadmin_application_providers" {
  value = [
    for provider in data.aws_ssoadmin_application_providers.example.application_providers : provider.application_provider_arn
  ]
}
