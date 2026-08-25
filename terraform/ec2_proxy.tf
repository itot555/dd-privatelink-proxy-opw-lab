# EC2 — Squid Proxy（Proxy VPC Private Subnet）

resource "aws_instance" "proxy" {
  for_each = local.proxy_subnet_map

  provider                    = aws.us_east_1
  ami                         = data.aws_ami.ubuntu_us_east_1.id
  instance_type               = var.proxy_instance_type
  subnet_id                   = each.value
  associate_public_ip_address = false
  key_name                    = aws_key_pair.ec2.key_name
  iam_instance_profile        = aws_iam_instance_profile.ec2.name

  vpc_security_group_ids = [aws_security_group.proxy.id]

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.proxy_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/scripts/proxy_userdata.sh", {
    COMMON_PUBLIC_KEY         = tls_private_key.ec2.public_key_openssh
    AWS_REGION                = "us-east-1"
    BOOTSTRAP_PREFIX          = local.bootstrap_prefix
    BOOTSTRAP_REVISION        = local.bootstrap_revision
    DATADOG_COMMON_CONFIG_KEY = aws_s3_object.bootstrap_datadog_common_proxy[each.key].key
    DD_API_KEY_SECRET_ARN     = aws_secretsmanager_secret.dd_api_key.arn
    DD_HOSTNAME               = local.dd_hostname_squid[each.key]
    DD_SITE                   = var.dd_site
    PROXY_PORT                = var.proxy_port
    S3_BUCKET                 = aws_s3_bucket.app_artifacts.id
  })

  user_data_replace_on_change = true

  depends_on = [
    aws_s3_object.bootstrap_datadog_common_proxy,
    aws_s3_object.bootstrap_userdata_common,
    aws_s3_object.bootstrap_fetch,
    aws_vpc_endpoint.datadog_us_east_1,
  ]

  tags = merge(local.common_tags, {
    Name    = "${local.project_name}-proxy-${each.key}"
    Role    = "proxy"
    Project = local.project_name
  })
}
