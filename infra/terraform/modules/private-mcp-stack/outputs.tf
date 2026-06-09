output "alb_dns_name" {
  description = "ALB DNS name."
  value       = aws_lb.this.dns_name
}

output "mcp_endpoint_url" {
  description = "MCP endpoint URL."
  value       = var.enable_https ? "https://${var.domain_name}/mcp" : "http://${var.domain_name}/mcp"
}

output "ecr_repository_url" {
  description = "ECR repository URL."
  value       = aws_ecr_repository.this.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.this.name
}

output "ecs_service_name" {
  description = "ECS service name."
  value       = aws_ecs_service.this.name
}

output "private_subnet_ids" {
  description = "Created private subnet IDs."
  value       = values(aws_subnet.private)[*].id
}

output "quicksight_vpc_connection_id" {
  description = "Amazon QuickSight/Quick VPC connection ID."
  value       = var.create_quicksight_vpc_connection ? aws_quicksight_vpc_connection.this[0].vpc_connection_id : null
}

output "quicksight_vpc_connection_status" {
  description = "Amazon QuickSight/Quick VPC connection availability status."
  value       = var.create_quicksight_vpc_connection ? aws_quicksight_vpc_connection.this[0].availability_status : null
}

output "mock_s3_bucket" {
  description = "Mock S3 bucket name."
  value       = var.create_mock_data_sources ? aws_s3_bucket.mock_data[0].bucket : null
}

output "mock_rds_endpoint" {
  description = "Mock RDS PostgreSQL endpoint."
  value       = var.create_mock_data_sources ? aws_db_instance.mock[0].address : null
}

output "cognito_user_client_id" {
  description = "Cognito OAuth user client ID."
  value       = var.create_cognito_oauth ? aws_cognito_user_pool_client.mcp_user[0].id : null
}

output "cognito_user_client_secret" {
  description = "Cognito OAuth user client secret."
  value       = var.create_cognito_oauth ? aws_cognito_user_pool_client.mcp_user[0].client_secret : null
  sensitive   = true
}

output "cognito_service_client_id" {
  description = "Cognito OAuth service client ID."
  value       = var.create_cognito_oauth ? aws_cognito_user_pool_client.mcp_service[0].id : null
}

output "cognito_service_client_secret" {
  description = "Cognito OAuth service client secret."
  value       = var.create_cognito_oauth ? aws_cognito_user_pool_client.mcp_service[0].client_secret : null
  sensitive   = true
}

output "cognito_authorization_url" {
  description = "Cognito OAuth authorization URL."
  value       = var.create_cognito_oauth ? "https://${aws_cognito_user_pool_domain.mcp[0].domain}.auth.${data.aws_region.current.name}.amazoncognito.com/oauth2/authorize" : null
}

output "cognito_token_url" {
  description = "Cognito OAuth token URL."
  value       = var.create_cognito_oauth ? "https://${aws_cognito_user_pool_domain.mcp[0].domain}.auth.${data.aws_region.current.name}.amazoncognito.com/oauth2/token" : null
}
