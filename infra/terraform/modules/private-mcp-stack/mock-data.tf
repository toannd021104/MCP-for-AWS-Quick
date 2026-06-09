resource "aws_s3_bucket" "mock_data" {
  count = var.create_mock_data_sources ? 1 : 0

  bucket_prefix = "${var.name}-mock-data-"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name}-mock-data"
    }
  )
}

resource "aws_s3_bucket_public_access_block" "mock_data" {
  count = var.create_mock_data_sources ? 1 : 0

  bucket                  = aws_s3_bucket.mock_data[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "mock_data" {
  count = var.create_mock_data_sources ? 1 : 0

  bucket = aws_s3_bucket.mock_data[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_object" "mock_orders" {
  count = var.create_mock_data_sources ? 1 : 0

  bucket       = aws_s3_bucket.mock_data[0].id
  key          = var.mock_s3_key
  content_type = "application/json"
  content = jsonencode({
    orders = [
      {
        order_id    = "ORD-1001"
        customer_id = "CUST-001"
        customer    = "Acme Vietnam"
        amount      = 1250.75
        currency    = "USD"
        status      = "paid"
        order_date  = "2026-06-01"
      },
      {
        order_id    = "ORD-1002"
        customer_id = "CUST-002"
        customer    = "Lotus Retail"
        amount      = 540.10
        currency    = "USD"
        status      = "processing"
        order_date  = "2026-06-03"
      },
      {
        order_id    = "ORD-1003"
        customer_id = "CUST-001"
        customer    = "Acme Vietnam"
        amount      = 310.00
        currency    = "USD"
        status      = "paid"
        order_date  = "2026-06-08"
      }
    ]
  })
}

resource "aws_db_subnet_group" "mock" {
  count = var.create_mock_data_sources ? 1 : 0

  name       = "${var.name}-mock"
  subnet_ids = values(aws_subnet.private)[*].id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name}-mock"
    }
  )
}

resource "aws_security_group" "mock_rds" {
  count = var.create_mock_data_sources ? 1 : 0

  name        = "${var.name}-mock-rds"
  description = "Mock RDS PostgreSQL for private MCP"
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name}-mock-rds"
    }
  )
}

resource "aws_security_group_rule" "mock_rds_inbound_from_ecs" {
  count = var.create_mock_data_sources ? 1 : 0

  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  description              = "PostgreSQL from MCP ECS tasks"
  security_group_id        = aws_security_group.mock_rds[0].id
  source_security_group_id = aws_security_group.ecs_tasks.id
}

resource "aws_security_group_rule" "ecs_egress_to_mock_rds" {
  count = var.create_mock_data_sources ? 1 : 0

  type                     = "egress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  description              = "PostgreSQL to mock RDS"
  security_group_id        = aws_security_group.ecs_tasks.id
  source_security_group_id = aws_security_group.mock_rds[0].id
}

resource "aws_db_instance" "mock" {
  count = var.create_mock_data_sources ? 1 : 0

  identifier                  = "${var.name}-mock"
  engine                      = "postgres"
  engine_version              = "16"
  instance_class              = "db.t4g.micro"
  allocated_storage           = 20
  max_allocated_storage       = 20
  storage_type                = "gp3"
  storage_encrypted           = true
  db_name                     = var.mock_rds_database_name
  username                    = var.mock_rds_username
  manage_master_user_password = true
  db_subnet_group_name        = aws_db_subnet_group.mock[0].name
  vpc_security_group_ids      = [aws_security_group.mock_rds[0].id]
  publicly_accessible         = false
  multi_az                    = false
  backup_retention_period     = 1
  skip_final_snapshot         = true
  deletion_protection         = false
  apply_immediately           = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name}-mock"
    }
  )
}

