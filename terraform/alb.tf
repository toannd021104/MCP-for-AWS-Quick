############################################################
# Step 5 — Internal ALB + target group + HTTPS listener
#
# - ALB: internal (no public IP), spans the 2 private subnets,
#   uses the ALB security group.
# - Target group: HTTP :8000, target-type ip, health check /health.
#   The MCP server's private IP is registered as a target.
# - Listener: HTTPS :443 terminating TLS with the ACM cert,
#   forwarding to the target group.
############################################################

resource "aws_lb" "this" {
  name               = "quick-mcp-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = values(aws_subnet.private)[*].id

  tags = merge(local.common_tags, { Name = "quick-mcp-alb" })
}

resource "aws_lb_target_group" "this" {
  name        = "quick-mcp-tg"
  protocol    = "HTTP"
  port        = var.mcp_port
  target_type = "ip"
  vpc_id      = aws_vpc.this.id

  health_check {
    path    = "/health"
    matcher = "200"
  }

  tags = merge(local.common_tags, { Name = "quick-mcp-tg" })
}

# Register the MCP server's private IP as a target.
resource "aws_lb_target_group_attachment" "mcp" {
  target_group_arn = aws_lb_target_group.this.arn
  target_id        = aws_instance.mcp.private_ip
  port             = var.mcp_port
}

# HTTPS:443 listener using the ACM cert -> forward to the target group.
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  protocol          = "HTTPS"
  port              = 443
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.mcp.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
