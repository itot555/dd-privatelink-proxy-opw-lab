data "archive_file" "java_app" {
  type        = "zip"
  source_dir  = "${path.module}/../apps/java-app"
  output_path = "${path.module}/java-app.zip"

  excludes = [
    "target",
  ]
}

data "archive_file" "python_app" {
  type        = "zip"
  source_dir  = "${path.module}/../apps/python-app"
  output_path = "${path.module}/python-app.zip"

  excludes = [
    ".venv",
    "__pycache__",
  ]
}

resource "aws_s3_object" "java_app" {
  provider = aws.us_east_1
  bucket   = aws_s3_bucket.app_artifacts.id
  key      = "${local.project_name}/apps/java-app-${data.archive_file.java_app.output_md5}.zip"
  source   = data.archive_file.java_app.output_path
  etag     = data.archive_file.java_app.output_md5
}

resource "aws_s3_object" "python_app" {
  provider = aws.us_east_1
  bucket   = aws_s3_bucket.app_artifacts.id
  key      = "${local.project_name}/apps/python-app-${data.archive_file.python_app.output_md5}.zip"
  source   = data.archive_file.python_app.output_path
  etag     = data.archive_file.python_app.output_md5
}

data "archive_file" "banking_ui" {
  count = var.enable_banking_demo ? 1 : 0

  type        = "zip"
  source_dir  = "${path.module}/../apps/banking-ui"
  output_path = "${path.module}/banking-ui.zip"

  excludes = [
    "node_modules",
    "dist",
    "preview",
  ]
}

resource "aws_s3_object" "banking_ui" {
  count = var.enable_banking_demo ? 1 : 0

  provider = aws.us_east_1
  bucket   = aws_s3_bucket.app_artifacts.id
  key      = "${local.project_name}/apps/banking-ui-${data.archive_file.banking_ui[0].output_md5}.zip"
  source   = data.archive_file.banking_ui[0].output_path
  etag     = data.archive_file.banking_ui[0].output_md5
}
