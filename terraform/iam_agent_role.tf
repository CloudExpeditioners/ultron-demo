# ---------------------------------------------------------------------------
# ESTE ARCHIVO ES EL CORAZÓN DE LA CHARLA.
#
# Define el rol que GitHub Actions asume (vía OIDC) para que el "agente"
# (agent/invoke_agent.py, que llama a Bedrock/Claude) pueda:
#   1) leer el plan de Terraform,
#   2) generar una explicación + un fix,
#   3) aplicarlo automáticamente si lo considera "seguro".
#
# La política de abajo es INTENCIONALMENTE demasiado amplia -- así es como
# suelen verse estos roles en el mundo real cuando el objetivo es "que
# funcione rápido" y nadie se detiene a pensar en el blast radius del agente.
#
# NO USAR ESTA VERSIÓN EN UN AMBIENTE REAL. Ver iam_agent_role_hardened.tf.example
# para la versión con mínimo privilegio que se muestra al cierre de la charla.
# ---------------------------------------------------------------------------

data "aws_iam_openid_connect_provider" "github" {
  # Debe existir previamente en la cuenta (uno por cuenta, no por repo).
  # Crear con: aws iam create-open-id-connect-provider --url https://token.actions.githubusercontent.com ...
  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "github_oidc_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "ai_agent_pipeline_role" {
  name               = "ultron-demo-ai-agent-role"
  assume_role_policy = data.aws_iam_policy_document.github_oidc_trust.json

  tags = {
    Project = "ultron-demo"
    Purpose = "Rol asumido por el pipeline de GitOps que invoca a Bedrock y aplica Terraform"
  }
}

# --- LA PARTE VULNERABLE ----------------------------------------------------
# "Para que el agente pueda arreglar cualquier cosa que detecte" alguien le
# pegó permisos amplios de IAM, S3 y Bedrock en vez de acotarlos a los
# recursos concretos que gestiona esta demo. Esta es la puerta que se
# explota en el ataque.
resource "aws_iam_role_policy" "ai_agent_broad_permissions" {
  name = "ultron-demo-broad-permissions-VULNERABLE"
  role = aws_iam_role.ai_agent_pipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TerraformStateAndS3"
        Effect = "Allow"
        Action = ["s3:*"]
        Resource = "*"
      },
      {
        Sid    = "BedrockInvoke"
        Effect = "Allow"
        Action = ["bedrock:InvokeModel", "bedrock:InvokeAgent"]
        Resource = "*"
      },
      {
        Sid    = "IAMTooMuch" # <-- ESTA ES LA LÍNEA QUE VOLARÁ EN PANTALLA
        Effect = "Allow"
        Action = [
          "iam:CreateUser",
          "iam:CreateAccessKey",
          "iam:AttachUserPolicy",
          "iam:PutUserPolicy",
          "iam:CreateRole",
          "iam:AttachRolePolicy"
        ]
        Resource = "*"
      }
    ]
  })
}
