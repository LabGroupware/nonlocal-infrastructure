# output "iam_role_arn" {
#   description = "The ARN of the IAM role"
#   value       = aws_iam_role.assumable_role.arn
# }

output "trusted_indentity_arn" {
  description = "The ARN of the trusted identity"
  value       = data.aws_caller_identity.current.arn
}
