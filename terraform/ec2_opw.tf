# EC2 — OPW（Proxy VPC Private Subnet）

resource "aws_instance" "opw" {
  for_each = local.opw_subnet_map

  provider                    = aws.us_east_1
  ami                         = data.aws_ami.ubuntu_us_east_1.id
  instance_type               = var.opw_instance_type
  subnet_id                   = each.value
  associate_public_ip_address = false
  key_name                    = aws_key_pair.ec2.key_name
  iam_instance_profile        = aws_iam_instance_profile.ec2.name

  vpc_security_group_ids = [aws_security_group.opw.id]

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.opw_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/scripts/opw_userdata.sh", {
    COMMON_PUBLIC_KEY         = tls_private_key.ec2.public_key_openssh
    AWS_REGION                = "us-east-1"
    BOOTSTRAP_PREFIX          = local.bootstrap_prefix
    BOOTSTRAP_REVISION        = local.bootstrap_revision
    DATADOG_COMMON_CONFIG_KEY = aws_s3_object.bootstrap_datadog_common_opw[each.key].key
    DD_API_KEY_SECRET_ARN     = aws_secretsmanager_secret.dd_api_key.arn
    DD_HOSTNAME               = local.dd_hostname_opw[each.key]
    DD_OP_PIPELINE_ID         = var.opw_pipeline_id
    DD_OP_TRACES_PIPELINE_ID  = var.opw_pipeline_id_traces
    DD_SITE                   = var.dd_site
    OPW_LOGS_PORT             = var.opw_logs_port
    OPW_TRACES_PORT           = var.opw_traces_port
    S3_BUCKET                 = aws_s3_bucket.app_artifacts.id
  })

  user_data_replace_on_change = true

  depends_on = [
    aws_s3_object.bootstrap_datadog_common_opw,
    aws_s3_object.bootstrap_userdata_common,
    aws_s3_object.bootstrap_fetch,
    aws_vpc_endpoint.datadog_us_east_1,
    aws_lb_target_group.opw_logs,
    aws_lb_target_group.opw_traces,
  ]

  # OPW 再作成時は aws_lb_target_group_attachment.opw_* も同一 apply に含めること。
  # -target=aws_instance.opw のみだと NLB ターゲットが空になり Tenant から :8282/:8484 が不通になる。

  tags = merge(local.common_tags, {
    Name    = "${local.project_name}-opw-${each.key}"
    Role    = "opw"
    Project = local.project_name
  })
}
