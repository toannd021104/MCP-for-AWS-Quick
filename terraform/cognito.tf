############################################################
# Service-to-service OAuth (AUTH_MODE=service)
#
# Quick fetches a Bearer JWT from the Cognito token endpoint
# (client_credentials grant) and attaches it to each MCP request.
# The MCP server validates the JWT (RS256 via JWKS + scope check).
#
# The Cognito token endpoint is PUBLIC, which satisfies Quick's
# requirement that OAuth endpoints stay publicly reachable.
############################################################

resource "aws_cognito_user_pool" "mcp" {
  count = var.enable_oauth ? 1 : 0

  name = "${var.name}-mcp"

  tags = local.common_tags
}

# Resource server defines the custom scope the service client requests.
resource "aws_cognito_resource_server" "mcp" {
  count = var.enable_oauth ? 1 : 0

  identifier   = "private-mcp"
  name         = "Private MCP"
  user_pool_id = aws_cognito_user_pool.mcp[0].id

  scope {
    scope_name        = "invoke"
    scope_description = "Invoke private MCP tools"
  }
}

# Machine-to-machine client used by Quick (client_credentials).
resource "aws_cognito_user_pool_client" "mcp_service" {
  count = var.enable_oauth ? 1 : 0

  name         = "${var.name}-mcp-service"
  user_pool_id = aws_cognito_user_pool.mcp[0].id

  generate_secret = true

  allowed_oauth_flows                  = ["client_credentials"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["private-mcp/invoke"]

  access_token_validity = 1
  token_validity_units {
    access_token = "hours"
  }

  depends_on = [aws_cognito_resource_server.mcp]
}

# Hosted domain that exposes the public token endpoint.
resource "aws_cognito_user_pool_domain" "mcp" {
  count = var.enable_oauth ? 1 : 0

  domain       = "${var.name}-mcp-${data.aws_caller_identity.current.account_id}"
  user_pool_id = aws_cognito_user_pool.mcp[0].id
}

############################################################
# OAuth outputs (only meaningful when enable_oauth = true).
# You enter these in the Quick connector under
# "Service-to-service OAuth".
############################################################

output "oauth_token_endpoint" {
  description = "Cognito token endpoint (client_credentials). Public URL."
  value       = var.enable_oauth ? "https://${aws_cognito_user_pool_domain.mcp[0].domain}.auth.${var.region}.amazoncognito.com/oauth2/token" : null
}

output "oauth_client_id" {
  description = "Cognito service client ID for Quick."
  value       = var.enable_oauth ? aws_cognito_user_pool_client.mcp_service[0].id : null
}

output "oauth_client_secret" {
  description = "Cognito service client secret for Quick."
  value       = var.enable_oauth ? aws_cognito_user_pool_client.mcp_service[0].client_secret : null
  sensitive   = true
}

output "oauth_scope" {
  description = "OAuth scope Quick must request."
  value       = "private-mcp/invoke"
}
