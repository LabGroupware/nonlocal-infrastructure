output "cognito_user_pool_id" {
  value       = aws_cognito_user_pool.admin_pool.id
  description = "The ID of the Cognito user pool"
}

output "issuer_url" {
  value       = aws_cognito_user_pool.admin_pool.endpoint
  description = "Cognito User Pool Endpoint"
}
