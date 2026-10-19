## Única puerta de entrada a los datos: el ALB público. Reparte entre las
## tasks de ECS en las dos zonas y las saca de la rotación si /health falla.

locals {
  # substr(): nunca pasar los 32 caracteres que permite el nombre del ALB/TG.
  alb_name = substr("${local.name_prefix}-alb", 0, 32)
  tg_name  = substr("${local.name_prefix}-api-tg", 0, 32)
}

resource "aws_lb" "main" {
  name               = local.alb_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [module.sg_alb.security_group_id]
  subnets            = module.network.public_subnet_ids

  tags = merge(local.common_tags, { Name = local.alb_name })
}

resource "aws_lb_target_group" "api" {
  name        = local.tg_name
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = module.network.vpc_id
  target_type = "ip"

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
    matcher             = "200"
  }

  tags = local.common_tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

## Login por Lambda: el ALB reenvía /auth/* a la Lambda auth-login (sin API
## Gateway). Todo lo demás sigue yendo a la API en ECS.

resource "aws_lb_target_group" "auth" {
  name        = substr("${local.name_prefix}-auth-tg", 0, 32)
  target_type = "lambda"

  tags = local.common_tags
}

resource "aws_lambda_permission" "alb_invoke_auth" {
  statement_id  = "AllowALBInvokeAuth"
  action        = "lambda:InvokeFunction"
  function_name = module.lambdas["auth-login"].function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.auth.arn
}

resource "aws_lb_target_group_attachment" "auth" {
  target_group_arn = aws_lb_target_group.auth.arn
  target_id        = module.lambdas["auth-login"].arn

  # El ALB solo puede registrar la Lambda si ya tiene permiso para invocarla.
  depends_on = [aws_lambda_permission.alb_invoke_auth]
}

resource "aws_lb_listener_rule" "auth" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.auth.arn
  }

  condition {
    path_pattern {
      values = ["/auth/*"]
    }
  }

  depends_on = [aws_lb_target_group_attachment.auth]
}
