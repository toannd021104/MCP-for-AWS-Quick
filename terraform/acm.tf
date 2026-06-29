############################################################
# Step 4 — Public ACM certificate (DNS validation)
#
# The ALB needs a publicly trusted TLS cert whose name matches
# the hostname (mcp.example.com).
#
# Because the domain lives on an external DNS provider (dpdns.org),
# Terraform requests the certificate and EXPOSES the validation
# CNAME via outputs. You add that CNAME at the DNS provider, then
# ACM flips the cert to ISSUED automatically.
############################################################

resource "aws_acm_certificate" "mcp" {
  domain_name       = var.hostname
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, { Name = "${var.name}-cert" })
}
