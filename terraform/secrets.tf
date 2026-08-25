resource "random_password" "postgres_admin" {
  length           = 32
  special          = true
  override_special = "_%@"
}

resource "random_password" "postgres_app" {
  length           = 32
  special          = true
  override_special = "_%@"
}

resource "random_password" "postgres_dbm" {
  length           = 32
  special          = true
  override_special = "_%@"
}

resource "aws_secretsmanager_secret" "dd_api_key" {
  provider                = aws.us_east_1
  name                    = "${local.project_name}-use1-datadog-api-key"
  description             = "Datadog API Key (us-east-1)"
  recovery_window_in_days = 0

  tags = merge(local.common_tags, { Name = "${local.project_name}-use1-datadog-api-key" })
}

resource "aws_secretsmanager_secret_version" "dd_api_key" {
  provider      = aws.us_east_1
  secret_id     = aws_secretsmanager_secret.dd_api_key.id
  secret_string = var.dd_api_key
}

resource "aws_secretsmanager_secret" "database" {
  provider                = aws.us_east_1
  name_prefix             = "${local.project_name}-database-"
  description             = "RDS PostgreSQL credentials for ${local.project_name}"
  recovery_window_in_days = 0

  tags = merge(local.common_tags, { Name = "${local.project_name}-database" })
}

resource "aws_secretsmanager_secret_version" "database" {
  provider  = aws.us_east_1
  secret_id = aws_secretsmanager_secret.database.id
  secret_string = jsonencode({
    admin_username = var.postgres_admin_username
    admin_password = random_password.postgres_admin.result
    app_username   = var.postgres_app_username
    app_password   = random_password.postgres_app.result
    database_name  = var.database_name
    dbm_username   = var.postgres_dbm_username
    dbm_password   = random_password.postgres_dbm.result
  })
}

resource "aws_secretsmanager_secret" "private_location_config" {
  provider                = aws.us_east_1
  name_prefix             = "${local.project_name}-private-location-"
  description             = "Datadog Synthetics Private Location Worker config for ${local.project_name}"
  recovery_window_in_days = 0

  tags = merge(local.common_tags, { Name = "${local.project_name}-private-location" })
}

resource "aws_secretsmanager_secret_version" "private_location_config" {
  provider  = aws.us_east_1
  secret_id = aws_secretsmanager_secret.private_location_config.id
  secret_string = jsonencode(merge(
    jsondecode(datadog_synthetics_private_location.main.config),
    {
      datadogApiKey            = var.dd_api_key
      proxyDatadog             = "http://${local.tenant_datadog_proxy_dns}:${var.proxy_port}"
      proxyEnableConnectTunnel = true
    }
  ))
}

resource "aws_secretsmanager_secret" "synthetics_pl_config" {
  provider                = aws.us_east_1
  name                    = "${local.project_name}-use1-synthetics-pl-config"
  description             = "Synthetics Private Location config (us-east-1, Worker用)"
  recovery_window_in_days = 0

  tags = merge(local.common_tags, { Name = "${local.project_name}-use1-synthetics-pl-config" })
}

resource "aws_secretsmanager_secret_version" "synthetics_pl_config" {
  provider      = aws.us_east_1
  secret_id     = aws_secretsmanager_secret.synthetics_pl_config.id
  secret_string = datadog_synthetics_private_location.main.config
}

resource "aws_secretsmanager_secret" "bastion_ssh_private_key" {
  provider                = aws.us_east_1
  name_prefix             = "${local.project_name}-bastion-ssh-"
  description             = "Java bastion ProxyJump 用 SSH 秘密鍵（EC2 userdata から取得）"
  recovery_window_in_days = 0

  tags = merge(local.common_tags, { Name = "${local.project_name}-bastion-ssh" })
}

resource "aws_secretsmanager_secret_version" "bastion_ssh_private_key" {
  provider      = aws.us_east_1
  secret_id     = aws_secretsmanager_secret.bastion_ssh_private_key.id
  secret_string = tls_private_key.ec2.private_key_pem
}
