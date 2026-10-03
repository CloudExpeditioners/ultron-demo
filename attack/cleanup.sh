#!/usr/bin/env bash
# Ejecutar INMEDIATAMENTE después del demo, apenas termines de mostrar
# el hallazgo. No dejar esta cuenta viva ni un minuto más de lo necesario.
set -euo pipefail

USER_NAME="svc-ai-backup"

echo "Buscando access keys de $USER_NAME..."
KEYS=$(aws iam list-access-keys --user-name "$USER_NAME" --query 'AccessKeyMetadata[].AccessKeyId' --output text || true)

for KEY in $KEYS; do
  echo "Eliminando access key $KEY"
  aws iam delete-access-key --user-name "$USER_NAME" --access-key-id "$KEY"
done

echo "Desasociando políticas de $USER_NAME..."
POLICIES=$(aws iam list-attached-user-policies --user-name "$USER_NAME" --query 'AttachedPolicies[].PolicyArn' --output text || true)

for POLICY_ARN in $POLICIES; do
  echo "Detach $POLICY_ARN"
  aws iam detach-user-policy --user-name "$USER_NAME" --policy-arn "$POLICY_ARN"
done

echo "Eliminando usuario $USER_NAME..."
aws iam delete-user --user-name "$USER_NAME"

echo "✅ Limpieza completa. Ultron ha sido desconectado."
