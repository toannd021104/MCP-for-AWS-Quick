resource "aws_cognito_user_pool" "mcp" {
  count = var.create_cognito_oauth ? 1 : 0

  name = "${var.name}-mcp"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  admin_create_user_config {
    allow_admin_create_user_only = true
  }

  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = 7
  }

  tags = local.common_tags
}

resource "aws_cognito_resource_server" "mcp" {
  count = var.create_cognito_oauth ? 1 : 0

  identifier   = "private-mcp"
  name         = "Private MCP"
  user_pool_id = aws_cognito_user_pool.mcp[0].id

  scope {
    scope_name        = "invoke"
    scope_description = "Invoke private MCP tools"
  }
}

resource "aws_cognito_user_pool_client" "mcp_user" {
  count = var.create_cognito_oauth ? 1 : 0

  name         = "${var.name}-mcp-user"
  user_pool_id = aws_cognito_user_pool.mcp[0].id

  generate_secret = true

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["openid", "email", "profile", "private-mcp/invoke"]
  callback_urls                        = var.cognito_callback_urls
  logout_urls                          = var.cognito_logout_urls
  supported_identity_providers         = ["COGNITO"]

  explicit_auth_flows = [
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]

  access_token_validity  = 1
  id_token_validity      = 1
  refresh_token_validity = 30

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  depends_on = [aws_cognito_resource_server.mcp]
}

resource "aws_cognito_user_pool_client" "mcp_service" {
  count = var.create_cognito_oauth ? 1 : 0

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

resource "aws_cognito_user_pool_domain" "mcp" {
  count = var.create_cognito_oauth ? 1 : 0

  domain       = "${var.name}-mcp-${data.aws_caller_identity.current.account_id}"
  user_pool_id = aws_cognito_user_pool.mcp[0].id
}

resource "aws_cognito_user" "test" {
  count = var.create_cognito_oauth && var.cognito_test_user_email != null && var.cognito_test_user_temporary_password != null ? 1 : 0

  user_pool_id = aws_cognito_user_pool.mcp[0].id
  username     = var.cognito_test_user_email

  attributes = {
    email          = var.cognito_test_user_email
    email_verified = "true"
  }

  temporary_password = var.cognito_test_user_temporary_password
  message_action     = "SUPPRESS"
}
