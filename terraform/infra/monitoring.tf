## Métricas, logs y alarmas. Todo lo que puede fallar en silencio (una DLQ
## con mensajes, una Lambda con errores, RDS al límite) avisa por acá.

resource "aws_sns_topic" "alarmas" {
  name = "${local.name_prefix}-alarmas"

  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "alarmas_email" {
  count = var.alarm_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.alarmas.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${local.name_prefix}-alb-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  alarm_actions = [aws_sns_topic.alarmas.arn]
  tags          = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "ecs_tasks_sanas" {
  alarm_name          = "${local.name_prefix}-ecs-tasks-sanas"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Minimum"
  threshold           = var.ecs_min_tasks
  treat_missing_data  = "breaching"

  dimensions = {
    TargetGroup  = aws_lb_target_group.api.arn_suffix
    LoadBalancer = aws_lb.main.arn_suffix
  }

  alarm_actions = [aws_sns_topic.alarmas.arn]
  tags          = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${local.name_prefix}-rds-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  alarm_actions = [aws_sns_topic.alarmas.arn]
  tags          = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_errores" {
  for_each = local.lambdas

  alarm_name          = "${local.name_prefix}-${each.key}-errores"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = module.lambdas[each.key].function_name
  }

  alarm_actions = [aws_sns_topic.alarmas.arn]
  tags          = local.common_tags
}
