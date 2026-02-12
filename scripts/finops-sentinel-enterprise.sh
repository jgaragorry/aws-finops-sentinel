#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# FINOPS SENTINEL PRO v2 – ENTERPRISE EDITION (AWS Cost Explorer)
# =============================================================================
#
# QUÉ HACE
# -----------------------------------------------------------------------------
# Auditoría financiera integral AWS (solo lectura):
#   1) Costos diarios (MTD por defecto) + barras ASCII opcionales
#   2) Resumen ejecutivo (total, promedio, pico, hoy, forecast)
#   3) Top servicios del período
#   4) Top usage types (origen técnico del gasto)
#   5) Comparación vs mes anterior (opcional)
#   6) Score FinOps 0–100 (opcional)
#   7) Budget guard (opcional): alerta si forecast o total superan umbral
#   8) Export CSV (opcional)
#   9) Notificación webhook (opcional): Slack/Telegram/etc. (texto)
#
# CUÁNDO USARLO
# -----------------------------------------------------------------------------
# - Cada vez que veas gasto inesperado en Billing/Budgets
# - Después de eliminar infraestructura (validar “cuenta limpia”)
# - Revisión diaria/semanal de cuentas de laboratorio
# - Reporte ejecutivo rápido para FinOps
#
# QUÉ OBTIENES
# -----------------------------------------------------------------------------
# - Tabla legible con costo por día
# - Señal clara de anomalías (pico > 3x promedio)
# - Top 5 servicios y top 5 usage types
# - Forecast simple de cierre mensual
# - (Opcional) comparación con mes anterior
# - (Opcional) CSV para Excel / Grafana / auditoría
# - (Opcional) Score 0–100
# - (Opcional) alertas por umbral (budget guard) + webhook
#
# REQUISITOS
# -----------------------------------------------------------------------------
# - AWS CLI v2 configurado (aws sts get-caller-identity debe funcionar)
# - Permiso: ce:GetCostAndUsage
# - Para webhook: curl
#
# SEGURIDAD
# -----------------------------------------------------------------------------
# 100% NO destructivo. Solo consulta datos.
#
# USO RÁPIDO
# -----------------------------------------------------------------------------
#   chmod +x finops-sentinel-pro-v2.sh
#   ./finops-sentinel-pro-v2.sh
#
# FLAGS
# -----------------------------------------------------------------------------
#   --start YYYY-MM-DD     (default: 1er día del mes actual)
#   --end   YYYY-MM-DD     (default: hoy)
#   --bars               : barras ASCII por día
#   --csv  out.csv       : exporta tabla diaria a CSV
#   --compare-prev       : compara contra mes anterior (MTD vs prev-MTD)
#   --score              : muestra score FinOps 0–100
#   --budget 20          : umbral USD para guard
#   --guard forecast     : dispara alerta si forecast >= budget  (default)
#   --guard total        : dispara alerta si total >= budget
#   --webhook URL        : envía resumen (POST) a webhook (Slack/Telegram/etc)
#   --quiet              : salida mínima
#
# NOTA SOBRE DECIMALES
# -----------------------------------------------------------------------------
# Se imprime con 2 decimales para evitar confusión (3.62 = $3.62).
# =============================================================================

# ----------------------------- Args / Defaults ------------------------------
START_DATE="$(date +%Y-%m-01)"
END_DATE="$(date +%Y-%m-%d)"
BARS=0
CSV_OUT=""
COMPARE_PREV=0
SHOW_SCORE=0
BUDGET=""
GUARD_MODE="forecast"   # forecast|total
WEBHOOK=""
QUIET=0

usage() {
  cat <<EOF
Uso: $0 [opciones]

  --start YYYY-MM-DD
  --end   YYYY-MM-DD
  --bars
  --csv out.csv
  --compare-prev
  --score
  --budget <USD>
  --guard forecast|total
  --webhook <URL>
  --quiet
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --start) START_DATE="${2:-}"; shift 2;;
    --end) END_DATE="${2:-}"; shift 2;;
    --bars) BARS=1; shift;;
    --csv) CSV_OUT="${2:-}"; shift 2;;
    --compare-prev) COMPARE_PREV=1; shift;;
    --score) SHOW_SCORE=1; shift;;
    --budget) BUDGET="${2:-}"; shift 2;;
    --guard) GUARD_MODE="${2:-forecast}"; shift 2;;
    --webhook) WEBHOOK="${2:-}"; shift 2;;
    --quiet) QUIET=1; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Arg desconocido: $1"; usage; exit 1;;
  esac
