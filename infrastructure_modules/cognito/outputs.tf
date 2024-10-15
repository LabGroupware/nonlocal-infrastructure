output "cognito_user_pool_id" {
  value       = aws_cognito_user_pool.admin_pool.id
  description = "The ID of the Cognito user pool"
}
