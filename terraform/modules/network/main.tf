## Red de AccesoSeguro: 3 capas (pública, aplicación, datos) x 2 zonas de disponibilidad.
## Direcciones por cidrsubnet(): publica-a/b = 10.0.1.0/24 y 10.0.2.0/24,
## app-a/b = 10.0.11.0/24 y 10.0.12.0/24, datos-a/b = 10.0.21.0/24 y 10.0.22.0/24.

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, { Name = "${var.name_prefix}-vpc" })
}

# Punto de entrada a internet: solo existe si hay capa pública (el ALB la necesita).
resource "aws_internet_gateway" "this" {
  count  = var.create_public_subnets ? 1 : 0
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, { Name = "${var.name_prefix}-igw" })
}

locals {
  # netnum_base define el segundo octeto lógico de cada capa dentro del /16.
  layers = {
    publica = { netnum_base = 1, public = true }
    app     = { netnum_base = 11, public = false }
    datos   = { netnum_base = 21, public = false }
  }

  # merge() junta los 3 mapas (uno por capa) en un solo mapa de subredes,
  # con clave "<capa>-<letra de zona>" (ej: "publica-a").
  subnets = merge([
    for layer_name, layer in local.layers : {
      for idx, az in var.azs :
      "${layer_name}-${substr(az, length(az) - 1, 1)}" => {
        layer  = layer_name
        az     = az
        cidr   = cidrsubnet(var.vpc_cidr, 8, layer.netnum_base + idx)
        public = layer.public
      }
    }
  ]...)

  data_subnet_keys = [for k, v in local.subnets : k if v.layer == "datos"]

  nacl_ingress_rules = [
    { rule_number = 100, protocol = "tcp", cidr_block = "10.0.11.0/24", from_port = 5432, to_port = 5432 },
    { rule_number = 110, protocol = "tcp", cidr_block = "10.0.12.0/24", from_port = 5432, to_port = 5432 },
    { rule_number = 120, protocol = "-1", cidr_block = "10.0.21.0/24", from_port = 0, to_port = 0 },
    { rule_number = 130, protocol = "-1", cidr_block = "10.0.22.0/24", from_port = 0, to_port = 0 },
  ]

  nacl_egress_rules = [
    { rule_number = 100, protocol = "tcp", cidr_block = "10.0.11.0/24", from_port = 1024, to_port = 65535 },
    { rule_number = 110, protocol = "tcp", cidr_block = "10.0.12.0/24", from_port = 1024, to_port = 65535 },
    { rule_number = 120, protocol = "-1", cidr_block = "10.0.21.0/24", from_port = 0, to_port = 0 },
    { rule_number = 130, protocol = "-1", cidr_block = "10.0.22.0/24", from_port = 0, to_port = 0 },
  ]
}

resource "aws_subnet" "this" {
  for_each = local.subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = each.value.public

  tags = merge(var.tags, { Name = "${var.name_prefix}-${each.key}" })
}

# Tabla pública: ruta local + 0.0.0.0/0 al Internet Gateway (solo si hay capa pública).
resource "aws_route_table" "public" {
  count  = var.create_public_subnets ? 1 : 0
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, { Name = "${var.name_prefix}-rt-publica" })
}

resource "aws_route" "public_internet" {
  count                  = var.create_public_subnets ? 1 : 0
  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id
}

# Tabla de aplicación: solo ruta local (el Gateway Endpoint de S3 se asocia desde storage/security).
resource "aws_route_table" "app" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, { Name = "${var.name_prefix}-rt-app" })
}

# Tabla de datos: solo ruta local. Nada en subredes privadas necesita salir a internet.
resource "aws_route_table" "datos" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, { Name = "${var.name_prefix}-rt-datos" })
}

resource "aws_route_table_association" "this" {
  for_each = local.subnets

  subnet_id = aws_subnet.this[each.key].id
  route_table_id = (
    each.value.layer == "publica" ? aws_route_table.public[0].id :
    each.value.layer == "app" ? aws_route_table.app.id :
    aws_route_table.datos.id
  )
}

# NACL en la capa de datos: segunda barrera, stateless, solo deja pasar a la base.
resource "aws_network_acl" "datos" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = [for k in local.data_subnet_keys : aws_subnet.this[k].id]

  dynamic "ingress" {
    for_each = local.nacl_ingress_rules
    content {
      rule_no    = ingress.value.rule_number
      protocol   = ingress.value.protocol
      action     = "allow"
      cidr_block = ingress.value.cidr_block
      from_port  = ingress.value.from_port
      to_port    = ingress.value.to_port
    }
  }

  dynamic "egress" {
    for_each = local.nacl_egress_rules
    content {
      rule_no    = egress.value.rule_number
      protocol   = egress.value.protocol
      action     = "allow"
      cidr_block = egress.value.cidr_block
      from_port  = egress.value.from_port
      to_port    = egress.value.to_port
    }
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-nacl-datos" })
}