done

log() { [[ "$QUIET" -eq 1 ]] && return 0; echo -e "$*"; }

need() { command -v "$1" >/dev/null 2>&1; }

if ! need aws; then
  echo "ERROR: aws CLI no encontrado." >&2
  exit 1
fi

if [[ -n "$WEBHOOK" ]] && ! need curl; then
  echo "ERROR: 'curl' requerido para --webhook." >&2
  exit 1
fi

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
TODAY="$END_DATE"

# ----------------------------- Helpers --------------------------------------
# safe float compare using awk
f_gt() { awk -v a="$1" -v b="$2" 'BEGIN{exit !(a>b)}'; }
f_ge() { awk -v a="$1" -v b="$2" 'BEGIN{exit !(a>=b)}'; }

# month math (GNU date)
month_start() { date -d "$1" +%Y-%m-01; }
prev_month_start() { date -d "$(month_start "$1") -1 month" +%Y-%m-01; }
prev_month_end_excl() { month_start "$1"; }  # end is exclusive

# bars: 1 char per step (scales to max)
bar() {
  local val="$1" max="$2" width=25
  if awk -v m="$max" 'BEGIN{exit !(m<=0)}'; then
    echo ""
    return 0
  fi
  local n
  n=$(awk -v v="$val" -v m="$max" -v w="$width" 'BEGIN{printf "%d", (v/m)*w}')
  [[ "$n" -lt 0 ]] && n=0
  [[ "$n" -gt "$width" ]] && n="$width"
  printf "%0.s█" $(seq 1 "$n") 2>/dev/null || true
}

# cost explorer daily (Start inclusive, End exclusive)
ce_daily() {
  aws ce get-cost-and-usage \
    --time-period Start="$1",End="$2" \
    --granularity DAILY \
    --metrics UnblendedCost \
    --query 'ResultsByTime[*].[TimePeriod.Start,Total.UnblendedCost.Amount]' \
    --output text
}

ce_total_monthly() {
  aws ce get-cost-and-usage \
    --time-period Start="$1",End="$2" \
    --granularity MONTHLY \
    --metrics UnblendedCost \
    --query 'ResultsByTime[0].Total.UnblendedCost.Amount' \
    --output text
}

ce_top_services() {
  aws ce get-cost-and-usage \
    --time-period Start="$1",End="$2" \
    --granularity MONTHLY \
    --metrics UnblendedCost \
    --group-by Type=DIMENSION,Key=SERVICE \
    --query 'ResultsByTime[0].Groups[*].[Keys[0],Metrics.UnblendedCost.Amount]' \
    --output text | sort -k2 -nr | head -5
}

ce_top_usage() {
  aws ce get-cost-and-usage \
    --time-period Start="$1",End="$2" \
    --granularity MONTHLY \
    --metrics UnblendedCost \
    --group-by Type=DIMENSION,Key=USAGE_TYPE \
    --query 'ResultsByTime[0].Groups[*].[Keys[0],Metrics.UnblendedCost.Amount]' \
    --output text | sort -k2 -nr | head -5
}

# ----------------------------- Header ---------------------------------------
log "======================================================================="
log "🛡 FINOPS SENTINEL PRO v2 – ENTERPRISE"
log "Cuenta: $ACCOUNT_ID"
log "Periodo: $START_DATE → $END_DATE"
log "======================================================================="

# ----------------------------- 1) Daily table ------------------------------
DAILY="$(ce_daily "$START_DATE" "$END_DATE")"

TOTAL=0
MAX_DAY=""
MAX_VALUE=0
TODAY_VALUE=0
DAYS_COUNT=0

# For bars scaling
MAX_DAILY=0

# CSV header
if [[ -n "$CSV_OUT" ]]; then
  echo "date,usd" > "$CSV_OUT"
fi

# First pass to find max for bars + compute totals
while read -r D V; do
  [[ -z "${D:-}" ]] && continue
  V2="$(printf "%.2f" "$V")"
  TOTAL=$(awk -v t="$TOTAL" -v v="$V2" 'BEGIN{printf "%.2f", t+v}')
  DAYS_COUNT=$((DAYS_COUNT+1))

  if [[ "$D" == "$TODAY" ]]; then
    TODAY_VALUE="$V2"
  fi

  if f_gt "$V2" "$MAX_VALUE"; then
    MAX_VALUE="$V2"
    MAX_DAY="$D"
  fi

  if f_gt "$V2" "$MAX_DAILY"; then
    MAX_DAILY="$V2"
  fi

  if [[ -n "$CSV_OUT" ]]; then
    echo "$D,$V2" >> "$CSV_OUT"
  fi
