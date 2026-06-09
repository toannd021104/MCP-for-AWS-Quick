resource "aws_security_group" "alb" {
  name        = "${var.name}-alb"
  description = "Inbound HTTP/HTTPS for the private MCP internal ALB"
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name}-alb"
    }
  )
}

resource "aws_security_group_rule" "alb_http_inbound" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = var.alb_ingress_cidr_blocks
  description       = "HTTP from Quick VPC connection or VPC clients"
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_https_inbound" {
  count = var.enable_https ? 1 : 0

  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.alb_ingress_cidr_blocks
  description       = "HTTPS from Quick VPC connection or VPC clients"
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_http_inbound_from_quick" {
  count = var.create_quicksight_vpc_connection ? 1 : 0

  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  description              = "HTTP from Amazon Quick VPC connection"
  security_group_id        = aws_security_group.alb.id
  source_security_group_id = aws_security_group.quicksight_vpc_connection[0].id
}

resource "aws_security_group_rule" "alb_https_inbound_from_quick" {
  count = var.create_quicksight_vpc_connection && var.enable_https ? 1 : 0

  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  description              = "HTTPS from Amazon Quick VPC connection"
  security_group_id        = aws_security_group.alb.id
  source_security_group_id = aws_security_group.quicksight_vpc_connection[0].id
}

resource "aws_security_group_rule" "alb_egress_to_ecs" {
  type                     = "egress"
  from_port                = var.container_port
  to_port                  = var.container_port
  protocol                 = "tcp"
  description              = "Forward traffic to ECS tasks"
  security_group_id        = aws_security_group.alb.id
  source_security_group_id = aws_security_group.ecs_tasks.id
}

resource "aws_security_group" "ecs_tasks" {
  name        = "${var.name}-ecs-tasks"
  description = "Private MCP ECS tasks"
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name}-ecs-tasks"
    }
  )
}

resource "aws_security_group" "quicksight_vpc_connection" {
  count = var.create_quicksight_vpc_connection ? 1 : 0

  name        = "${var.name}-quick-vpc-connection"
  description = "Amazon Quick VPC connection for private MCP"
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name}-quick-vpc-connection"
    }
  )
}

resource "aws_security_group_rule" "quick_vpc_connection_egress_http_to_alb" {
  count = var.create_quicksight_vpc_connection ? 1 : 0

  type                     = "egress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  description              = "HTTP to private MCP internal ALB"
  security_group_id        = aws_security_group.quicksight_vpc_connection[0].id
  source_security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "quick_vpc_connection_egress_https_to_alb" {
  count = var.create_quicksight_vpc_connection && var.enable_https ? 1 : 0

  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  description              = "HTTPS to private MCP internal ALB"
  security_group_id        = aws_security_group.quicksight_vpc_connection[0].id
  source_security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "ecs_inbound_from_alb" {
  type                     = "ingress"
  from_port                = var.container_port
  to_port                  = var.container_port
  protocol                 = "tcp"
  description              = "MCP traffic from ALB"
  security_group_id        = aws_security_group.ecs_tasks.id
  source_security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "ecs_egress_https_to_endpoints" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  description              = "AWS private service endpoints"
  security_group_id        = aws_security_group.ecs_tasks.id
  source_security_group_id = aws_security_group.vpc_endpoints.id
}

resource "aws_security_group_rule" "ecs_egress_https_to_s3" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  prefix_list_ids   = [aws_vpc_endpoint.s3.prefix_list_id]
  description       = "ECR image layer downloads through S3 gateway endpoint"
  security_group_id = aws_security_group.ecs_tasks.id
}

resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.name}-vpc-endpoints"
  description = "Private interface VPC endpoints"
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name}-vpc-endpoints"
    }
  )
}

resource "aws_security_group_rule" "vpc_endpoints_inbound_from_ecs" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  description              = "Private HTTPS from ECS tasks"
  security_group_id        = aws_security_group.vpc_endpoints.id
  source_security_group_id = aws_security_group.ecs_tasks.id
}

resource "aws_security_group_rule" "vpc_endpoints_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Endpoint service responses"
  security_group_id = aws_security_group.vpc_endpoints.id
}
