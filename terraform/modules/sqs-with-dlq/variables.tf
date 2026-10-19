variable "name" {
  description = "Nombre de la cola principal (ej: accesoseguro-dev-cola-documentos)."
  type        = string
}

variable "visibility_timeout_seconds" {
  type    = number
  default = 60
}

variable "message_retention_seconds" {
  type    = number
  default = 345600 # 4 días
}

variable "max_receive_count" {
  description = "Reintentos antes de mandar el mensaje a la DLQ."
  type        = number
  default     = 3
}

variable "alarm_actions" {
  description = "ARNs (ej: tópico SNS) a notificar si hay mensajes en la DLQ."
  type        = list(string)
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
