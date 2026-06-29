############################################################
# Step 3 — MCP server EC2 (Jaeger + Python MCP) + bastion
#
# - MCP server: ARM instance in a PRIVATE subnet, runs Jaeger
#   all-in-one + the Python MCP server on :8000 via user-data.
# - Bastion: small ARM instance in the PUBLIC subnet for SSH.
############################################################

# Latest Amazon Linux 2023 ARM64 AMI (resolved via SSM, same as the blog)
data "aws_ssm_parameter" "al2023_arm64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

# MCP server in the private subnet (us-east-1a)
resource "aws_instance" "mcp" {
  ami                    = data.aws_ssm_parameter.al2023_arm64.value
  instance_type          = var.mcp_instance_type
  subnet_id              = aws_subnet.private["private_a"].id
  vpc_security_group_ids = [aws_security_group.mcp.id]
  key_name               = aws_key_pair.this.key_name

  user_data = templatefile("${path.module}/mcp-userdata.sh.tftpl",
    {
      mcp_port     = var.mcp_port
      mcp_repo_url = var.mcp_repo_url

      auth_mode            = var.enable_oauth ? "service" : "none"
      oauth_issuer         = var.enable_oauth ? "https://cognito-idp.${var.region}.amazonaws.com/${aws_cognito_user_pool.mcp[0].id}" : ""
      oauth_jwks_url       = var.enable_oauth ? "https://cognito-idp.${var.region}.amazonaws.com/${aws_cognito_user_pool.mcp[0].id}/.well-known/jwks.json" : ""
      oauth_client_id      = var.enable_oauth ? aws_cognito_user_pool_client.mcp_service[0].id : ""
      oauth_required_scope = "private-mcp/invoke"
  })

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = merge(local.common_tags, { Name = "jaeger-mcp-prod-server" })

  depends_on = [aws_route.private_default]
}

# Bastion in the public subnet
resource "aws_instance" "bastion" {
  ami                         = data.aws_ssm_parameter.al2023_arm64.value
  instance_type               = var.bastion_instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  key_name                    = aws_key_pair.this.key_name
  associate_public_ip_address = true

  tags = merge(local.common_tags, { Name = "jaeger-mcp-prod-bastion" })
}
