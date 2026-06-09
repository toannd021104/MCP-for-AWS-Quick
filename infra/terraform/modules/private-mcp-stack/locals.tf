locals {
  common_tags = merge(
    var.tags,
    {
      Name        = var.name
      Environment = var.environment
    }
  )

  container_image = coalesce(var.container_image, "${aws_ecr_repository.this.repository_url}:latest")

  certificate_arn = var.enable_https ? (
    var.create_acm_certificate ? aws_acm_certificate_validation.this[0].certificate_arn : var.certificate_arn
  ) : null

  endpoint_services = toset([
    "cognito-idp",
    "ecr.api",
    "ecr.dkr",
    "logs",
    "secretsmanager"
  ])

  mock_environment_variables = var.create_mock_data_sources ? {
    MOCK_S3_BUCKET = aws_s3_bucket.mock_data[0].bucket
    MOCK_S3_KEY    = var.mock_s3_key
    RDS_HOST       = aws_db_instance.mock[0].address
    RDS_PORT       = tostring(aws_db_instance.mock[0].port)
    RDS_DB_NAME    = var.mock_rds_database_name
  } : {}

  oauth_environment_variables = var.create_cognito_oauth ? {
    OAUTH_ENABLED    = "true"
    OAUTH_ISSUER     = "https://cognito-idp.${data.aws_region.current.name}.amazonaws.com/${aws_cognito_user_pool.mcp[0].id}"
    OAUTH_AUDIENCES  = join(",", [aws_cognito_user_pool_client.mcp_user[0].id, aws_cognito_user_pool_client.mcp_service[0].id])
    OAUTH_JWKS_URL   = "https://cognito-idp.${data.aws_region.current.name}.amazonaws.com/${aws_cognito_user_pool.mcp[0].id}/.well-known/jwks.json"
    OAUTH_AUTH_URL   = "https://${aws_cognito_user_pool_domain.mcp[0].domain}.auth.${data.aws_region.current.name}.amazoncognito.com/oauth2/authorize"
    OAUTH_TOKEN_URL  = "https://${aws_cognito_user_pool_domain.mcp[0].domain}.auth.${data.aws_region.current.name}.amazoncognito.com/oauth2/token"
    OAUTH_SCOPE      = "private-mcp/invoke"
    MCP_RESOURCE_URL = var.enable_https ? "https://${var.domain_name}/mcp" : "http://${var.domain_name}/mcp"
  } : {}

  mock_container_secrets = var.create_mock_data_sources ? {
    RDS_SECRET_JSON = aws_db_instance.mock[0].master_user_secret[0].secret_arn
  } : {}

  container_environment = [
    for key, value in merge(var.environment_variables, local.mock_environment_variables, local.oauth_environment_variables) : {
      name  = key
      value = value
    }
  ]

  container_secrets = [
    for key, value in merge(var.secrets, local.mock_container_secrets) : {
      name      = key
      valueFrom = value
    }
  ]
}
