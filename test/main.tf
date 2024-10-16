resource "aws_cognito_user_pool" "admin_pool" {
  name = "admin-pool"
}

output "cognito_user_pool_endpoint" {
  value = aws_cognito_user_pool.admin_pool.endpoint
}
