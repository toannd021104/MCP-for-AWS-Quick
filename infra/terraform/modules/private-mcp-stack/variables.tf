variable "name" {
  description = "Base name for resources."
  type        = string
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
}

variable "vpc_id" {
  description = "Existing VPC ID where resources are deployed."
  type        = string
}

variable "private_subnets" {
  description = "Private subnets to create for ECS and VPC endpoints."
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
  description = "Route53 hosted zone name."
  type        = string
}

variable "route53_private_zone" {
  description = "Whether the hosted zone is private."
  type        = bool
  default     = true
}

variable "alb_ingress_cidr_blocks" {
  description = "CIDR blocks allowed to reach the internal ALB."
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
  description = "Whether to create an HTTPS listener."
  type        = bool
  default     = false
}

variable "create_acm_certificate" {
  description = "Whether to request and validate an ACM certificate."
  type        = bool
  default     = false
}

variable "certificate_arn" {
  description = "Existing ACM certificate ARN."
  type        = string
  default     = null
}

variable "create_route53_records" {
  description = "Whether to create Route53 DNS records."
  type        = bool
  default     = true
}

variable "container_image" {
  description = "Container image for the MCP server."
  type        = string
  default     = null
}

variable "container_port" {
  description = "Container port for the MCP server."
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
  description = "Desired ECS service count."
  type        = number
  default     = 1
}

variable "environment_variables" {
  description = "Plain environment variables passed to the MCP container."
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Container secrets. Keys become env var names and values are secret ARNs."
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
  default     = false
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

variable "tags" {
  description = "Tags applied to resources."
  type        = map(string)
  default     = {}
}
