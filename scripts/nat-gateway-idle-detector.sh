#!/bin/bash
# ==============================================================================
# SCRIPT: nat-gateway-idle-detector.sh
# DESCRIPCIÓN: Detecta NAT Gateways con tráfico nulo o residual (<1KB) en 24h.
# CUÁNDO USARLO: Auditorías semanales de red o limpieza de entornos Dev/Test.
# VALOR FINOPS: Elimina el cargo fijo por hora de Gateways inactivos.
# AUTOR: José Julio Garagorry Arias
# ==============================================================================

echo "----------------------------------------------------------------"
echo "🔍 [SENTINEL] Iniciando Auditoría de Tráfico en NAT Gateways..."
echo "----------------------------------------------------------------"

# Obtener todos los NAT Gateways en estado 'available'
NAT_GATEWAYS=$(aws ec2 describe-nat-gateways --filter "Name=state,Values=available" --query 'NatGateways[*].NatGatewayId' --output text)

if [ -z "$NAT_GATEWAYS" ]; then
    echo "✅ No se encontraron NAT Gateways activos en esta región."
    exit 0
fi

for NAT_ID in $NAT_GATEWAYS; do
    # Consultar CloudWatch por la métrica BytesOut en las últimas 24 horas
    BYTES_OUT=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/NATGateway \
        --metric-name BytesOut \
        --dimensions Name=NatGatewayId,Value=$NAT_ID \
        --start-time $(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%SZ) \
        --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
        --period 86400 \
        --statistics Sum \
        --query 'Datapoints[0].Sum' --output text)

    # Validar si el resultado es nulo o menor a 1024 bytes (1KB)
    if [ "$BYTES_OUT" == "None" ] || [ $(echo "$BYTES_OUT < 1024" | bc) -ne 0 ]; then
        echo "⚠️ ALERTA: NAT Gateway [$NAT_ID] está INACTIVO (Tráfico: ${BYTES_OUT:-0} bytes)."
        echo "👉 Acción: Validar si la VPC sigue en uso o si el Gateway puede ser eliminado."
    else
        echo "✅ NAT Gateway [$NAT_ID] está en uso activo (Tráfico: $BYTES_OUT bytes)."
    fi
done

echo "----------------------------------------------------------------"
echo "✅ Auditoría de Networking finalizada."
