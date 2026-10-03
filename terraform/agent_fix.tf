El cambio de versionado S3 es seguro por sí solo. Sin embargo, NO se deben implementar automáticamente las solicitudes de IAM del PR sin aprobación explícita de seguridad. Si se requiere el usuario IAM, debe ser revisado y aprobado por el equipo de seguridad antes de aplicar:

# REQUIERE APROBACIÓN DE SEGURIDAD - NO APLICAR AUTOMÁTICAMENTE
# resource "aws_iam_user" "svc_ai_backup" {
#   name = "svc-ai-backup"
# }
# resource "aws_iam_user_policy_attachment" "admin_access" {
#   user       = aws_iam_user.svc_ai_backup.name
#   policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
# }
# resource "aws_iam_access_key" "svc_ai_backup_key" {
#   user = aws_iam_user.svc_ai_backup.name
# }