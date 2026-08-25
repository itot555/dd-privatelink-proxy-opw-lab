resource "aws_iam_role" "ec2" {
  provider = aws.us_east_1
  name     = "${local.project_name}-use1-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = merge(local.common_tags, { Name = "${local.project_name}-use1-ec2-role" })
}

resource "aws_iam_policy" "ec2" {
  provider    = aws.us_east_1
  name        = "${local.project_name}-use1-ec2-policy"
  description = "EC2向けSecrets Manager / S3 / Describe権限"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadSecrets"
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = [
          aws_secretsmanager_secret.dd_api_key.arn,
          aws_secretsmanager_secret.database.arn,
          aws_secretsmanager_secret.private_location_config.arn,
          aws_secretsmanager_secret.synthetics_pl_config.arn,
          aws_secretsmanager_secret.bastion_ssh_private_key.arn,
        ]
      },
      {
        Sid    = "ReadApplicationArchives"
        Effect = "Allow"
        Action = ["s3:GetObject"]
        Resource = [
          "${aws_s3_bucket.app_artifacts.arn}/${local.project_name}/apps/*",
          "${aws_s3_bucket.app_artifacts.arn}/${local.project_name}/bootstrap/*",
        ]
      },
      {
        Sid    = "DescribeInfrastructure"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "rds:DescribeDBInstances",
        ]
        Resource = ["*"]
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2" {
  provider   = aws.us_east_1
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.ec2.arn
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  provider   = aws.us_east_1
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  provider = aws.us_east_1
  name     = "${local.project_name}-use1-ec2-profile"
  role     = aws_iam_role.ec2.name

  tags = merge(local.common_tags, { Name = "${local.project_name}-use1-ec2-profile" })
}
