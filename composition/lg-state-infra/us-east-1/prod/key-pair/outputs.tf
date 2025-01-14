output "private_key_file_names" {
  value = module.keys.private_key_file_names
}

output "public_key_file_names" {
  value = module.keys.public_key_file_names
}

output "local_hostname" {
  value = module.keys.local_hostname
}

output "key_pair_ids" {
  value = module.keys.key_pair_ids
}

output "key_pair_arns" {
  value = module.keys.key_pair_arns
}

output "key_tags" {
  value = module.keys.key_tags
}
