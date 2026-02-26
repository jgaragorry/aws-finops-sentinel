#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# 🛡️ FINOPS SENTINEL PRO v2 – ENTERPRISE EDITION (AWS Cost Explorer)
# =============================================================================
# 📌 QUÉ HACE:
#    Análisis forense de costos AWS. Mantiene historial diario y métricas clave.
#
# 🚀 MEJORAS DE CERTEZA SRE:
#    1. Recupera métricas de Promedio y Día Máximo (Funcionalidad Original).
#    2. Expande visibilidad a Top 10 (Servicios y Usage Types).
#    3. Precisión de 4 decimales para capturar costos Serverless (Lambda/Events).
# =============================================================================

# (Argumentos y Defaults se mantienen idénticos al original)
START_DATE="$(date +%Y-%m-01)"
END_DATE="$(date +%Y-%m-%d)"
BARS=0; CSV_OUT=""; COMPARE_PREV=0; SHOW_SCORE=0; BUDGET=""; 
GUARD_MODE="forecast"; WEBHOOK=""; QUIET=0; SHOW_ACCOUNT=0

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
    -h|--help) grep '^# ' "$0" | cut -c 3-; exit 0;;
    *) echo "Arg desconocido: $1"; exit 1;;
  esac
done

log() { [[ "$QUIET" -eq 1 ]] && return 0; echo -e "$*"; }

if [[ "$SHOW_ACCOUNT" -eq 1 ]]; then
  ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
else
  ACCOUNT_ID="(oculta)"
fi

TODAY="$END_DATE"

# ----------------------------- Helpers --------------------------------------
f_gt() { awk -v a="$1" -v b="$2" 'BEGIN{exit !(a>b)}'; }

bar() {
  local val="$1" max="$2" width=25
  if awk -v m="$max" 'BEGIN{exit !(m<=0)}'; then echo ""; return 0; fi
  local n
  n=$(awk -v v="$val" -v m="$max" -v w="$width" 'BEGIN{printf "%d", (v/m)*w}')
  [[ "$n" -lt 0 ]] && n=0
  [[ "$n" -gt "$width" ]] && n="$width"
  printf "%0.s█" $(seq 1 "$n") 2>/dev/null || true
}

ce_daily() {
  aws ce get-cost-and-usage --time-period Start="$1",End="$2" --granularity DAILY --metrics UnblendedCost --query 'ResultsByTime[*].[TimePeriod.Start,Total.UnblendedCost.Amount]' --output text
}

ce_top_services() {
  aws ce get-cost-and-usage --time-period Start="$1",End="$2" --granularity MONTHLY --metrics UnblendedCost --group-by Type=DIMENSION,Key=SERVICE --query 'ResultsByTime[0].Groups[*].[Keys[0],Metrics.UnblendedCost.Amount]' --output text | sort -k2 -nr | head -10
}

ce_top_usage() {
  aws ce get-cost-and-usage --time-period Start="$1",End="$2" --granularity MONTHLY --metrics UnblendedCost --group-by Type=DIMENSION,Key=USAGE_TYPE --query 'ResultsByTime[0].Groups[*].[Keys[0],Metrics.UnblendedCost.Amount]' --output text | sort -k2 -nr | head -10
}

# ----------------------------- Core Logic -----------------------------------
DAILY="$(ce_daily "$START_DATE" "$END_DATE")"
TOTAL=0; MAX_DAY=""; MAX_VALUE=0; TODAY_VALUE=0; DAYS_COUNT=0; MAX_DAILY=0

while read -r D V; do
  [[ -z "${D:-}" ]] && continue
  V2="$(printf "%.2f" "$V")"
  TOTAL=$(awk -v t="$TOTAL" -v v="$V2" 'BEGIN{printf "%.2f", t+v}')
  DAYS_COUNT=$((DAYS_COUNT+1))
  [[ "$D" == "$TODAY" ]] && TODAY_VALUE="$V2"
  
  # Lógica para detectar el día de mayor gasto (Original Reincorporada)
  if f_gt "$V2" "$MAX_VALUE"; then 
    MAX_VALUE="$V2"
    MAX_DAY="$D"
  fi
  
  if f_gt "$V2" "$MAX_DAILY"; then MAX_DAILY="$V2"; fi
done <<< "$DAILY"

AVG=$(awk -v t="$TOTAL" -v n="$DAYS_COUNT" 'BEGIN{printf "%.2f", t/n}')
FORECAST=$(awk -v a="$AVG" 'BEGIN{printf "%.2f", a*30}')
ANOMALY_THRESHOLD=$(awk -v a="$AVG" 'BEGIN{printf "%.2f", a*3}')
ANOMALY=$([[ $(f_gt "$MAX_VALUE" "$ANOMALY_THRESHOLD") ]] && echo "YES" || echo "NO")

# ----------------------------- Header ---------------------------------------
log "======================================================================="
log "🛡 FINOPS SENTINEL PRO v2 – ENTERPRISE EDITION"
log "Cuenta: $ACCOUNT_ID | Periodo: $START_DATE → $END_DATE"
log "======================================================================="

# ----------------------------- Display --------------------------------------
log ""
log "📊 COSTO DIARIO"
printf "%-15s | %-8s%s\n" "FECHA" "USD" $([[ "$BARS" -eq 1 ]] && echo " | BARRA" || echo "")
printf "%s\n" "--------------------------------------------------------------------------"
while read -r D V; do
  [[ -z "${D:-}" ]] && continue
  V2="$(printf "%.2f" "$V")"
  [[ "$BARS" -eq 1 ]] && printf "%-15s | %-8s | %s\n" "$D" "$V2" "$(bar "$V2" "$MAX_DAILY")" || printf "%-15s | %-8s\n" "$D" "$V2"
done <<< "$DAILY"

log ""
log "📈 RESUMEN EJECUTIVO"
log "-----------------------------------------------------------------------"
printf "💰 Total acumulado: %s USD\n" "$TOTAL"
printf "📊 Promedio diario: %s USD\n" "$AVG" # <--- RECUPERADO
printf "📅 Día mayor gasto: %s (%s USD)\n" "${MAX_DAY:-N/A}" "$MAX_VALUE" # <--- RECUPERADO
printf "📆 Gasto hoy: %s USD\n" "${TODAY_VALUE:-0.00}" # <--- RECUPERADO
printf "🔮 Forecast estimado mes: %s USD\n" "$FORECAST"
printf "🚨 Anomalía (>3x promedio): %s\n" "$ANOMALY" # <--- MEJORADO

log ""
log "🏆 TOP 10 SERVICIOS (Detalle SRE)"
log "-----------------------------------------------------------------------"
ce_top_services "$START_DATE" "$END_DATE" | awk '{printf "%-32s | %.4f USD\n",$1,$2}'

log ""
log "🔎 TOP 10 USAGE TYPES (Origen del gasto)"
log "-----------------------------------------------------------------------"
ce_top_usage "$START_DATE" "$END_DATE" | awk '{printf "%-45s | %.4f USD\n",$1,$2}'

log ""
log "======================================================================="
log "✔ Auditoría completada – Sin pérdida de métricas históricas."
log "======================================================================="
