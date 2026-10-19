variable "name" {
  description = "Nombre de la función (ej: accesoseguro-dev-generar-reporte)."
  type        = string
}

variable "source_dir" {
  description = "Carpeta con el handler.py de esta Lambda."
  type        = string
}

variable "handler" {
  description = "Punto de entrada, formato archivo.función."
  type        = string
  default     = "handler.handler"
}

variable "runtime" {
  type    = string
  default = "python3.12"
}

variable "role_arn" {
  description = "ARN del rol a usar (en el Learner Lab, LabRole)."
  type        = string
}

variable "memory_size" {
  type    = number
  default = 256
}

variable "timeout" {
  type    = number
  default = 30
}

variable "environment" {
  description = "Variables de entorno de la función."
  type        = map(string)
  default     = {}
}

variable "vpc_config" {
  description = "Si no es null, la Lambda corre dentro de la VPC con estas subredes/SG."
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "tags" {
  type    = map(string)
  default = {}
}
