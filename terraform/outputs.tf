output "project_name" {
  description = "AWS resource name prefix actually used (pl- plus 3 random letters unless overridden)"
  value       = local.project_name
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name（HTTPS viewer）"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "alb_dns_name" {
  description = "Internet-facing Application Load Balancer DNS name"
  value       = aws_lb.public.dns_name
}

output "application_urls" {
  description = "Demo application URLs via CloudFront and ALB"
  value = {
    cloudfront = "https://${aws_cloudfront_distribution.main.domain_name}/"
    java_hello = "https://${aws_cloudfront_distribution.main.domain_name}/hello"
    java_api   = "https://${aws_cloudfront_distribution.main.domain_name}/api/items"
    alb        = "http://${aws_lb.public.dns_name}/"
  }
}

output "java_instance_id" {
  description = "Java EC2 instance ID"
  value       = aws_instance.java.id
}

output "dd_hostnames" {
  description = "Datadog Agent / OS hostname（{dd_env}-{role}-{index} 形式）"
  value       = local.dd_hostnames
}

output "java_public_ip" {
  description = "Java EC2 public IP address"
  value       = aws_instance.java.public_ip
}

output "python_instance_id" {
  description = "Python EC2 instance ID"
  value       = aws_instance.python.id
}

output "python_private_ip" {
  description = "Python EC2 private IP address"
  value       = aws_instance.python.private_ip
}

output "frontend_instance_id" {
  description = "Frontend EC2 instance ID"
  value       = aws_instance.frontend.id
}

output "database_endpoint" {
  description = "RDS PostgreSQL endpoint used by the application and DBM Agent"
  value       = aws_db_instance.main.endpoint
}

output "database_secret_arn" {
  description = "Secrets Manager ARN containing generated PostgreSQL credentials"
  value       = aws_secretsmanager_secret.database.arn
}

output "dd_api_key_secret_arn" {
  description = "Secrets Manager ARN containing the Datadog API Key"
  value       = aws_secretsmanager_secret.dd_api_key.arn
}

output "deployment_summary" {
  description = "High-level summary of the deployed Sandbox"
  value       = <<-EOT
    ${local.project_name} (us-east-1) — Tenant / Proxy 二層 VPC
    ========================================================
    Tenant VPC                  : ${module.vpc_tenant.vpc_id} (${var.vpc_cidr_us_east_1})
    Proxy VPC                   : ${module.vpc_proxy.vpc_id} (${var.vpc_cidr_proxy_us_east_1})
    Java EC2 + Private Location : ${aws_instance.java.id}
    Python EC2 + DBM Agent      : ${aws_instance.python.id}
    Frontend EC2 (nginx)        : ${aws_instance.frontend.id}
    Squid Proxy (${var.proxy_instance_count})           : ${join(", ", [for instance in values(aws_instance.proxy) : instance.id])}
    OPW + Agent (${var.opw_instance_count})             : ${join(", ", [for instance in values(aws_instance.opw) : instance.id])}
    Proxy NLB (Proxy VPC)       : ${aws_lb.proxy.dns_name}
    Tenant→Proxy EP DNS         : ${local.tenant_datadog_proxy_dns}
    Tenant Agent proxy URL      : http://${local.tenant_datadog_proxy_dns}:${var.proxy_port}
    OPW Logs (Tenant)           : http://${local.tenant_datadog_proxy_dns}:${var.opw_logs_port}
    Internet ALB                : ${aws_lb.public.dns_name}
    CloudFront                  : ${aws_cloudfront_distribution.main.domain_name}
    RDS PostgreSQL              : ${aws_db_instance.main.endpoint}
    Synthetics Private Location : ${datadog_synthetics_private_location.main.id}

    確認手順: terraform output verification_steps
  EOT
}

output "proxy_nlb_dns_name" {
  description = "Proxy VPC Internal NLB DNS name"
  value       = aws_lb.proxy.dns_name
}

output "tenant_proxy_endpoint_dns" {
  description = "Tenant Interface VPC Endpoint DNS（Agent/DDOT の proxy / OP URL に使用）"
  value       = local.tenant_datadog_proxy_dns
}

