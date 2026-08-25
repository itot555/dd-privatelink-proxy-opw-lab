resource "aws_instance" "frontend" {
  provider                    = aws.us_east_1
  ami                         = data.aws_ami.ubuntu_us_east_1.id
  instance_type               = var.frontend_instance_type
  subnet_id                   = module.vpc_tenant.public_subnets[0]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.ec2.key_name
  iam_instance_profile        = aws_iam_instance_profile.ec2.name

  vpc_security_group_ids = [aws_security_group.frontend.id]

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.application_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/scripts/frontend_userdata.sh", {
    COMMON_PUBLIC_KEY         = tls_private_key.ec2.public_key_openssh
    AWS_REGION                = "us-east-1"
    BOOTSTRAP_PREFIX          = local.bootstrap_prefix
    BOOTSTRAP_REVISION        = local.bootstrap_revision
    DATADOG_COMMON_CONFIG_KEY = aws_s3_object.bootstrap_datadog_common_frontend.key
    DD_API_KEY_SECRET_ARN     = aws_secretsmanager_secret.dd_api_key.arn
    DD_HOSTNAME               = local.dd_hostname_frontend
    DD_ENV                    = var.dd_env
    DD_SITE                   = var.dd_site
    DD_VERSION                = var.dd_version
    FRONTEND_APP_PORT         = var.frontend_app_port
    PROJECT_NAME              = local.project_name
    S3_BUCKET                 = aws_s3_bucket.app_artifacts.id
    ENABLE_BANKING_DEMO       = var.enable_banking_demo ? "true" : "false"
    BANKING_UI_ARCHIVE_S3_KEY = var.enable_banking_demo ? aws_s3_object.banking_ui[0].key : ""
    ENABLE_RUM                = var.enable_rum && var.enable_banking_demo ? "true" : "false"
    RUM_APPLICATION_ID        = var.rum_application_id
    RUM_CLIENT_TOKEN          = var.rum_client_token
  })

  user_data_replace_on_change = true

  depends_on = [
    aws_s3_object.bootstrap_datadog_common_frontend,
    aws_s3_object.bootstrap_userdata_common,
    aws_s3_object.bootstrap_fetch,
    aws_s3_object.banking_ui,
    aws_vpc_endpoint.tenant_to_proxy,
  ]

  tags = merge(local.common_tags, {
    Name    = "${local.project_name}-frontend"
    Role    = "frontend"
    Project = local.project_name
  })
}
