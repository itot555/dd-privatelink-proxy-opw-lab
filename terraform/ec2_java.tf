# EC2 — Java（SSI、Synthetics Private Location Worker、bastion。Tenant Public Subnet）

resource "aws_instance" "java" {
  provider                    = aws.us_east_1
  ami                         = data.aws_ami.ubuntu_us_east_1.id
  instance_type               = var.application_instance_type
  subnet_id                   = module.vpc_tenant.public_subnets[0]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.ec2.key_name
  iam_instance_profile        = aws_iam_instance_profile.ec2.name

  vpc_security_group_ids = [aws_security_group.java.id]

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.application_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/scripts/java_userdata.sh", {
    COMMON_PUBLIC_KEY            = tls_private_key.ec2.public_key_openssh
    APP_SERVICE                  = local.application_services.java
    APP_VERSION                  = var.dd_version
    AWS_REGION                   = "us-east-1"
    BASTION_SSH_SECRET_ARN       = aws_secretsmanager_secret.bastion_ssh_private_key.arn
    BOOTSTRAP_PREFIX             = local.bootstrap_prefix
    BOOTSTRAP_REVISION           = local.bootstrap_revision
    DATADOG_COMMON_CONFIG_KEY    = aws_s3_object.bootstrap_datadog_common_java.key
    DATABASE_SECRET_ARN          = aws_secretsmanager_secret.database.arn
    DD_API_KEY_SECRET_ARN        = aws_secretsmanager_secret.dd_api_key.arn
    DD_ENV                       = var.dd_env
    DD_SITE                      = var.dd_site
    DD_HOSTNAME                  = local.dd_hostname_java
    ENABLE_JAVA_SSI              = var.enable_java_ssi ? "true" : "false"
    JAVA_APP_PORT                = var.java_app_port
    PRIVATE_LOCATION_CONCURRENCY = var.private_location_concurrency
    PRIVATE_LOCATION_IMAGE       = var.private_location_image
    PRIVATE_LOCATION_SECRET_ARN  = aws_secretsmanager_secret.private_location_config.arn
    PROJECT_NAME                 = local.project_name
    PROXY_ENDPOINT_DNS           = local.tenant_datadog_proxy_dns
    PROXY_PORT                   = var.proxy_port
    PYTHON_APP_PORT              = var.python_app_port
    S3_BUCKET                    = aws_s3_bucket.app_artifacts.id
    APP_ARCHIVE_S3_KEY           = aws_s3_object.java_app.key
    SSI_LIBRARIES                = var.java_ssi_libraries
    ENABLE_BANKING_DEMO          = var.enable_banking_demo ? "true" : "false"
    DEMO_BANK_PASSWORD           = var.demo_bank_password
  })

  user_data_replace_on_change = true

  depends_on = [
    aws_lb_listener.opw_logs,
    aws_lb_listener.proxy_squid,
    aws_s3_object.bootstrap_datadog_common_java,
    aws_s3_object.bootstrap_userdata_common,
    aws_s3_object.java_app,
    aws_secretsmanager_secret_version.bastion_ssh_private_key,
    aws_secretsmanager_secret_version.database,
    aws_secretsmanager_secret_version.private_location_config,
    aws_vpc_endpoint.tenant_to_proxy,
  ]

  tags = merge(local.common_tags, {
    Name    = "${local.project_name}-java"
    Role    = "java"
    Project = local.project_name
  })
}
