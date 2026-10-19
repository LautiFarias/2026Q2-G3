## RDS PostgreSQL Multi-AZ: la base relacional de solicitudes, empresas,
## sedes y auditoría oficial. Multi-AZ es una réplica standby (failover),
## no se lee: la portería necesita el dato al instante en la primaria.

resource "aws_db_subnet_group" "main" {
  name       = "${local.name_prefix}-db-subnets"
  subnet_ids = module.network.data_subnet_ids

  tags = local.common_tags
}

resource "aws_db_parameter_group" "main" {
  name_prefix = "${local.name_prefix}-pg16-"
  family      = "postgres16"
  description = "Parameter group de AccesoSeguro"

  # Reemplazar sin cortar: RDS no deja modificar un parameter group en uso.
  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
}

resource "random_password" "db" {
  length  = 24
  special = false
}

resource "aws_db_instance" "main" {
  identifier     = "${local.name_prefix}-db"
  engine         = "postgres"
  engine_version = "16" # solo la major: RDS elige la menor vigente (16.4 ya no existe)
  instance_class = var.db_instance_class

  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true
  kms_key_id        = aws_kms_key.main.arn

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.main.name

  multi_az            = true
  publicly_accessible = false

  backup_retention_period = 7

  # Se destruye y recrea seguido en el lab: no tiene sentido pedir snapshot
  # final salvo en "prod".
  skip_final_snapshot = var.environment != "prod"
  final_snapshot_identifier = var.environment == "prod" ? (
    "${local.name_prefix}-final-${formatdate("YYYYMMDD-hhmm", timestamp())}"
  ) : null
  deletion_protection = var.environment == "prod"

  # timestamp() cambia en cada plan; no tiene sentido que eso dispare un
  # diff en un atributo que solo importa al momento del destroy.
  lifecycle {
    ignore_changes = [final_snapshot_identifier, engine_version]
  }

  tags = local.common_tags
}

# La clave de la base nunca va en el código: queda en Secrets Manager y
# ECS/Lambda la leen al arrancar.
resource "aws_secretsmanager_secret" "db" {
  name                    = "${local.name_prefix}-db-credenciales"
  kms_key_id              = aws_kms_key.main.arn
  recovery_window_in_days = 0 # se recrea seguido en el lab, no hace falta ventana de recuperación

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id

  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db.result
    host     = aws_db_instance.main.address
    port     = 5432
    dbname   = var.db_name
  })
}
