output "alb_dns_name" {
  description = "ALB DNS name."
  value       = module.private_mcp_stack.alb_dns_name
}

output "mcp_endpoint_url" {
  description = "MCP endpoint URL to configure in Amazon Quick."
  value       = module.private_mcp_stack.mcp_endpoint_url
}

output "ecr_repository_url" {
  description = "ECR repository URL for the MCP server image."
  value       = module.private_mcp_stack.ecr_repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = module.private_mcp_stack.ecs_cluster_name
}

output "ecs_service_name" {
  description = "ECS service name."
  value       = module.private_mcp_stack.ecs_service_name
}

output "quicksight_vpc_connection_id" {
  description = "Amazon QuickSight/Quick VPC connection ID."
  value       = module.private_mcp_stack.quicksight_vpc_connection_id
}

output "quicksight_vpc_connection_status" {
  description = "Amazon QuickSight/Quick VPC connection availability status."
  value       = module.private_mcp_stack.quicksight_vpc_connection_status
}

output "mock_s3_bucket" {
  description = "Mock S3 bucket name."
  value       = module.private_mcp_stack.mock_s3_bucket
}

output "mock_rds_endpoint" {
  description = "Mock RDS PostgreSQL endpoint."
  value       = module.private_mcp_stack.mock_rds_endpoint
}

output "cognito_user_client_id" {
  description = "Cognito OAuth user client ID."
  value       = module.private_mcp_stack.cognito_user_client_id
}

output "cognito_user_client_secret" {
  description = "Cognito OAuth user client secret."
  value       = module.private_mcp_stack.cognito_user_client_secret
  sensitive   = true
}

output "cognito_service_client_id" {
  description = "Cognito OAuth service client ID."
  value       = module.private_mcp_stack.cognito_service_client_id
}

output "cognito_service_client_secret" {
  description = "Cognito OAuth service client secret."
  value       = module.private_mcp_stack.cognito_service_client_secret
  sensitive   = true
}

output "cognito_authorization_url" {
  description = "Cognito OAuth authorization URL."
  value       = module.private_mcp_stack.cognito_authorization_url
}

output "cognito_token_url" {
  description = "Cognito OAuth token URL."
  value       = module.private_mcp_stack.cognito_token_url
}
