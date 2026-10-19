# Módulo `sqs-with-dlq`

Cola Standard con su Dead Letter Queue y una alarma de CloudWatch que avisa
si llega algo a la DLQ (después de `max_receive_count` reintentos fallidos).

## Uso

```hcl
module "sqs" {
  source   = "../modules/sqs-with-dlq"
  for_each = local.colas

  name          = "${local.name_prefix}-${each.key}"
  alarm_actions = [aws_sns_topic.alarmas.arn]
  tags          = local.common_tags
}
```
