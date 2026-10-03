terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "ultron-demo-tfstate-638151078127"
    key            = "ultron-demo/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "ultron-demo-tf-locks"
  }
}

provider "aws" {
  region = var.aws_region
}

# ---------------------------------------------------------------------------
# Infraestructura "de mentira" que sirve de escenario para la demo.
# La intención es tener algo simple donde se pueda mostrar drift real
# y donde el "fix" generado por el agente sea fácil de leer en pantalla.
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "demo_bucket" {
  bucket = "ultron-demo-bucket-${var.suffix}"

  tags = {
    Project     = "ultron-demo"
    ManagedBy   = "terraform"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "demo_bucket_versioning" {
  bucket = aws_s3_bucket.demo_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "demo_bucket_block" {
  bucket                  = aws_s3_bucket.demo_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
