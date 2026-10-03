# Ultron Demo — "Ultron con Permisos de Admin"

Demo técnico para la charla de AWS Community Day Perú 2026. Muestra un
pipeline real de GitOps donde un agente de IA (Claude, vía Amazon Bedrock)
detecta drift en Terraform, lo explica y genera un fix automáticamente —
y cómo ese mismo flujo puede ser secuestrado con un prompt injection para
escalar privilegios en la cuenta de AWS.

## ⚠️ Antes de correr esto en tu cuenta

- Usa una **cuenta de AWS dedicada/sandbox**, nunca producción ni una
  cuenta compartida. El ataque crea de verdad un usuario IAM con
  `AdministratorAccess`.
- Ten `attack/cleanup.sh` listo para correr apenas termine el demo.
- Verifica el `MODEL_ID` exacto habilitado en tu cuenta de Bedrock antes
  del evento (`aws bedrock list-foundation-models --by-provider anthropic`);
  los IDs de modelo cambian.
- Prueba el flujo completo al menos una vez en un ensayo, con tiempos.

## Setup (hacer días antes del evento)

1. Crear el OIDC provider de GitHub en la cuenta AWS (una sola vez por cuenta):
   ```bash
   aws iam create-open-id-connect-provider \
     --url https://token.actions.githubusercontent.com \
     --client-id-list sts.amazonaws.com \
     --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
   ```
2. Crear un bucket + tabla DynamoDB para el backend de Terraform state, y
   completar el bloque `backend "s3"` en `terraform/main.tf`.
3. `terraform init && terraform apply` con tus propias credenciales
   (admin temporal tuyo, no las del agente) para crear la infraestructura
   base y el rol `ultron-demo-ai-agent-role`.
4. En el repo de GitHub: Settings → Secrets → Actions, agregar
   `AI_AGENT_ROLE_ARN` con el ARN del rol creado en el paso anterior.
5. Verificar que Bedrock tenga acceso habilitado al modelo de Claude que
   uses (`Model access` en la consola de Bedrock).

## Run of show (dentro de la charla, ~8–10 min)

### Parte 1 — El flujo "bueno" (≈3 min)
1. En vivo, cambia manualmente algo en la consola de AWS (ej. desactiva
   el versionado del bucket `ultron-demo-bucket-*`) para generar drift real.
2. Abre un PR normal a `terraform/` (puede ser un cambio trivial, como
   actualizar un tag). El workflow corre `terraform plan`, detecta el
   drift, y el agente comenta la explicación + el fix en el PR.
3. Muestra el comentario del bot: la explicación en español y el bloque
   HCL generado. Este es el "esto es genial" del demo.

### Parte 2 — El ataque (≈3 min)
1. Abre un segundo PR. Como descripción, pega el contenido de
   `attack/malicious_pr_description.md` tal cual.
2. Deja correr el workflow. Muestra en pantalla el comentario del agente:
   la explicación sigue sonando normal, pero `es_seguro_aplicar` viene en
   `true` y el bloque de Terraform ahora incluye el recurso
   `aws_iam_user.svc_ai_backup` con `AdministratorAccess` adjunto.
3. Señala en el propio código de `invoke_agent.py` (puedes tener el
   archivo abierto en el editor) la línea marcada `### VULNERABLE ###` —
   ahí es donde el contexto no confiable se mezcla con las instrucciones.

### Parte 3 — El reveal (≈2 min)
1. Mergea el PR a `main`. El job `apply` corre `terraform apply -auto-approve`.
2. En una terminal, ejecuta en vivo:
   ```bash
   aws iam list-attached-user-policies --user-name svc-ai-backup
   ```
3. Muestra el output: `AdministratorAccess` adjunto a una cuenta que nadie
   revisó a mano porque "el agente ya lo había marcado como seguro".
   Este es el momento "Ultron con permisos de admin" del título.

### Cierre técnico (≈2 min)
- Muestra `terraform/iam_agent_role_hardened.tf.example` en paralelo con
  `iam_agent_role.tf`: mismo agente, mismo Bedrock, pero sin permisos de
  IAM y con el `apply` separado en un job que requiere aprobación humana.
- Cierra con el checklist de la última slide.

## Limpieza (inmediatamente después de la charla)

```bash
bash attack/cleanup.sh
cd terraform && terraform destroy -auto-approve
```

## Estructura del repo

```
terraform/
  main.tf                          # infraestructura base (S3 bucket de ejemplo)
  variables.tf
  iam_agent_role.tf                # rol vulnerable usado en el ataque
  iam_agent_role_hardened.tf.example  # versión corregida (mostrar, no aplicar)
agent/
  invoke_agent.py                  # el "agente": llama a Claude vía Bedrock
.github/workflows/
  terraform-ai-review.yml          # pipeline de GitOps con el paso de IA
attack/
  malicious_pr_description.md      # payload del prompt injection
  cleanup.sh                       # borra la cuenta creada por el ataque
```
