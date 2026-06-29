############################################################
# Step 2 — Security groups
#
# Trust chain: bastion ──SSH──► MCP, ALB ──8000──► MCP,
# and the ALB accepts 443 from within the VPC.
# Terraform wires the SG references automatically, so no
# hardcoded sg-xxxx IDs are needed.
############################################################

# Bastion SG — SSH from the internet
resource "aws_security_group" "bastion" {
  name        = "${var.name}-bastion-sg"
  description = "Bastion SSH"
  vpc_id      = aws_vpc.this.id

  tags = merge(local.common_tags, { Name = "${var.name}-bastion-sg" })
}

resource "aws_security_group_rule" "bastion_ssh_in" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.ssh_ingress_cidr]
  description       = "SSH from the internet"
  security_group_id = aws_security_group.bastion.id
}

resource "aws_security_group_rule" "bastion_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Bastion outbound"
  security_group_id = aws_security_group.bastion.id
}

# ALB SG — HTTPS 443 from within the VPC
resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "Internal ALB"
  vpc_id      = aws_vpc.this.id

  tags = merge(local.common_tags, { Name = "${var.name}-alb-sg" })
}

resource "aws_security_group_rule" "alb_https_in_vpc" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  description       = "HTTPS from within the VPC"
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_egress_to_mcp" {
  type                     = "egress"
  from_port                = var.mcp_port
  to_port                  = var.mcp_port
  protocol                 = "tcp"
  description              = "Forward to MCP server"
  security_group_id        = aws_security_group.alb.id
  source_security_group_id = aws_security_group.mcp.id
}

# MCP SG — 8000 only from the ALB SG; SSH only from the bastion SG
resource "aws_security_group" "mcp" {
  name        = "${var.name}-sg"
  description = "Private MCP server"
  vpc_id      = aws_vpc.this.id

  tags = merge(local.common_tags, { Name = "${var.name}-sg" })
}

resource "aws_security_group_rule" "mcp_app_from_alb" {
  type                     = "ingress"
  from_port                = var.mcp_port
  to_port                  = var.mcp_port
  protocol                 = "tcp"
  description              = "MCP app port from ALB"
  security_group_id        = aws_security_group.mcp.id
  source_security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "mcp_ssh_from_bastion" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  description              = "SSH from bastion"
  security_group_id        = aws_security_group.mcp.id
  source_security_group_id = aws_security_group.bastion.id
}

resource "aws_security_group_rule" "mcp_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Outbound for setup (Docker, pip, Jaeger image) via NAT"
  security_group_id = aws_security_group.mcp.id
}
