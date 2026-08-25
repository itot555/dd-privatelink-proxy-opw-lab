resource "aws_db_subnet_group" "main" {
  provider   = aws.us_east_1
  name       = local.project_name
  subnet_ids = module.vpc_tenant.private_subnets

  tags = merge(local.common_tags, { Name = "${local.project_name}-db-subnet-group" })
}

resource "aws_db_parameter_group" "main" {
  provider    = aws.us_east_1
  name_prefix = "${local.project_name}-"
  family      = "postgres17"
  description = "DBM parameters for ${local.project_name}"

  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "pg_stat_statements.track"
    value = "ALL"
  }

  parameter {
    name  = "track_activity_query_size"
    value = "4096"
  }

  tags = merge(local.common_tags, { Name = "${local.project_name}-db-params" })
}

resource "aws_db_instance" "main" {
  provider = aws.us_east_1

  identifier = local.project_name

  engine         = "postgres"
  engine_version = var.postgres_engine_version
  instance_class = var.database_instance_class

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.database_name
  username = var.postgres_admin_username
  password = random_password.postgres_admin.result
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.main.name
  parameter_group_name   = aws_db_parameter_group.main.name
  vpc_security_group_ids = [aws_security_group.database.id]

  publicly_accessible        = false
  multi_az                   = false
  deletion_protection        = false
  skip_final_snapshot        = true
  apply_immediately          = true
  backup_retention_period    = 1
  auto_minor_version_upgrade = true

  performance_insights_enabled = false

  depends_on = [
    aws_secretsmanager_secret_version.database,
  ]

  tags = merge(local.common_tags, { Name = "${local.project_name}-rds" })
}
