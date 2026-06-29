############################################################
# SSH key pair for the bastion and MCP server.
#
# Terraform generates an RSA key, registers the public key as
# an EC2 key pair, and writes the private key to a local .pem
# file (chmod 0600) so you can SSH in.
############################################################

resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "this" {
  key_name   = var.key_name
  public_key = tls_private_key.this.public_key_openssh

  tags = local.common_tags
}

resource "local_sensitive_file" "private_key" {
  content         = tls_private_key.this.private_key_pem
  filename        = "${path.module}/${var.key_name}.pem"
  file_permission = "0600"
}
