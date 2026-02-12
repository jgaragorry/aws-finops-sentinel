#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# FINOPS SENTINEL PRO v2 – ENTERPRISE EDITION (AWS Cost Explorer)
# =============================================================================
#
# 100% Read-Only FinOps Forensics Toolkit
# Account ID oculto por defecto (usar --show-account para mostrar)
# =============================================================================

# ----------------------------- Args / Defaults ------------------------------

START_DATE="$(date +%Y-%m-01)"
END_DATE="$(date +%Y-%m-%d)"
BARS=0
CSV_OUT=""
COMPARE_PREV=0
SHOW_SCORE=0
BUDGET=""
GUARD_MODE="forecast"
WEBHOOK=""
QUIET=0
SHOW_ACCOUNT=0

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
  --show-account
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
    --show-account) SHOW_ACCOUNT=1; shift;;
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

if [[ "$SHOW_ACCOUNT" -eq 1 ]]; then
  ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
else
  ACCOUNT_ID="(oculta)"
fi

TODAY="$END_DATE"

# ----------------------------- Helpers --------------------------------------

f_gt() { awk -v a="$1" -v b="$2" 'BEGIN{exit !(a>b)}'; }
f_ge() { awk -v a="$1" -v b="$2" 'BEGIN{exit !(a>=b)}'; }

month_start() { date -d "$1" +%Y-%m-01; }
prev_month_start() { date -d "$(month_start "$1") -1 month" +%Y-%m-01; }

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

# ----------------------------- Daily Table ----------------------------------

DAILY="$(ce_daily "$START_DATE" "$END_DATE")"

TOTAL=0
MAX_DAY=""
MAX_VALUE=0
TODAY_VALUE=0
DAYS_COUNT=0
MAX_DAILY=0

if [[ -n "$CSV_OUT" ]]; then
  echo "date,usd" > "$CSV_OUT"
fi

while read -r D V; do
  [[ -z "${D:-}" ]] && continue
  V2="$(printf "%.2f" "$V")"

  TOTAL=$(awk -v t="$TOTAL" -v v="$V2" 'BEGIN{printf "%.2f", t+v}')
  DAYS_COUNT=$((DAYS_COUNT+1))

  [[ "$D" == "$TODAY" ]] && TODAY_VALUE="$V2"

  if f_gt "$V2" "$MAX_VALUE"; then
    MAX_VALUE="$V2"
    MAX_DAY="$D"
  fi

  if f_gt "$V2" "$MAX_DAILY"; then
    MAX_DAILY="$V2"
  fi

  [[ -n "$CSV_OUT" ]] && echo "$D,$V2" >> "$CSV_OUT"

done <<< "$DAILY"

[[ "$DAYS_COUNT" -le 0 ]] && { echo "ERROR: No hay datos."; exit 1; }

AVG=$(awk -v t="$TOTAL" -v n="$DAYS_COUNT" 'BEGIN{printf "%.2f", t/n}')
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
    printf "%-15s | %-8s | %s\n" "$D" "$V2" "$(bar "$V2" "$MAX_DAILY")"
  else
    printf "%-15s | %-8s\n" "$D" "$V2"
  fi
done <<< "$DAILY"

TOP_SERVICES="$(ce_top_services "$START_DATE" "$END_DATE")"
TOP_USAGE="$(ce_top_usage "$START_DATE" "$END_DATE")"

log ""
log "======================================================================="
log "📈 RESUMEN EJECUTIVO"
log "-----------------------------------------------------------------------"
printf "💰 Total acumulado: %s USD\n" "$TOTAL"
printf "📊 Promedio diario: %s USD\n" "$AVG"
printf "📅 Día mayor gasto: %s (%s USD)\n" "${MAX_DAY:-N/A}" "$MAX_VALUE"
printf "📆 Gasto hoy: %s USD\n" "${TODAY_VALUE:-0.00}"
printf "🔮 Forecast estimado mes: %s USD\n" "$FORECAST"
printf "🚨 Anomalía (>3x promedio): %s\n" "$ANOMALY"

log "======================================================================="

log ""
log "🏆 TOP SERVICIOS DEL PERIODO"
log "-----------------------------------------------------------------------"
echo "$TOP_SERVICES" | awk '{printf "%-32s | %.2f USD\n",$1,$2}'

log ""
log "🔎 TOP USAGE TYPES (origen técnico del gasto)"
log "-----------------------------------------------------------------------"
echo "$TOP_USAGE" | awk '{printf "%-45s | %.2f USD\n",$1,$2}'

log ""
log "======================================================================="
log "🛡 FINOPS SENTINEL PRO v2 COMPLETADO – No destructivo"
log "======================================================================="