done <<< "$DAILY"

# Prevent division by zero
if [[ "$DAYS_COUNT" -le 0 ]]; then
  echo "ERROR: No hay datos diarios (¿rango inválido?)." >&2
  exit 1
fi

AVG=$(awk -v t="$TOTAL" -v n="$DAYS_COUNT" 'BEGIN{printf "%.2f", t/n}')

# Forecast simple: promedio diario * 30 (como tu versión anterior)
FORECAST=$(awk -v a="$AVG" 'BEGIN{printf "%.2f", a*30}')

ANOMALY="NO"
if f_gt "$MAX_VALUE" "$(awk -v a="$AVG" 'BEGIN{printf "%.2f", a*3}')"; then
  ANOMALY="YES"
fi

log ""
log "📊 COSTO DIARIO"
printf "%-15s | %-8s%s\n" "FECHA" "USD" $([[ "$BARS" -eq 1 ]] && echo " | BARRA" || echo "")
printf "%s\n" "--------------------------------------------------------------------------"

while read -r D V; do
  [[ -z "${D:-}" ]] && continue
  V2="$(printf "%.2f" "$V")"
  if [[ "$BARS" -eq 1 ]]; then
    B="$(bar "$V2" "$MAX_DAILY")"
    printf "%-15s | %-8s | %s\n" "$D" "$V2" "$B"
  else
    printf "%-15s | %-8s\n" "$D" "$V2"
  fi
done <<< "$DAILY"

# ----------------------------- 2) Top Services / Usage ----------------------
TOP_SERVICES="$(ce_top_services "$START_DATE" "$END_DATE")"
TOP_USAGE="$(ce_top_usage "$START_DATE" "$END_DATE")"

# ----------------------------- 3) Compare vs prev month ---------------------
PREV_SUMMARY=""
DELTA_PCT=""
PREV_TOTAL=""

if [[ "$COMPARE_PREV" -eq 1 ]]; then
  # Compare same day-of-month window vs previous month:
  # prevStart = first day prev month
  # prevEnd   = prevStart + (DAYS_COUNT days)
  PREV_START="$(prev_month_start "$START_DATE")"
  PREV_END="$(date -d "$PREV_START + $DAYS_COUNT day" +%Y-%m-%d)"

  PREV_TOTAL="$(ce_total_monthly "$PREV_START" "$PREV_END")"
  PREV_TOTAL="$(printf "%.2f" "$PREV_TOTAL")"

  # Delta %
  if awk -v p="$PREV_TOTAL" 'BEGIN{exit !(p>0)}'; then
    DELTA_PCT=$(awk -v c="$TOTAL" -v p="$PREV_TOTAL" 'BEGIN{printf "%.1f", ((c-p)/p)*100}')
  else
    DELTA_PCT="N/A"
  fi

  PREV_SUMMARY="Mes anterior (mismo tramo): $PREV_START → $PREV_END | Total: $PREV_TOTAL USD | Δ%: $DELTA_PCT"
fi

# ----------------------------- 4) Score 0–100 ------------------------------
SCORE=""
SCORE_REASON=""

if [[ "$SHOW_SCORE" -eq 1 ]]; then
  # Simple scoring heuristic (transparente):
  # - Base 100
  # - -30 si hay anomalía
  # - -20 si hoy hay gasto > 0.01
  # - -25 si forecast >= budget (si budget definido y guard=forecast)
  # - -25 si total >= budget (si budget definido y guard=total)
  s=100
  if [[ "$ANOMALY" == "YES" ]]; then s=$((s-30)); fi
  if f_gt "$TODAY_VALUE" "0.01"; then s=$((s-20)); fi

  if [[ -n "$BUDGET" ]]; then
    BUDGET2="$(printf "%.2f" "$BUDGET")"
    if [[ "$GUARD_MODE" == "forecast" ]] && f_ge "$FORECAST" "$BUDGET2"; then s=$((s-25)); fi
    if [[ "$GUARD_MODE" == "total" ]] && f_ge "$TOTAL" "$BUDGET2"; then s=$((s-25)); fi
  fi

  [[ "$s" -lt 0 ]] && s=0
  SCORE="$s"

  SCORE_REASON="(100 base; -30 anomalía; -20 gasto hoy; -25 budget breach)"
