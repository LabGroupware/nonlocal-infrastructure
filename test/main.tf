terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14.0"
    }
  }
}

provider "aws" {
  profile = "terraform"

  assume_role {
    role_arn = "arn:aws:iam::522814736454:role/ClusterAdmin"
  }
}

resource "null_resource" "assume_role" {
  provisioner "local-exec" {
    command = <<EOT
      aws sts assume-role --role-arn "arn:aws:iam::522814736454:role/ClusterAdmin" \
      --role-session-name "TerraformSession" \
      --query 'Credentials' --output json > assume_role_output.json
    EOT
  }

  triggers = {
    always_run = "${timestamp()}"
  }
}

data "external" "assume_role_output" {
  program    = ["cat", "assume_role_output.json"]
  depends_on = [null_resource.assume_role]
}

resource "null_resource" "cleanup" {
  provisioner "local-exec" {
    command = "rm assume_role_output.json"
  }

  depends_on = [null_resource.assume_role]
}

# locals {
#   credentials = jsondecode(data.external.assume_role_output)
# }

output "aws_access_key_id" {
  value = data.external.assume_role_output.result["AccessKeyId"]
}
