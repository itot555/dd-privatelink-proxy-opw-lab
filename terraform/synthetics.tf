resource "datadog_synthetics_private_location" "main" {
  name        = "${local.project_name}-private-location"
  description = "Terraform-managed Private Location for the ${local.project_name} sandbox (us-east-1)"

  tags = [
    "env:${var.dd_env}",
    "project:${local.project_name}",
    "team:${var.private_location_team}",
    "region:us-east-1",
  ]
}
