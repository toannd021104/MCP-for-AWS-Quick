data "aws_caller_identity" "current" {}

locals {
  common_tags = merge(
    {
      Project   = "quick-mcp"
      ManagedBy = "terraform"
    },
    var.tags
  )
}
