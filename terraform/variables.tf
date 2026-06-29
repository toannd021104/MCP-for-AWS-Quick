variable "region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Base name for resources."
  type        = string
  default     = "private-mcp"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnets" {
  description = "Private subnets to create (one per AZ)."
  type = map(object({
    availability_zone = string
    cidr_block        = string
  }))
  default = {
    private_a = {
      availability_zone = "us-east-1a"
      cidr_block        = "10.0.96.0/20"
    }
    private_b = {
      availability_zone = "us-east-1b"
      cidr_block        = "10.0.112.0/20"
    }
  }
}

variable "public_subnet" {
  description = "Public subnet (hosts NAT gateway + bastion)."
  type = object({
    availability_zone = string
    cidr_block        = string
  })
  default = {
    availability_zone = "us-east-1a"
    cidr_block        = "10.0.0.0/20"
  }
}

variable "ssh_ingress_cidr" {
  description = "CIDR allowed to SSH into the bastion."
  type        = string
  default     = "0.0.0.0/0"
}

variable "mcp_port" {
  description = "Port the MCP server listens on."
  type        = number
  default     = 8000
}

variable "key_name" {
  description = "Existing EC2 key pair name for SSH access to bastion and MCP server."
  type        = string
  default     = "quick-mcp-key"
}

variable "mcp_instance_type" {
  description = "Instance type for the MCP server (ARM)."
  type        = string
  default     = "t4g.medium"
}

variable "bastion_instance_type" {
  description = "Instance type for the bastion (ARM)."
  type        = string
  default     = "t4g.nano"
}

variable "mcp_repo_url" {
  description = "Git repository URL for the MCP server cloned by user-data."
  type        = string
  default     = "https://github.com/toannd021104/jaeger-mcp.git"
}

variable "enable_oauth" {
  description = "Enable service-to-service OAuth (Cognito client_credentials). false = No authentication."
  type        = bool
  default     = false
}

variable "hostname" {
  description = "Private DNS name for the MCP endpoint."
  type        = string
  default     = "mcp.example.com"
}

variable "hosted_zone_name" {
  description = "Route 53 private hosted zone name."
  type        = string
  default     = "example.com"
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
