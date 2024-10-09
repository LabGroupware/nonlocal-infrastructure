output "private_key_file_names" {
  value = {
    for key, value in local_file.private_keys : key => value.filename
  }
}

output "public_key_file_names" {
  value = {
    for key, value in local_file.public_keys : key => value.filename
  }
}

output "local_hostname" {
  value = data.external.hostname.result["hostname"]
}

output "key_pair_ids" {
  value = {
    for key, value in module.key_pair : key => value.key_pair_id
  }
}

output "key_pair_arns" {
  value = {
    for key, value in module.key_pair : key => value.key_pair_arn
  }
}

output "key_tags" {
  value = local.key_tags
}
