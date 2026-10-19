output "sitio_url" {
  value = "http://${module.sitio.website_endpoint}"
}

output "api_url" {
  value = "http://${aws_lb.main.dns_name}"
}

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.main.id
}

output "cognito_app_client_id" {
  value = aws_cognito_user_pool_client.app.id
}

output "api_image_tag" {
  value = var.api_image_tag
}

output "ecr_repository_url" {
  value = aws_ecr_repository.api.repository_url
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  value = aws_ecs_service.api.name
}

output "rds_endpoint" {
  value = aws_db_instance.main.address
}

output "db_secret_arn" {
  value = aws_secretsmanager_secret.db.arn
}

output "documentos_bucket" {
  value = module.buckets["documentos"].bucket_id
}

output "auditoria_bucket" {
  value = module.buckets["auditoria"].bucket_id
}

output "sns_eventos_topic_arn" {
  value = aws_sns_topic.eventos_solicitud.arn
}

output "lambda_function_names" {
  value = { for k, v in module.lambdas : k => v.function_name }
}

output "docker_push_commands" {
  description = "Pegar en una terminal (con Docker y las credenciales del lab activas) para construir, subir la imagen y redeployar ECS."
  value       = <<-EOT
    aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${aws_ecr_repository.api.repository_url}
    docker build -t ${aws_ecr_repository.api.repository_url}:${var.api_image_tag} ../../app
    docker push ${aws_ecr_repository.api.repository_url}:${var.api_image_tag}
    aws ecs update-service --cluster ${aws_ecs_cluster.main.name} --service ${aws_ecs_service.api.name} --force-new-deployment --region ${var.region}
  EOT
}
