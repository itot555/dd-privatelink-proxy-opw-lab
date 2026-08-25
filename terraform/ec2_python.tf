resource "aws_instance" "python" {
  provider                    = aws.us_east_1
  ami                         = data.aws_ami.ubuntu_us_east_1.id
  instance_type               = var.application_instance_type
  subnet_id                   = module.vpc_tenant.private_subnets[0]
  associate_public_ip_address = false
  key_name                    = aws_key_pair.ec2.key_name
  iam_instance_profile        = aws_iam_instance_profile.ec2.name

  vpc_security_group_ids = [aws_security_group.python.id]

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.application_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/scripts/python_userdata.sh", {
    COMMON_PUBLIC_KEY         = tls_private_key.ec2.public_key_openssh
    APP_SERVICE               = local.application_services.python
    APP_VERSION               = var.dd_version
    AWS_REGION                = "us-east-1"
    BOOTSTRAP_PREFIX          = local.bootstrap_prefix
    BOOTSTRAP_REVISION        = local.bootstrap_revision
    DATADOG_COMMON_CONFIG_KEY = aws_s3_object.bootstrap_datadog_common_python.key
    DATABASE_NAME             = var.database_name
    DATABASE_SECRET_ARN       = aws_secretsmanager_secret.database.arn
    DD_API_KEY_SECRET_ARN     = aws_secretsmanager_secret.dd_api_key.arn
    DD_ENV                    = var.dd_env
    DD_SITE                   = var.dd_site
    DD_HOSTNAME               = local.dd_hostname_python
    ENABLE_DDOT               = var.enable_ddot_collector ? "true" : "false"
    PROJECT_NAME              = local.project_name
    PYTHON_APP_PORT           = var.python_app_port
    RDS_ENDPOINT              = aws_db_instance.main.address
    S3_BUCKET                 = aws_s3_bucket.app_artifacts.id
    APP_ARCHIVE_S3_KEY        = aws_s3_object.python_app.key
    ENABLE_BANKING_DEMO       = var.enable_banking_demo ? "true" : "false"
    DEMO_BANK_PASSWORD        = var.demo_bank_password
    enable_banking_demo       = var.enable_banking_demo
    banking_schema_sql        = file("${path.module}/scripts/banking_schema.sql.tftpl")
  })

  user_data_replace_on_change = true

  depends_on = [
    aws_s3_object.bootstrap_datadog_common_python,
    aws_s3_object.bootstrap_userdata_common,
    aws_s3_object.bootstrap_fetch,
    aws_s3_object.python_app,
    aws_db_instance.main,
    aws_secretsmanager_secret_version.database,
    aws_vpc_endpoint.tenant_to_proxy,
  ]

  tags = merge(local.common_tags, {
    Name    = "${local.project_name}-python"
    Role    = "python"
    Project = local.project_name
  })
}
