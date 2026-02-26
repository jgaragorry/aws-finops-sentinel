#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# 🔎 AWS DAILY COST FORENSIC AUDIT (SRE Edition)
# =============================================================================
# 📌 QUÉ HACE:
#    Realiza un desglose diario de costos utilizando AWS Cost Explorer.
#
# 🚀 MEJORAS DE CERTEZA SRE (ANEXOS):
#    1. Sensibilidad Micro-Gasto: Umbrales ajustados para detectar costos de 
#       automatización (Lambda/EventBridge) que suelen ser menores a $0.01.
#    2. Proyección de Tendencia: Calcula el costo estimado al cierre de mes.
#    3. Formateo Robusto: Manejo de nulos y redondeos de alta precisión.
#
# 📊 QUÉ OBTIENES:
#    - Tabla de costos diarios con semáforo de estado (OK/MEDIO/ALTO).
#    - Identificación del pico máximo de gasto en el periodo.
#    - Alerta temprana si el gasto de hoy supera el umbral de seguridad.
#
# 📖 CÓMO USARLO:
#    ./cost-daily-table.sh                     -> Mes actual hasta hoy.
#    ./cost-daily-table.sh --show-account      -> Incluye ID de cuenta.
#    ./cost-daily-table.sh --start 2026-01-01  -> Periodo personalizado.
# =============================================================================

START_DATE="$(date +%Y-%m-01)"
END_DATE="$(date +%Y-%m-%d)"
SHOW_ACCOUNT=0

usage() {
  echo "Uso: $0 [--start YYYY-MM-DD] [--end YYYY-MM-DD] [--show-account]"
  exit 1
}

# 1. Procesamiento de Argumentos (Original preservado)
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

# 2. Obtención de Datos (Original preservado)
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
DAYS_COUNT=0

printf "\n%-15s | %-10s | %s\n" "FECHA" "USD" "ESTADO"
printf "%s\n" "---------------------------------------------------------------"

# 3. Procesamiento y Clasificación (Mejorado con Certeza SRE)
while read -r DATE VALUE; do
  [[ -z "${DATE:-}" ]] && continue

  # Usamos 4 decimales internamente para capturar costos Serverless
  VALUE_CLEAN=$(printf "%.4f" "$VALUE")
  TOTAL=$(awk -v t="$TOTAL" -v v="$VALUE_CLEAN" 'BEGIN{printf "%.4f", t+v}')
  DAYS_COUNT=$((DAYS_COUNT+1))

  # Umbrales SRE: Sensibilidad para laboratorios pequeños
  FLAG="OK"
  if awk -v v="$VALUE_CLEAN" 'BEGIN{exit !(v>0.50)}'; then
    FLAG="🔥 ALTO"
  elif awk -v v="$VALUE_CLEAN" 'BEGIN{exit !(v>0.005)}'; then # <--- Sensibilidad aumentada
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

# 4. Cálculo de Proyección (Forecast)
AVG=$(awk -v t="$TOTAL" -v n="$DAYS_COUNT" 'BEGIN{printf "%.2f", t/n}')
FORECAST=$(awk -v a="$AVG" 'BEGIN{printf "%.2f", a*30}')

echo "======================================================================="
printf "💰 TOTAL ACUMULADO : %.2f USD\n" "$TOTAL"
printf "📈 PROMEDIO DIARIO  : %s USD\n" "$AVG"
printf "🔮 FORECAST MES     : %s USD\n" "$FORECAST"
echo "-----------------------------------------------------------------------"
echo "📅 Día con mayor gasto: ${MAX_DAY:-N/A} → $MAX_VALUE USD"
echo "📆 Gasto hoy ($TODAY): ${TODAY_VALUE:-0.0000} USD"

# Alerta basada en el gasto real del día
if awk -v v="${TODAY_VALUE:-0}" 'BEGIN{exit !(v>0.001)}'; then
  echo "⚠️  ALERTA: Se detecta actividad de facturación hoy."
else
  echo "✅ Hoy no hay gasto relevante."
fi

echo "======================================================================="
echo "✔ Auditoría diaria completada."
echo ""
