#!/bin/bash

# ==============================================================================
# ⏱️  AWS LABORATORY COST STOPWATCH (SRE & FinOps Edition)
# ==============================================================================
# 📌 DESCRIPCIÓN:
#    Proporciona visibilidad en tiempo real del gasto estimado por segundo.
#
# 🚀 COBERTURA DE COSTOS (TOTAL ESTIMADO: $0.2715 / hora):
#    - EKS Cluster (~$0.10/hr)
#    - Fargate/Nodes (~$0.16/hr)
#    - [ANEXO] Lambda + EventBridge + S3 + Logs (~$0.0058/hr)
#
# 📊 QUÉ OBTIENES:
#    Certeza del gasto acumulado para evitar sorpresas en la factura mensual.
# ==============================================================================

# Nueva tasa incluyendo la infraestructura de remediación automática
COST_PER_HOUR=0.2715
COST_PER_SECOND=$(echo "scale=10; $COST_PER_HOUR / 3600" | bc -l)

YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Validación de dependencia
if ! command -v bc &> /dev/null; then
    echo -e "${RED}ERROR: 'bc' no está instalado. Instálalo con: sudo apt install bc${NC}"
    exit 1
fi

start_time=$(date +%s)

# Función de salida para el trap (Original respetada y mejorada)
finalizar() {
    echo -e "\n\n${YELLOW}🏁 Cronómetro detenido.${NC}"
    echo -e "${CYAN}----------------------------------------------------------------${NC}"
    echo -e "👉 RECOMENDACIÓN SRE:"
    echo -e "1. Ejecuta 'terraform destroy' en la carpeta del lab."
    echo -e "2. Ejecuta './scripts/nuke_lab.sh' para limpiar recursos huérfanos."
    echo -e "3. Verifica el costo final con './scripts/cost-daily-table.sh'."
    echo -e "${CYAN}----------------------------------------------------------------${NC}"
    exit 0
}

# Capturar CTRL+C (SIGINT)
trap finalizar SIGINT

clear
echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}🚀 CRONÓMETRO DE COSTOS ACTIVADO - AWS SRE MULTI-LAB${NC}"
echo -e "${CYAN}================================================================${NC}"
echo -e "Monitorizando: EKS, Lambda, EventBridge y Almacenamiento S3."
echo -e "Presiona [CTRL+C] para detener e iniciar la destrucción."
echo ""

while true; do
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))
    
    # Formatear tiempo HH:MM:SS (Original intacto)
    printf -v timer "%02d:%02d:%02d" $((elapsed/3600)) $(( (elapsed%3600)/60 )) $((elapsed%60))
    
    # Calcular costo acumulado (Original intacto)
    total_cost=$(echo "scale=5; $elapsed * $COST_PER_SECOND" | bc -l)
    
    # Imprimir en la misma línea usando \r (Original intacto)
    printf "\r⏱️  TIEMPO: ${YELLOW}%s${NC} | 💸 GASTO ESTIMADO: ${GREEN}\$%s USD${NC}    " "$timer" "$total_cost"
    
    sleep 1
done
