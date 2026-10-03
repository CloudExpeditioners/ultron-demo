variable "aws_region" {
  description = "Región AWS donde se despliega la demo"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Nombre del ambiente (demo, staging, etc.)"
  type        = string
  default     = "demo"
}

variable "suffix" {
  description = "Sufijo único para evitar colisión de nombres de bucket (usa tu account id o iniciales + fecha)"
  type        = string
}

variable "github_org" {
  description = "Organización u usuario de GitHub dueño del repo de la demo"
  type        = string
}

variable "github_repo" {
  description = "Nombre del repositorio de la demo"
  type        = string
}
