resource "random_bytes" "bytes" {
  length = 4

  keepers = {
    listener_arn = var.application_name
  }
}

resource "tls_private_key" "keygen" {
  for_each = toset(local.key_values)

  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_keys" {
  for_each = tls_private_key.keygen

  content  = each.value.private_key_pem
  filename = "${var.private_dir}/${each.key}.id_rsa" #private_key_file
  provisioner "local-exec" {
    command = "chmod 600 ${var.private_dir}/${each.key}.id_rsa"
  }
}

resource "local_file" "public_keys" {
  for_each = tls_private_key.keygen

  content  = each.value.public_key_openssh
  filename = "${var.private_dir}/${each.key}.id_rsa.pub" #public_key_file
  provisioner "local-exec" {
    command = "chmod 600 ${var.private_dir}/${each.key}.id_rsa.pub"
  }
}

module "key_pair" {
  source = "../../resource_modules/compute/key-pair"


  for_each = tls_private_key.keygen

  public_key = each.value.public_key_openssh
  key_name   = local.key_names[each.key]
  tags       = local.key_tags[each.key]
}

