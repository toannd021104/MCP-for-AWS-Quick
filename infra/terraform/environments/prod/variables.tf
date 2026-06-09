variable "aws_profile" {
  description = "AWS CLI profile used by Terraform."
  type        = string
  default     = "mcp"
}

variable "aws_region" {
  description = "AWS region for the MCP stack."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Base name for resources."
  type        = string
  default     = "private-mcp"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "prod"
}

variable "vpc_id" {
  description = "Existing VPC ID where the private MCP stack is deployed."
  type        = string
}

variable "private_subnets" {
  description = "Private subnets to create for ECS tasks and VPC endpoints."
  type = map(object({
    availability_zone = string
    cidr_block        = string
  }))
}

variable "domain_name" {
  description = "Private DNS name for the MCP endpoint."
  type        = string
}

variable "hosted_zone_name" {
  description = "Route53 hosted zone name used for the ALB alias."
  type        = string
}

variable "route53_private_zone" {
  description = "Whether hosted_zone_name is a private hosted zone."
  type        = bool
  default     = true
}

variable "alb_ingress_cidr_blocks" {
  description = "CIDR blocks allowed to reach the internal ALB. Use the VPC CIDR or a narrower Quick VPC connection range."
  type        = list(string)
}

variable "create_quicksight_vpc_connection" {
  description = "Whether to create an Amazon QuickSight/Quick VPC connection for the private MCP server."
  type        = bool
  default     = true
}

variable "quicksight_vpc_connection_id" {
  description = "ID for the Amazon QuickSight/Quick VPC connection."
  type        = string
  default     = "private-mcp-vpc"
}

variable "quicksight_vpc_connection_name" {
  description = "Display name for the Amazon QuickSight/Quick VPC connection."
  type        = string
  default     = "Private MCP VPC"
}

variable "enable_https" {
  description = "Whether to create an HTTPS listener on the ALB."
  type        = bool
  default     = false
}

variable "create_acm_certificate" {
  description = "Whether Terraform should request and validate an ACM certificate."
  type        = bool
  default     = false
}

variable "certificate_arn" {
  description = "Existing ACM certificate ARN. Required when create_acm_certificate is false and enable_https is true."
  type        = string
  default     = null
}

variable "create_route53_records" {
  description = "Whether Terraform should create Route53 validation and ALB alias records."
  type        = bool
  default     = true
}

variable "container_image" {
  description = "Container image for the MCP server. If null, the module uses the ECR repo latest tag it creates."
  type        = string
  default     = null
}

variable "container_port" {
  description = "Port exposed by the MCP server container."
  type        = number
  default     = 8080
}

variable "cpu" {
  description = "Fargate task CPU units."
  type        = number
  default     = 512
}

variable "memory" {
  description = "Fargate task memory in MiB."
  type        = number
  default     = 1024
}

variable "desired_count" {
  description = "Desired ECS service task count."
  type        = number
  default     = 1
}

variable "environment_variables" {
  description = "Plain environment variables passed to the MCP container."
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Container secrets. Keys become env var names and values are Secrets Manager or SSM parameter ARNs."
  type        = map(string)
  default     = {}
}

variable "create_mock_data_sources" {
  description = "Whether to create cheap mock S3 and RDS data sources for MCP testing."
  type        = bool
  default     = true
}

variable "mock_rds_database_name" {
  description = "Database name for the mock RDS PostgreSQL instance."
  type        = string
  default     = "mockdata"
}

variable "mock_rds_username" {
  description = "Master username for the mock RDS PostgreSQL instance."
  type        = string
  default     = "mcp_admin"
}

variable "mock_s3_key" {
  description = "S3 object key containing mock data."
  type        = string
  default     = "mock/orders.json"
}

variable "create_cognito_oauth" {
  description = "Whether to create Cognito OAuth resources for the MCP connector."
  type        = bool
  default     = true
}

variable "cognito_callback_urls" {
  description = "Allowed OAuth callback URLs from Amazon Quick."
  type        = list(string)
  default     = []
}

variable "cognito_logout_urls" {
  description = "Allowed OAuth logout URLs."
  type        = list(string)
  default     = []
}

variable "cognito_test_user_email" {
  description = "Email for an optional Cognito test user."
  type        = string
  default     = null
}

variable "cognito_test_user_temporary_password" {
  description = "Temporary password for the optional Cognito test user."
  type        = string
  default     = null
  sensitive   = true
}

variable "default_tags" {
  description = "Default tags applied to AWS resources."
  type        = map(string)
  default = {
    Project     = "private-mcp"
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}
