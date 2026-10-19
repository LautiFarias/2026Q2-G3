locals {
  name_prefix = "${var.project}-${var.environment}"

  common_tags = merge(var.tags, {
    Proyecto       = var.project
    Ambiente       = var.environment
    Gestionado-por = "terraform"
  })

  # slice(): nos quedamos con las primeras 2 zonas de disponibilidad disponibles.
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  lambda_vpc_config = {
    subnet_ids         = module.network.app_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  # Definición de las 5 Lambdas: si corren en la VPC (necesitan RDS) y sus
  # variables de entorno propias.
  lambdas = {
    generar-reporte = {
      in_vpc = true
      environment = {
        DB_HOST          = aws_db_instance.main.address
        DB_NAME          = var.db_name
        DB_SECRET_ARN    = aws_secretsmanager_secret.db.arn
        AUDITORIA_BUCKET = module.buckets["auditoria"].bucket_id
      }
    }
    validar-documento = {
      in_vpc = true
      environment = {
        DB_HOST               = aws_db_instance.main.address
        DB_NAME               = var.db_name
        DB_SECRET_ARN         = aws_secretsmanager_secret.db.arn
        DOCUMENTO_MAX_SIZE_MB = tostring(var.documento_max_size_mb)
      }
    }
    vencer-permisos = {
      in_vpc = true
      environment = {
        DB_HOST               = aws_db_instance.main.address
        DB_NAME               = var.db_name
        DB_SECRET_ARN         = aws_secretsmanager_secret.db.arn
        SNS_EVENTOS_TOPIC_ARN = aws_sns_topic.eventos_solicitud.arn
      }
    }
    archivar-auditoria = {
      in_vpc = false
      environment = {
        AUDITORIA_BUCKET = module.buckets["auditoria"].bucket_id
      }
    }
    auth-login = {
      in_vpc = false
      environment = {
        COGNITO_CLIENT_ID   = aws_cognito_user_pool_client.app.id
        CORS_ALLOWED_ORIGIN = var.cors_allowed_origin
      }
    }
    notificar-mail = {
      in_vpc = false
      environment = {
        SES_SENDER = try(local.ses_emails[0], "")
      }
    }
  }

  # toset() para for_each; compact() saca mails vacíos de la lista.
  colas      = toset(["cola-documentos", "cola-auditoria", "cola-notificaciones"])
  ses_emails = compact(concat(var.ses_verified_emails, [var.alarm_email]))

  # Variables de entorno de la API en ECS: keys()+sort() para un orden estable
  # en el formato name/value que pide la task definition.
  api_environment_map = {
    APP_ENV               = var.environment
    PORT                  = "5000"
    CORS_ALLOWED_ORIGIN   = var.cors_allowed_origin
    DB_HOST               = aws_db_instance.main.address
    DB_NAME               = var.db_name
    DB_SECRET_ARN         = aws_secretsmanager_secret.db.arn
    COGNITO_USER_POOL_ID  = aws_cognito_user_pool.main.id
    COGNITO_APP_CLIENT_ID = aws_cognito_user_pool_client.app.id
    COGNITO_REGION        = var.region
    DOCUMENTOS_BUCKET     = module.buckets["documentos"].bucket_id
    AUDITORIA_BUCKET      = module.buckets["auditoria"].bucket_id
    SNS_EVENTOS_TOPIC_ARN = aws_sns_topic.eventos_solicitud.arn
    LAMBDA_REPORTES_NAME  = module.lambdas["generar-reporte"].function_name
  }

  api_environment = [
    for k in sort(keys(local.api_environment_map)) : {
      name  = k
      value = tostring(local.api_environment_map[k])
    }
  ]
}
