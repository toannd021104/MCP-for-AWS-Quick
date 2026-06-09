resource "aws_iam_role" "quicksight_vpc_connection" {
  count = var.create_quicksight_vpc_connection ? 1 : 0

  name = "${var.name}-quick-vpc-connection"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "quicksight.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "quicksight_vpc_connection" {
  count = var.create_quicksight_vpc_connection ? 1 : 0

  name = "${var.name}-quick-vpc-connection"
  role = aws_iam_role.quicksight_vpc_connection[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:ModifyNetworkInterfaceAttribute",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups"
        ]
        Resource = ["*"]
      }
    ]
  })
}

resource "aws_quicksight_vpc_connection" "this" {
  count = var.create_quicksight_vpc_connection ? 1 : 0

  aws_account_id     = data.aws_caller_identity.current.account_id
  vpc_connection_id  = var.quicksight_vpc_connection_id
  name               = var.quicksight_vpc_connection_name
  role_arn           = aws_iam_role.quicksight_vpc_connection[0].arn
  security_group_ids = [aws_security_group.quicksight_vpc_connection[0].id]
  subnet_ids         = values(aws_subnet.private)[*].id

  tags = local.common_tags

  depends_on = [
    aws_iam_role_policy.quicksight_vpc_connection,
    aws_route_table_association.private
  ]

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}

