terraform {
  required_version = ">= 1.6.0"

  backend "s3" {
    bucket       = "private-mcp-terraform-state-307711587176-us-east-1"
    key          = "private-mcp/prod/terraform.tfstate"
    region       = "us-east-1"
    profile      = "mcp"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
