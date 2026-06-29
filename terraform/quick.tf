############################################################
# Step 8 — Amazon Quick (QuickSight) VPC connection
#
# Lets Quick send traffic into the private subnets. Creates ENIs
# using a security group we control, and points them at the
# resolver inbound IPs from Step 7.
############################################################

# SG for the Quick connection ENIs: egress 443 to ALB SG, DNS 53 to resolver SG.
resource "aws_security_group" "quick_eni" {
  name        = "${var.name}-quick-eni"
  description = "Quick VPC connection ENIs"
  vpc_id      = aws_vpc.this.id

  tags = merge(local.common_tags, { Name = "${var.name}-quick-eni" })
}

resource "aws_security_group_rule" "quick_egress_https_to_alb" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  description              = "HTTPS to ALB"
  security_group_id        = aws_security_group.quick_eni.id
  source_security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "quick_egress_dns_tcp_to_resolver" {
  type                     = "egress"
  from_port                = 53
  to_port                  = 53
  protocol                 = "tcp"
  description              = "DNS TCP to resolver"
  security_group_id        = aws_security_group.quick_eni.id
  source_security_group_id = aws_security_group.resolver_inbound.id
}

resource "aws_security_group_rule" "quick_egress_dns_udp_to_resolver" {
  type                     = "egress"
  from_port                = 53
  to_port                  = 53
  protocol                 = "udp"
  description              = "DNS UDP to resolver"
  security_group_id        = aws_security_group.quick_eni.id
  source_security_group_id = aws_security_group.resolver_inbound.id
}

# Allow the ALB SG to accept 443 from the Quick ENI SG.
resource "aws_security_group_rule" "alb_https_from_quick" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  description              = "HTTPS from Quick ENIs"
  security_group_id        = aws_security_group.alb.id
  source_security_group_id = aws_security_group.quick_eni.id
}

# IAM role Quick assumes to manage its ENIs (trust = quicksight.amazonaws.com).
resource "aws_iam_role" "quick_vpc_connection" {
  name = "${var.name}-quick-vpc-conn"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "quicksight.amazonaws.com" }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "quick_vpc_connection" {
  name = "${var.name}-quick-vpc-conn"
  role = aws_iam_role.quick_vpc_connection.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:CreateNetworkInterface",
        "ec2:ModifyNetworkInterfaceAttribute",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups"
      ]
      Resource = ["*"]
    }]
  })
}

resource "aws_quicksight_vpc_connection" "this" {
  aws_account_id    = data.aws_caller_identity.current.account_id
  vpc_connection_id = "quick-mcp-vpc"
  name              = "Quick MCP Toannd VPC"
  role_arn          = aws_iam_role.quick_vpc_connection.arn

  security_group_ids = [aws_security_group.quick_eni.id]
  subnet_ids         = values(aws_subnet.private)[*].id

  # Resolver inbound IPs from Step 7. This reference forces Terraform to
  # create the resolver endpoint BEFORE the VPC connection.
  dns_resolvers = aws_route53_resolver_endpoint.inbound.ip_address[*].ip

  tags = local.common_tags

  depends_on = [aws_iam_role_policy.quick_vpc_connection]

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}
