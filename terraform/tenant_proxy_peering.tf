# Tenant ↔ Proxy VPC Peering — テレメトリは PrivateLink、SSH は Java bastion 経由
# Tenant Java（Public）→ ProxyJump → Proxy VPC 内 Squid/OPW へ到達する。
#
# route_table_ids は apply 前に ID が未定のため for_each 不可 → count + index を使用。

resource "aws_vpc_peering_connection" "tenant_proxy" {
  provider = aws.us_east_1

  vpc_id      = module.vpc_tenant.vpc_id
  peer_vpc_id = module.vpc_proxy.vpc_id
  auto_accept = true

  tags = merge(local.common_tags, { Name = "${local.project_name}-tenant-proxy-peering" })
}

resource "aws_route" "tenant_private_to_proxy" {
  count = length(module.vpc_tenant.private_route_table_ids)

  provider = aws.us_east_1

  route_table_id            = module.vpc_tenant.private_route_table_ids[count.index]
  destination_cidr_block    = module.vpc_proxy.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.tenant_proxy.id
}

resource "aws_route" "tenant_public_to_proxy" {
  count = length(module.vpc_tenant.public_route_table_ids)

  provider = aws.us_east_1

  route_table_id            = module.vpc_tenant.public_route_table_ids[count.index]
  destination_cidr_block    = module.vpc_proxy.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.tenant_proxy.id
}

resource "aws_route" "proxy_private_to_tenant" {
  count = length(module.vpc_proxy.private_route_table_ids)

  provider = aws.us_east_1

  route_table_id            = module.vpc_proxy.private_route_table_ids[count.index]
  destination_cidr_block    = module.vpc_tenant.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.tenant_proxy.id
}

resource "aws_route" "proxy_public_to_tenant" {
  count = length(module.vpc_proxy.public_route_table_ids)

  provider = aws.us_east_1

  route_table_id            = module.vpc_proxy.public_route_table_ids[count.index]
  destination_cidr_block    = module.vpc_tenant.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.tenant_proxy.id
}
