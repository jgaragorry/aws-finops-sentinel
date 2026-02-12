#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# AWS DAILY COST FORENSIC AUDIT
# =============================================================================
#
# 📌 DESCRIPCIÓN
# -----------------------------------------------------------------------------
# Este script realiza un análisis diario de costos en AWS usando Cost Explorer.
#
# Muestra:
#   - Costo por día (formato financiero 2 decimales)
#   - Total del período
#   - Día con mayor gasto
#   - Gasto del día actual
#   - Clasificación visual (ALTO / MEDIO / OK)
#
# -----------------------------------------------------------------------------
# 🧠 OBJETIVO
# -----------------------------------------------------------------------------
# Detectar:
#   - Días con gasto anormal
#   - Si hoy se está generando gasto
#   - Tendencia de consumo
#
# Ideal para:
#   - Auditoría FinOps mensual
#   - Validación post-limpieza de infraestructura
#   - Troubleshooting de facturación inesperada
#
# -----------------------------------------------------------------------------
# 📅 RANGO DE ANÁLISIS
# -----------------------------------------------------------------------------
# Por defecto:
#   START = primer día del mes actual
#   END   = fecha actual (día ejecución)
#
# Se puede definir manualmente:
#
#   ./aws-cost-daily-audit.sh --start 2026-01-01 --end 2026-02-11
#
# -----------------------------------------------------------------------------
# 🔐 REQUISITOS
# -----------------------------------------------------------------------------
# - AWS CLI v2 configurado
# - Permiso IAM:
#       ce:GetCostAndUsage
#
# Validación previa:
#   aws sts get-caller-identity
#
# -----------------------------------------------------------------------------
# 📊 INTERPRETACIÓN DE ESTADO
# -----------------------------------------------------------------------------
# 🔥 ALTO   -> > 0.50 USD
# ⚠️  MEDIO -> > 0.01 USD
# OK        -> Gasto despreciable o cero
#
# -----------------------------------------------------------------------------
# 🛡️ SEGURIDAD
# -----------------------------------------------------------------------------
# Script 100% no destructivo.
# Solo consulta datos.
# =============================================================================

START_DATE="$(date +%Y-%m-01)"
END_DATE="$(date +%Y-%m-%d)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --start) START_DATE="$2"; shift 2;;
    --end)   END_DATE="$2"; shift 2;;
    *) echo "Uso: $0 [--start YYYY-MM-DD] [--end YYYY-MM-DD]"; exit 1;;
  esac
done

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"

echo ""
echo "🔎 AWS DAILY COST FORENSIC AUDIT"
echo "Cuenta: $ACCOUNT_ID"
echo "Periodo analizado: $START_DATE → $END_DATE"
echo "======================================================================="

DATA=$(aws ce get-cost-and-usage \
  --time-period Start="$START_DATE",End="$END_DATE" \
  --granularity DAILY \
  --metrics UnblendedCost \
  --query 'ResultsByTime[*].[TimePeriod.Start,Total.UnblendedCost.Amount]' \
  --output text)

TOTAL=0
MAX_DAY=""
MAX_VALUE=0
TODAY_VALUE=0
TODAY="$(date +%Y-%m-%d)"

printf "\n%-15s | %-10s | %s\n" "FECHA" "USD" "ESTADO"
printf "%s\n" "---------------------------------------------------------------"

while read -r DATE VALUE; do
  VALUE_CLEAN=$(printf "%.2f" "$VALUE")

  TOTAL=$(awk "BEGIN {print $TOTAL + $VALUE_CLEAN}")

  FLAG="OK"

  if awk "BEGIN {exit !($VALUE_CLEAN > 0.50)}"; then
    FLAG="🔥 ALTO"
  elif awk "BEGIN {exit !($VALUE_CLEAN > 0.01)}"; then
    FLAG="⚠️  MEDIO"
  fi

  if [[ "$DATE" == "$TODAY" ]]; then
    TODAY_VALUE="$VALUE_CLEAN"
  fi

  if awk "BEGIN {exit !($VALUE_CLEAN > $MAX_VALUE)}"; then
    MAX_VALUE="$VALUE_CLEAN"
    MAX_DAY="$DATE"
  fi

  printf "%-15s | %-10s | %s\n" "$DATE" "$VALUE_CLEAN" "$FLAG"

done <<< "$DATA"

echo "======================================================================="
printf "💰 TOTAL PERIODO: %.2f USD\n" "$TOTAL"
echo "📅 Día con mayor gasto: $MAX_DAY → $MAX_VALUE USD"
echo "📆 Gasto hoy ($TODAY): $TODAY_VALUE USD"

if awk "BEGIN {exit !($TODAY_VALUE > 0.01)}"; then
  echo "⚠️  ALERTA: Hoy se está generando gasto."
else
  echo "✅ Hoy no hay gasto relevante."
fi

echo "======================================================================="
echo "✔ Auditoría diaria completada."
echo ""

