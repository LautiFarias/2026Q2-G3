## Arquitectura desacoplada: la API publica un evento y sigue; otras piezas
## reaccionan por su cuenta. SNS reparte (push) a varias colas SQS, que
## amortiguan picos y reintentan sin perder nada.

resource "aws_sns_topic" "eventos_solicitud" {
  name              = "${local.name_prefix}-eventos-solicitud"
  kms_master_key_id = aws_kms_key.main.id

  tags = local.common_tags
}

locals {
  # Qué cola dispara qué Lambda cuando le llega un mensaje.
  queue_lambda_map = {
    cola-documentos     = "validar-documento"
    cola-auditoria      = "archivar-auditoria"
    cola-notificaciones = "notificar-mail"
  }

  # cola-documentos NO se suscribe a SNS: le llega directo de S3.
  sns_subscribed_queues = toset(["cola-auditoria", "cola-notificaciones"])
}

module "sqs" {
  source   = "../modules/sqs-with-dlq"
  for_each = local.colas

  name          = "${local.name_prefix}-${each.key}"
  alarm_actions = [aws_sns_topic.alarmas.arn]
  tags          = local.common_tags
}

resource "aws_sns_topic_subscription" "to_sqs" {
  for_each = local.sns_subscribed_queues

  topic_arn = aws_sns_topic.eventos_solicitud.arn
  protocol  = "sqs"
  endpoint  = module.sqs[each.key].queue_arn
}

# Cada cola solo acepta mensajes de quien corresponde: el tópico SNS, o (para
# cola-documentos) el bucket de documentos. Nada más puede escribirles.
resource "aws_sqs_queue_policy" "sns_to_sqs" {
  for_each  = local.sns_subscribed_queues
  queue_url = module.sqs[each.key].queue_url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "${title(replace(each.key, "-", " "))}DesdeSNS"
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = module.sqs[each.key].queue_arn
      Condition = { ArnEquals = { "aws:SourceArn" = aws_sns_topic.eventos_solicitud.arn } }
    }]
  })

  depends_on = [aws_sns_topic_subscription.to_sqs]
}

resource "aws_sqs_queue_policy" "s3_to_cola_documentos" {
  queue_url = module.sqs["cola-documentos"].queue_url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "ColaDocumentosDesdeS3"
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = module.sqs["cola-documentos"].queue_arn
      Condition = { ArnEquals = { "aws:SourceArn" = module.buckets["documentos"].bucket_arn } }
    }]
  })
}

# Cada archivo nuevo en el bucket de documentos deja un aviso en la cola
# (la notificación necesita que la policy de la cola ya exista).
resource "aws_s3_bucket_notification" "documentos" {
  bucket = module.buckets["documentos"].bucket_id

  queue {
    queue_arn = module.sqs["cola-documentos"].queue_arn
    events    = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_sqs_queue_policy.s3_to_cola_documentos]
}

resource "aws_lambda_event_source_mapping" "sqs_to_lambda" {
  for_each = local.queue_lambda_map

  event_source_arn = module.sqs[each.key].queue_arn
  function_name    = module.lambdas[each.value].arn
  batch_size       = 5
}

## Evento programado (EventBridge): despierta a vencer-permisos cada 15 min,
## reemplaza lo que hoy se corre a mano.

resource "aws_cloudwatch_event_rule" "vencer_permisos" {
  name                = "${local.name_prefix}-vencer-permisos-15min"
  description         = "Dispara la Lambda vencer-permisos cada 15 minutos"
  schedule_expression = "rate(15 minutes)"

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "vencer_permisos" {
  rule      = aws_cloudwatch_event_rule.vencer_permisos.name
  target_id = "vencer-permisos"
  arn       = module.lambdas["vencer-permisos"].arn
}

resource "aws_lambda_permission" "eventbridge_invoke" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.lambdas["vencer-permisos"].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.vencer_permisos.arn
}

## SES: el cartero de los mails de aviso. En sandbox, solo manda a
## direcciones verificadas (remitente + destinatarios de prueba).

resource "aws_ses_email_identity" "verificados" {
  for_each = toset(local.ses_emails)
  email    = each.value
}
