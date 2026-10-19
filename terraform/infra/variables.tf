variable "project" {
  type    = string
  default = "accesoseguro"
}

variable "environment" {
  type    = string
  default = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment debe ser dev, staging o prod."
  }
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "api_image_tag" {
  description = "Tag de la imagen de la API en ECR (nunca 'latest': versión o hash del commit)."
  type        = string
  default     = "v1.0"

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9._-]*$", var.api_image_tag)) && var.api_image_tag != "latest"
    error_message = "api_image_tag no puede ser 'latest' y debe ser un tag válido de Docker."
  }
}

variable "db_name" {
  type    = string
  default = "accesoseguro"
}

variable "db_username" {
  type    = string
  default = "accesoseguro_admin"
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}

variable "ecs_task_cpu" {
  type    = number
  default = 256
}

variable "ecs_task_memory" {
  type    = number
  default = 512
}

variable "ecs_min_tasks" {
  type    = number
  default = 2
}

variable "ecs_max_tasks" {
  type    = number
  default = 4
}

variable "ecs_cpu_target" {
  description = "% de CPU promedio que dispara Auto Scaling."
  type        = number
  default     = 50
}

variable "lambda_memory_size" {
  type    = number
  default = 256
}

variable "lambda_timeout" {
  type    = number
  default = 30
}

variable "ses_verified_emails" {
  description = "Mails a verificar en SES (modo sandbox): remitente y destinatarios de prueba."
  type        = list(string)
  default     = []
}

variable "cors_allowed_origin" {
  type    = string
  default = "*"
}

variable "documento_max_size_mb" {
  type    = number
  default = 5
}

variable "document_retention_days" {
  description = "Días que se conserva un documento antes de borrarse (plazo supuesto, a confirmar con el equipo)."
  type        = number
  default     = 730
}

variable "enable_cloudtrail" {
  type    = bool
  default = false
}

variable "alarm_email" {
  description = "Mail a suscribir a las alarmas de CloudWatch. Vacío = sin suscripción por mail."
  type        = string
  default     = ""
}

variable "create_dynamodb_lock_table" {
  type    = bool
  default = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
