## Security Groups encadenados: cada pieza solo acepta tráfico de la que
## está justo antes. Un Security Group bloquea todo lo que no está permitido
## explícitamente, así que no hace falta "denegar" nada a mano.

# Único Security Group armado con un módulo externo del registro público.
module "sg_alb" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.3"

  name        = "${local.name_prefix}-alb"
  description = "ALB publico: unica puerta de entrada, solo HTTP desde internet"
  vpc_id      = module.network.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp"]
  egress_rules        = ["all-all"]

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-sg-alb" })
}

resource "aws_security_group" "ecs" {
  name_prefix = "${local.name_prefix}-ecs-"
  description = "Tasks de ECS: puerto 5000 solo desde el ALB"
  vpc_id      = module.network.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-sg-ecs" })
}

resource "aws_security_group_rule" "ecs_from_alb" {
  type                     = "ingress"
  from_port                = 5000
  to_port                  = 5000
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ecs.id
  source_security_group_id = module.sg_alb.security_group_id
  description              = "Desde el ALB"
}

resource "aws_security_group" "lambda" {
  name_prefix = "${local.name_prefix}-lambda-"
  description = "Lambdas en la VPC: nada entrante, solo sale hacia RDS y los endpoints"
  vpc_id      = module.network.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-sg-lambda" })
}

resource "aws_security_group" "rds" {
  name_prefix = "${local.name_prefix}-rds-"
  description = "RDS: 5432 solo desde ECS y las Lambdas"
  vpc_id      = module.network.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-sg-rds" })
}

resource "aws_security_group_rule" "rds_from_ecs" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = aws_security_group.ecs.id
}

resource "aws_security_group_rule" "rds_from_lambda" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = aws_security_group.lambda.id
}

resource "aws_security_group" "endpoints" {
  name_prefix = "${local.name_prefix}-endpoints-"
  description = "Interface endpoints: 443 desde ECS y las Lambdas"
  vpc_id      = module.network.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-sg-endpoints" })
}

resource "aws_security_group_rule" "endpoints_from_ecs" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.endpoints.id
  source_security_group_id = aws_security_group.ecs.id
}

resource "aws_security_group_rule" "endpoints_from_lambda" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.endpoints.id
  source_security_group_id = aws_security_group.lambda.id
}

## VPC Endpoints: como ECS y las Lambdas no tienen salida a internet, llegan
## a los servicios de AWS por túneles privados dentro de la región.

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.network.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [module.network.app_route_table_id, module.network.datos_route_table_id]

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-vpce-s3" })
}

locals {
  interface_endpoints = toset(["ecr.api", "ecr.dkr", "logs", "secretsmanager", "sns", "lambda"])
}

resource "aws_vpc_endpoint" "interfaces" {
  for_each = local.interface_endpoints

  vpc_id              = module.network.vpc_id
  service_name        = "com.amazonaws.${var.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.network.app_subnet_ids
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-vpce-${replace(each.key, ".", "-")}" })
}

## Caja fuerte: una clave KMS para la base, los buckets y Secrets Manager.

resource "aws_kms_key" "main" {
  description             = "Clave de AccesoSeguro (RDS, S3, Secrets Manager)"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = local.common_tags
}

resource "aws_kms_alias" "main" {
  name          = "alias/${local.name_prefix}"
  target_key_id = aws_kms_key.main.key_id
}

## CloudTrail: el historial de 90 días de la cuenta existe siempre; esto es
## el trail propio, opcional (se prende con enable_cloudtrail).

module "cloudtrail_bucket" {
  source = "../modules/s3-bucket"
  count  = var.enable_cloudtrail ? 1 : 0

  bucket_name = "${local.name_prefix}-cloudtrail-${data.aws_caller_identity.current.account_id}"
  versioning  = false

  extra_policy_statements = [
    {
      Sid       = "AWSCloudTrailAclCheck"
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action    = "s3:GetBucketAcl"
      Resource  = "arn:aws:s3:::${local.name_prefix}-cloudtrail-${data.aws_caller_identity.current.account_id}"
    },
    {
      Sid       = "AWSCloudTrailWrite"
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action    = "s3:PutObject"
      Resource  = "arn:aws:s3:::${local.name_prefix}-cloudtrail-${data.aws_caller_identity.current.account_id}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
      Condition = { StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" } }
    },
  ]

  tags = local.common_tags
}

resource "aws_cloudtrail" "main" {
  count                         = var.enable_cloudtrail ? 1 : 0
  name                          = "${local.name_prefix}-trail"
  s3_bucket_name                = module.cloudtrail_bucket[0].bucket_id
  include_global_service_events = true
  is_multi_region_trail         = false

  depends_on = [module.cloudtrail_bucket]

  tags = local.common_tags
}
