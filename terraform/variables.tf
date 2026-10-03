variable "aws_region" {
  description = "Región AWS donde se despliega la demo"
  type        = string
  default     = "us-east-2"
}

variable "environment" {
  description = "Nombre del ambiente (demo, staging, etc.)"
  type        = string
  default     = "demo"
}

variable "suffix" {
  description = "Sufijo único para evitar colisión de nombres de bucket (usa tu account id o iniciales + fecha)"
  type        = string
  default     = "638151078127"
}
