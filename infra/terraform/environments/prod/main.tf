module "private_mcp_stack" {
  source = "../../modules/private-mcp-stack"

  name        = var.name
  environment = var.environment

  vpc_id                  = var.vpc_id
  private_subnets         = var.private_subnets
  alb_ingress_cidr_blocks = var.alb_ingress_cidr_blocks

  create_quicksight_vpc_connection = var.create_quicksight_vpc_connection
  quicksight_vpc_connection_id     = var.quicksight_vpc_connection_id
  quicksight_vpc_connection_name   = var.quicksight_vpc_connection_name

  domain_name            = var.domain_name
  hosted_zone_name       = var.hosted_zone_name
  route53_private_zone   = var.route53_private_zone
  enable_https           = var.enable_https
  create_acm_certificate = var.create_acm_certificate
  certificate_arn        = var.certificate_arn
  create_route53_records = var.create_route53_records

  container_image = var.container_image
  container_port  = var.container_port
  cpu             = var.cpu
  memory          = var.memory
  desired_count   = var.desired_count

  environment_variables = var.environment_variables
  secrets               = var.secrets

  create_mock_data_sources = var.create_mock_data_sources
  mock_rds_database_name   = var.mock_rds_database_name
  mock_rds_username        = var.mock_rds_username
  mock_s3_key              = var.mock_s3_key

  create_cognito_oauth                 = var.create_cognito_oauth
  cognito_callback_urls                = var.cognito_callback_urls
  cognito_logout_urls                  = var.cognito_logout_urls
  cognito_test_user_email              = var.cognito_test_user_email
  cognito_test_user_temporary_password = var.cognito_test_user_temporary_password

  tags = var.default_tags
}
