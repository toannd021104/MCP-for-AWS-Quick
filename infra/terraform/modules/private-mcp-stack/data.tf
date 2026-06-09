data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_route53_zone" "this" {
  count = var.create_route53_records ? 1 : 0

  name         = var.hosted_zone_name
  private_zone = var.route53_private_zone
}
