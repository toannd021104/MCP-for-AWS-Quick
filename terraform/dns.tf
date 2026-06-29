############################################################
# Route 53 private hosted zone for the MCP hostname.
#
# The zone is associated with the VPC, so the hostname only
# resolves inside the VPC (split-horizon DNS).
#
# The alias A record pointing at the internal ALB is added
# later, once the ALB exists.
############################################################

resource "aws_route53_zone" "private" {
  name = var.hosted_zone_name

  vpc {
    vpc_id = aws_vpc.this.id
  }

  tags = merge(local.common_tags, { Name = "${var.name}-private-zone" })
}

# Step 6 — alias record: mcp.example.com -> internal ALB.
# Makes the hostname resolve to the ALB, but ONLY inside the VPC.
resource "aws_route53_record" "mcp" {
  zone_id = aws_route53_zone.private.zone_id
  name    = var.hostname
  type    = "A"

  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = false
  }
}
