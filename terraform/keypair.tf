resource "tls_private_key" "ec2" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_sensitive_file" "private_key" {
  content         = tls_private_key.ec2.private_key_pem
  filename        = "${path.module}/keys/${local.project_name}-ssh-key"
  file_permission = "0600"

  provisioner "local-exec" {
    command = "mkdir -p ${path.module}/keys"
  }

  depends_on = [tls_private_key.ec2]
}

resource "local_file" "public_key" {
  content         = tls_private_key.ec2.public_key_openssh
  filename        = "${path.module}/keys/${local.project_name}-ssh-key.pub"
  file_permission = "0644"

  depends_on = [tls_private_key.ec2]
}

resource "aws_key_pair" "ec2" {
  provider   = aws.us_east_1
  key_name   = "${local.project_name}-use1-keypair"
  public_key = tls_private_key.ec2.public_key_openssh

  tags = merge(local.common_tags, { Name = "${local.project_name}-use1-keypair" })
}
