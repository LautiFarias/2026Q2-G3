variable "name_prefix" {
  description = "Prefijo para nombrar los recursos de red (ej: accesoseguro-dev)."
  type        = string
}

variable "vpc_cidr" {
  description = "Bloque CIDR de la VPC. Cada subred sale de acá con cidrsubnet()."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr debe ser un bloque CIDR válido, ej: 10.0.0.0/16."
  }
}

variable "azs" {
  description = "Zonas de disponibilidad a usar (2, una por subred de cada capa)."
  type        = list(string)

  validation {
    condition     = length(var.azs) == 2
    error_message = "La arquitectura usa exactamente 2 zonas de disponibilidad."
  }
}

variable "create_public_subnets" {
  description = "Si es false, no se crea Internet Gateway ni ruta pública (red totalmente privada)."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags comunes para todos los recursos de red."
  type        = map(string)
  default     = {}
}