output "nlb_dns_name" {
  description = "Deprecated: proxy_nlb_dns_name を使用してください"
  value       = aws_lb.proxy.dns_name
}

output "opw_instance_ids" {
  description = "Observability Pipelines Worker EC2 instance IDs"
  value       = { for key, instance in aws_instance.opw : key => instance.id }
}

output "private_location_config_secret_arn" {
  description = "Secrets Manager ARN containing the generated Private Location Worker config"
  value       = aws_secretsmanager_secret.private_location_config.arn
}

output "private_location_id" {
  description = "Terraform-managed Datadog Synthetics Private Location ID"
  value       = datadog_synthetics_private_location.main.id
}

output "synthetics_test_public_ids" {
  description = "Terraform 管理 Synthetics テスト ID（enable_synthetics_e2e_tests=true 時）"
  value = var.enable_synthetics_e2e_tests ? {
    pl_cloudfront_hello  = datadog_synthetics_test.pl_cloudfront_hello[0].id
    pl_distributed_trace = datadog_synthetics_test.pl_distributed_trace[0].id
  } : {}
}

output "proxy_instance_ids" {
  description = "Squid Proxy EC2 instance IDs"
  value       = { for key, instance in aws_instance.proxy : key => instance.id }
}

output "s3_bucket_name" {
  description = "S3 bucket name for application artifacts"
  value       = aws_s3_bucket.app_artifacts.id
}

output "proxy_private_ips" {
  description = "Proxy VPC Squid EC2 private IPs（Java bastion から ProxyJump）"
  value       = { for key, instance in aws_instance.proxy : key => instance.private_ip }
}

output "opw_private_ips" {
  description = "Proxy VPC OPW EC2 private IPs（Java bastion から ProxyJump）"
  value       = { for key, instance in aws_instance.opw : key => instance.private_ip }
}

output "ssh_private_key_path" {
  description = "Local path to the generated diagnostic SSH private key"
  value       = local_sensitive_file.private_key.filename
}

output "frontend_public_ip" {
  description = "Frontend EC2 public IP address"
  value       = aws_instance.frontend.public_ip
}

output "ssh_access_guide_legacy" {
  description = "Deprecated: ssh_access_guide を使用してください"
  value       = "terraform output ssh_access_guide"
}

output "verification_guide" {
  description = "Deprecated: verification_steps / step1_troubleshoot_bootstrap を使用してください"
  value       = "terraform output verification_steps"
}

output "destroy_guide" {
  description = "Sandbox 削除手順"
  value       = <<-EOT
    cd terraform
    terraform destroy

    destroy 容易化（default）:
      - S3 force_destroy         : ${var.enable_force_destroy}
      - RDS skip_final_snapshot  : true
      - Secrets recovery_window  : 0 日
  EOT
}

output "tenant_vpc_id" {
  description = "Tenant VPC ID"
  value       = module.vpc_tenant.vpc_id
}

output "proxy_vpc_id" {
  description = "Proxy VPC ID"
  value       = module.vpc_proxy.vpc_id
}

output "vpc_id" {
  description = "Deprecated: tenant_vpc_id を使用してください"
  value       = module.vpc_tenant.vpc_id
}

output "destroy_guide_legacy" {
  description = "Deprecated: destroy_guide を使用してください"
  value       = "terraform output destroy_guide"
}

output "proxy_opw_scaling" {
  description = "Squid / OPW のデプロイ台数"
  value = {
    proxy_instance_count = var.proxy_instance_count
    opw_instance_count   = var.opw_instance_count
  }
}

output "ap_northeast_1_network" {
  description = "ap-northeast-1 ネットワーク基盤の状態（Interface VPC Endpoint は AZ ごとに時間課金あり）"
  value = {
    network_enabled  = var.enable_ap_northeast_1_network
    compute_enabled  = var.enable_ap_northeast_1_compute
    vpc_id           = var.enable_ap_northeast_1_network ? module.vpc_ap_northeast_1[0].vpc_id : null
    privatelink_keys = var.enable_ap_northeast_1_network ? sort(keys(var.dd_privatelink_services)) : []
    endpoint_count   = var.enable_ap_northeast_1_network ? length(var.dd_privatelink_services) * length(module.vpc_ap_northeast_1[0].private_subnets) : 0
  }
}