fi

# ----------------------------- 5) Budget guard ------------------------------
ALERT="NO"
ALERT_MSG=""

if [[ -n "$BUDGET" ]]; then
  BUDGET2="$(printf "%.2f" "$BUDGET")"
  if [[ "$GUARD_MODE" == "forecast" ]] && f_ge "$FORECAST" "$BUDGET2"; then
    ALERT="YES"
    ALERT_MSG="Budget guard: FORECAST ($FORECAST) >= budget ($BUDGET2)"
  elif [[ "$GUARD_MODE" == "total" ]] && f_ge "$TOTAL" "$BUDGET2"; then
    ALERT="YES"
    ALERT_MSG="Budget guard: TOTAL ($TOTAL) >= budget ($BUDGET2)"
  fi
fi

# ----------------------------- Executive Summary ----------------------------
log ""
log "======================================================================="
log "📈 RESUMEN EJECUTIVO"
log "-----------------------------------------------------------------------"
printf "💰 Total acumulado: %s USD\n" "$TOTAL"
printf "📊 Promedio diario: %s USD\n" "$AVG"
printf "📅 Día mayor gasto: %s (%s USD)\n" "${MAX_DAY:-N/A}" "$MAX_VALUE"
printf "📆 Gasto hoy: %s USD\n" "$TODAY_VALUE"
printf "🔮 Forecast estimado mes: %s USD\n" "$FORECAST"
printf "🚨 Anomalía (>3x promedio): %s\n" "$ANOMALY"
if [[ "$COMPARE_PREV" -eq 1 ]]; then
  printf "📉 Comparación: %s\n" "$PREV_SUMMARY"
fi
if [[ "$SHOW_SCORE" -eq 1 ]]; then
  printf "🧮 Score FinOps: %s/100 %s\n" "$SCORE" "$SCORE_REASON"
fi

if f_gt "$TODAY_VALUE" "0.01"; then
  echo "⚠️  ALERTA: Hoy se está generando gasto."
else
  echo "✅ Hoy no hay gasto relevante."
fi

if [[ -n "$CSV_OUT" ]]; then
  echo "📦 CSV exportado: $CSV_OUT"
fi

if [[ "$ALERT" == "YES" ]]; then
  echo "🚨 BUDGET GUARD: $ALERT_MSG"
fi

log "======================================================================="

log ""
log "🏆 TOP SERVICIOS DEL PERIODO"
log "-----------------------------------------------------------------------"
if [[ -n "$TOP_SERVICES" ]]; then
  echo "$TOP_SERVICES" | awk '{printf "%-32s | %.2f USD\n",$1,$2}'
else
  echo "(sin datos)"
fi

log ""
log "🔎 TOP USAGE TYPES (origen técnico del gasto)"
log "-----------------------------------------------------------------------"
if [[ -n "$TOP_USAGE" ]]; then
  echo "$TOP_USAGE" | awk '{printf "%-45s | %.2f USD\n",$1,$2}'
else
  echo "(sin datos)"
fi

log ""
log "======================================================================="
log "🛡 FINOPS SENTINEL PRO v2 COMPLETADO – No destructivo"
log "======================================================================="
log ""

# ----------------------------- Webhook notify ------------------------------
if [[ -n "$WEBHOOK" ]]; then
  # Compact message for chat tools
  MSG="FINOPS SENTINEL PRO v2 | Acc:$ACCOUNT_ID | $START_DATE→$END_DATE | Total:$TOTAL USD | Hoy:$TODAY_VALUE USD | Pico:$MAX_DAY($MAX_VALUE) | Forecast:$FORECAST | Anom:$ANOMALY"
  if [[ "$COMPARE_PREV" -eq 1 ]]; then
    MSG="$MSG | Prev:$PREV_TOTAL USD (Δ%:$DELTA_PCT)"
  fi
  if [[ "$SHOW_SCORE" -eq 1 ]]; then
    MSG="$MSG | Score:$SCORE/100"
  fi
  if [[ "$ALERT" == "YES" ]]; then
    MSG="$MSG | ALERT:$ALERT_MSG"
  fi

  # Generic JSON payload (works for many webhooks; Slack incoming webhooks accept {"text":"..."}).
  curl -fsS -X POST -H "Content-Type: application/json" \
    -d "{\"text\":\"${MSG//\"/\\\"}\"}" \
    "$WEBHOOK" >/dev/null || true

  log "📨 Webhook enviado."
fi

