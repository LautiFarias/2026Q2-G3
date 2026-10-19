output "vpc_id" {
  value = aws_vpc.main.id
}

output "vpc_cidr" {
  value = aws_vpc.main.cidr_block
}

output "subnet_ids" {
  description = "Mapa completo <capa>-<zona> => subnet id."
  value       = { for k, v in aws_subnet.this : k => v.id }
}

output "public_subnet_ids" {
  value = [for k, v in local.subnets : aws_subnet.this[k].id if v.public]
}

output "app_subnet_ids" {
  value = [for k, v in local.subnets : aws_subnet.this[k].id if v.layer == "app"]
}

output "data_subnet_ids" {
  value = [for k, v in local.subnets : aws_subnet.this[k].id if v.layer == "datos"]
}

output "app_route_table_id" {
  value = aws_route_table.app.id
}

output "datos_route_table_id" {
  value = aws_route_table.datos.id
}

output "public_route_table_id" {
  value = var.create_public_subnets ? aws_route_table.public[0].id : null
}
