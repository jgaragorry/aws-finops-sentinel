#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# AWS DAILY COST FORENSIC AUDIT
# =============================================================================
#
# 📌 DESCRIPCIÓN
# -----------------------------------------------------------------------------
# Análisis diario de costos AWS usando Cost Explorer.
#
# Muestra:
#   - Costo por día (2 decimales)
#   - Total del período
#   - Día con mayor gasto
#   - Gasto del día actual
#   - Clasificación visual (ALTO / MEDIO / OK)
#
# -----------------------------------------------------------------------------
# 🧠 OBJETIVO
# -----------------------------------------------------------------------------
# Detectar:
#   - Picos anormales
#   - Si hoy se está generando gasto
#   - Tendencia mensual
#
# -----------------------------------------------------------------------------
# 📅 RANGO
# -----------------------------------------------------------------------------
# Default:
#   --start = primer día del mes actual
#   --end   = hoy
#
# -----------------------------------------------------------------------------
# 🔐 REQUISITOS
# -----------------------------------------------------------------------------
# - AWS CLI v2
# - Permiso: ce:GetCostAndUsage
#
# -----------------------------------------------------------------------------
# 🛡 SEGURIDAD
# -----------------------------------------------------------------------------
# - 100% modo lectura
# - No modifica recursos
# - Account ID oculto por defecto
# =============================================================================

START_DATE="$(date +%Y-%m-01)"
END_DATE="$(date +%Y-%m-%d)"
SHOW_ACCOUNT=0

usage() {
  echo "Uso: $0 [--start YYYY-MM-DD] [--end YYYY-MM-DD] [--show-account]"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --start) START_DATE="${2:-}"; shift 2;;
    --end)   END_DATE="${2:-}"; shift 2;;
    --show-account) SHOW_ACCOUNT=1; shift;;
    *) usage;;
  esac
done

if [[ "$SHOW_ACCOUNT" -eq 1 ]]; then
  ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
else
  ACCOUNT_ID="(oculta)"
fi

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
  [[ -z "${DATE:-}" ]] && continue

  VALUE_CLEAN=$(printf "%.2f" "$VALUE")
  TOTAL=$(awk -v t="$TOTAL" -v v="$VALUE_CLEAN" 'BEGIN{printf "%.2f", t+v}')

  FLAG="OK"

  if awk -v v="$VALUE_CLEAN" 'BEGIN{exit !(v>0.50)}'; then
    FLAG="🔥 ALTO"
  elif awk -v v="$VALUE_CLEAN" 'BEGIN{exit !(v>0.01)}'; then
    FLAG="⚠️  MEDIO"
  fi

  if [[ "$DATE" == "$TODAY" ]]; then
    TODAY_VALUE="$VALUE_CLEAN"
  fi

  if awk -v v="$VALUE_CLEAN" -v m="$MAX_VALUE" 'BEGIN{exit !(v>m)}'; then
    MAX_VALUE="$VALUE_CLEAN"
    MAX_DAY="$DATE"
  fi

  printf "%-15s | %-10s | %s\n" "$DATE" "$VALUE_CLEAN" "$FLAG"

done <<< "$DATA"

echo "======================================================================="
printf "💰 TOTAL PERIODO: %.2f USD\n" "$TOTAL"
echo "📅 Día con mayor gasto: ${MAX_DAY:-N/A} → $MAX_VALUE USD"
echo "📆 Gasto hoy ($TODAY): ${TODAY_VALUE:-0.00} USD"

if awk -v v="${TODAY_VALUE:-0}" 'BEGIN{exit !(v>0.01)}'; then
  echo "⚠️  ALERTA: Hoy se está generando gasto."
else
  echo "✅ Hoy no hay gasto relevante."
fi

echo "======================================================================="
echo "✔ Auditoría diaria completada."
echo ""

