#!/bin/bash

# ==============================================================================
# ⏱️  AWS LABORATORY COST STOPWATCH (CORREGIDO)
# ==============================================================================
# TOTAL ESTIMADO: $0.2657 / hora
# ==============================================================================

COST_PER_HOUR=0.2657
COST_PER_SECOND=$(echo "scale=10; $COST_PER_HOUR / 3600" | bc -l)

YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
NC='\033[0m'

start_time=$(date +%s)

# Función de salida para el trap
finalizar() {
    echo -e "\n${YELLOW}🏁 Cronómetro detenido. ¡No olvides ejecutar el script de destrucción!${NC}"
    exit 0
}

# Capturar CTRL+C (SIGINT)
trap finalizar SIGINT

clear
echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}🚀 CRONÓMETRO DE COSTOS ACTIVADO - LABORATORIO EKS n8n${NC}"
echo -e "${CYAN}================================================================${NC}"
echo -e "Presiona [CTRL+C] para detener cuando inicies la destrucción."
echo ""

while true; do
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))
    
    # Formatear tiempo HH:MM:SS
    printf -v timer "%02d:%02d:%02d" $((elapsed/3600)) $(( (elapsed%3600)/60 )) $((elapsed%60))
    
    # Calcular costo acumulado
    total_cost=$(echo "scale=5; $elapsed * $COST_PER_SECOND" | bc -l)
    
    # Imprimir en la misma línea usando \r
    printf "\r⏱️  TIEMPO: ${YELLOW}%s${NC} | 💸 GASTO ESTIMADO: ${GREEN}\$%s USD${NC}    " "$timer" "$total_cost"
    
    sleep 1
done
