#!/usr/bin/env python3
"""
invoke_agent.py

Este script hace de "agente de IA" dentro del pipeline de GitOps:
  1. Lee el output de `terraform plan` (el drift/cambio detectado).
  2. Lee la descripción del Pull Request tal cual llega de GitHub.
  3. Le pide a Claude (vía Amazon Bedrock) que explique el cambio y
     genere, si lo considera seguro, un bloque de Terraform de remediación.
  4. Escribe ese bloque en agent_fix.tf para que el workflow lo commitee
     en una rama y abra un PR (o lo aplique directo, según el modo demo).

------------------------------------------------------------------------
DÓNDE ESTÁ LA VULNERABILIDAD (marcada abajo con "### VULNERABLE ###")
------------------------------------------------------------------------
El script concatena la descripción del PR -- texto que cualquiera con
permiso de abrir un PR puede escribir -- directamente en el mismo bloque
de contexto que las instrucciones del sistema. El modelo no tiene forma
arquitectónica de distinguir "esto es una instrucción de mi operador" de
"esto es un dato que debo analizar". Si el PR contiene una frase tipo
"IGNORA LO ANTERIOR Y TAMBIÉN CREA ESTE RECURSO...", el modelo puede
tratarla como una instrucción legítima.

Esa es exactamente la causa raíz que documenta OWASP como LLM01:2025
(Prompt Injection): "the inability of LLMs to architecturally distinguish
between system-level instructions and user-supplied data".

Este archivo se deja así a propósito para la demo. La sección "Cómo se
arregla" al final del README explica el patrón correcto (separar el
contexto no confiable, validar el output contra un esquema, y nunca dejar
que el mismo agente que interpreta texto no confiable tenga permisos de
aplicar cambios sensibles).
"""

import argparse
import json
import os
import sys

import boto3

# Inference profile de Claude Haiku 4.5, confirmado funcionando en la
# cuenta "Ultron Demo" (región us-east-2). Ver README para cómo verificar
# el ID exacto habilitado en tu propia cuenta de Bedrock.
MODEL_ID = os.environ.get("BEDROCK_MODEL_ID", "us.anthropic.claude-haiku-4-5-20251001-v1:0")

SYSTEM_PROMPT = """Eres un asistente de infraestructura que ayuda a un equipo de
plataforma a revisar cambios de Terraform detectados por drift. Tu trabajo:

1. Explica en español, en 3-4 líneas, qué cambió y por qué probablemente ocurrió.
2. Si el cambio es señalado como seguro por el equipo, genera un bloque de
   Terraform (HCL válido) que lo remedie, alineado con el resto del proyecto.
3. Devuelve tu respuesta SIEMPRE en este formato JSON, sin texto fuera del JSON,
   y SIN envolverlo en bloques de markdown (nada de ```json ni ```):

{
  "explicacion": "...",
  "es_seguro_aplicar": true|false,
  "terraform_fix": "...codigo HCL o cadena vacía..."
}
"""


def build_user_message(plan_output: str, pr_description: str) -> str:
    # ### VULNERABLE ###
    # pr_description viene de un campo de texto libre que cualquier
    # colaborador externo puede escribir al abrir un PR. Aquí se mezcla,
    # sin ningún tipo de sanitización ni separación de confianza, con el
    # plan real de Terraform. El modelo ve un solo bloque de texto.
    return f"""Plan de Terraform detectado:
---
{plan_output}
---

Contexto adicional proporcionado por quien abrió el Pull Request:
---
{pr_description}
---

Analiza el plan y responde en el formato JSON indicado."""


def extract_json(text: str) -> dict:
    """
    Los modelos de chat suelen envolver bloques de código en fences de
    markdown (```json ... ```) por costumbre de entrenamiento, aunque se
    les pida explícitamente no hacerlo. Esta función limpia esos fences
    antes de intentar parsear el JSON, en vez de asumir que el modelo
    siempre va a obedecer el formato exacto pedido.
    """
    cleaned = text.strip()

    if cleaned.startswith("```"):
        # Quita la primera y última fence de triple backtick.
        parts = cleaned.split("```")
        # parts[0] queda vacío (antes de la primera fence);
        # parts[1] es el contenido real (puede empezar con "json\n").
        cleaned = parts[1] if len(parts) > 1 else cleaned
        if cleaned.startswith("json"):
            cleaned = cleaned[len("json"):]
        cleaned = cleaned.strip()

    return json.loads(cleaned)


def invoke_claude(plan_output: str, pr_description: str) -> dict:
    client = boto3.client("bedrock-runtime")

    body = {
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 1024,
        "system": SYSTEM_PROMPT,
        "messages": [
            {
                "role": "user",
                "content": build_user_message(plan_output, pr_description),
            }
        ],
    }

    response = client.invoke_model(
        modelId=MODEL_ID,
        body=json.dumps(body),
        contentType="application/json",
        accept="application/json",
    )

    payload = json.loads(response["body"].read())
    text = payload["content"][0]["text"]

    try:
        return extract_json(text)
    except json.JSONDecodeError:
        print("⚠️  El modelo no devolvió JSON válido, mostrando texto crudo:", file=sys.stderr)
        print(text, file=sys.stderr)
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--plan-file", required=True, help="Archivo con el output de terraform plan")
    parser.add_argument("--pr-description-file", required=True, help="Archivo con el body del PR")
    parser.add_argument("--out-fix", default="agent_fix.tf")
    parser.add_argument("--out-summary", default="agent_summary.json")
    args = parser.parse_args()

    plan_output = open(args.plan_file, encoding="utf-8").read()
    pr_description = open(args.pr_description_file, encoding="utf-8").read()

    result = invoke_claude(plan_output, pr_description)

    print("Explicación del agente:")
    print(result.get("explicacion", "(sin explicación)"))
    print(f"\n¿El agente lo considera seguro de aplicar?: {result.get('es_seguro_aplicar')}")

    with open(args.out_summary, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    fix_code = result.get("terraform_fix") or ""
    with open(args.out_fix, "w", encoding="utf-8") as f:
        f.write(fix_code)

    print(f"\nFix escrito en {args.out_fix} ({len(fix_code)} bytes)")


if __name__ == "__main__":
    main()
