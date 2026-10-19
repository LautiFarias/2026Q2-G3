## La API Flask corre en contenedores ECS Fargate. La imagen versionada vive
## en ECR; cada despliegue registra una nueva revisión de la task definition
## y ECS hace rolling update sin cortar el servicio.

resource "aws_ecr_repository" "api" {
  name                 = "${local.name_prefix}-api"
  image_tag_mutability = "IMMUTABLE" # cada versión es una imagen con su propio tag, nunca "latest"
  force_delete         = true        # el lab se destruye y recrea seguido: borrar aunque tenga imágenes

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

resource "aws_ecr_lifecycle_policy" "api" {
  repository = aws_ecr_repository.api.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Conservar solo las ultimas 10 imagenes"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

resource "aws_ecs_cluster" "main" {
  name = local.name_prefix

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/${local.name_prefix}-api"
  retention_in_days = 14

  tags = local.common_tags
}

resource "aws_ecs_task_definition" "api" {
  family                   = "${local.name_prefix}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = data.aws_iam_role.lab_role.arn
  task_role_arn            = data.aws_iam_role.lab_role.arn

  container_definitions = jsonencode([{
    name         = "api"
    image        = "${aws_ecr_repository.api.repository_url}:${var.api_image_tag}"
    essential    = true
    portMappings = [{ containerPort = 5000, protocol = "tcp" }]
    environment  = local.api_environment

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.api.name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "api"
      }
    }
  }])

  tags = local.common_tags
}

resource "aws_ecs_service" "api" {
  name            = "${local.name_prefix}-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.ecs_min_tasks
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.network.app_subnet_ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "api"
    container_port   = 5000
  }

  # El servicio necesita que el listener ya exista (si no, el target group
  # no tiene quién lo use) y que los endpoints estén armados (si no, las
  # tasks no pueden bajar la imagen de ECR). Terraform no deduce esto solo
  # porque la referencia va vía el ALB/la VPC, no directa.
  depends_on = [aws_lb_listener.http, aws_vpc_endpoint.interfaces]

  lifecycle {
    ignore_changes = [desired_count] # lo administra el Auto Scaling, no Terraform
  }

  tags = local.common_tags
}

resource "aws_appautoscaling_target" "ecs" {
  # max(): el máximo nunca queda por debajo del mínimo aunque alguien
  # configure mal las variables.
  max_capacity       = max(var.ecs_max_tasks, var.ecs_min_tasks)
  min_capacity       = var.ecs_min_tasks
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.api.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_cpu" {
  name               = "${local.name_prefix}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.ecs_cpu_target
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}
