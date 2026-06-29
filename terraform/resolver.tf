############################################################
# Step 7 — Route 53 Resolver INBOUND endpoint
#
# Amazon Quick does not use the default VPC DNS resolver, so it
# needs explicit resolver IPs that can answer the private hostname.
# This endpoint's ENIs get fixed private IPs that Quick will query
# (fed into the Quick VPC connection in Step 8).
############################################################

resource "aws_security_group" "resolver_inbound" {
  name        = "${var.name}-resolver-inbound"
  description = "DNS inbound for Quick MCP resolver"
  vpc_id      = aws_vpc.this.id

  tags = merge(local.common_tags, { Name = "${var.name}-resolver-inbound" })
}

resource "aws_security_group_rule" "resolver_dns_tcp" {
  type              = "ingress"
  from_port         = 53
  to_port           = 53
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  description       = "DNS TCP from within the VPC"
  security_group_id = aws_security_group.resolver_inbound.id
}

resource "aws_security_group_rule" "resolver_dns_udp" {
  type              = "ingress"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  cidr_blocks       = [var.vpc_cidr]
  description       = "DNS UDP from within the VPC"
  security_group_id = aws_security_group.resolver_inbound.id
}

resource "aws_route53_resolver_endpoint" "inbound" {
  name      = "${var.name}-resolver-inbound"
  direction = "INBOUND"

  security_group_ids = [aws_security_group.resolver_inbound.id]

  dynamic "ip_address" {
    for_each = values(aws_subnet.private)
    content {
      subnet_id = ip_address.value.id
    }
  }

  tags = local.common_tags
}
