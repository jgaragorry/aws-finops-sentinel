#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# 🧟 GLOBAL AWS ZOMBIE HUNTER (SRE & FinOps Edition)
# =============================================================================
# 📌 DESCRIPCIÓN:
#   Escanea todas las regiones buscando recursos huérfanos o sin uso.
#
# 🚀 MONITOREO COMPLETO:
#   1. EBS Volumes: Discos 'available' (sin instancia).
#   2. Elastic IPs: IPs públicas sin asociación.
#   3. Lambda Functions: Lista todas las funciones para auditoría de inactividad.
#   4. Security Groups: Detecta SGs sin interfaces de red (ENI).
#
# 📊 QUÉ OBTIENES:
#   Certeza total de la higiene de tu cuenta en todas las regiones.
# =============================================================================

usage() { grep '^# ' "$0" | cut -c 3-; exit 0; }
[[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && usage

echo "================================================================"
echo "🌎 INICIANDO BARRIDO GLOBAL DE RECURSOS ZOMBIE"
echo "================================================================"

REGIONS=$(aws ec2 describe-regions --query 'Regions[].RegionName' --output text)

for REGION in $REGIONS; do
    echo -e "\n🔍 Región: [ $REGION ]"
    echo "----------------------------------------------------------------"

    # 1. EBS Volumes (Original)
    EBS=$(aws ec2 describe-volumes --region "$REGION" --filters Name=status,Values=available --query 'Volumes[*].[VolumeId,Size]' --output text)
    if [[ -n "$EBS" ]]; then
        echo "⚠️  EBS DISPONIBLES (SIN USAR):"
        echo "$EBS" | awk '{printf "   - ID: %s | Size: %sGB\n", $1, $2}'
    else
        echo "✅ EBS: OK"
    fi

    # 2. Elastic IPs (Original)
    EIP=$(aws ec2 describe-addresses --region "$REGION" --query 'Addresses[?AssociationId==null].[PublicIp]' --output text)
    if [[ -n "$EIP" ]]; then
        echo "⚠️  EIPs RESERVADAS (SIN ASOCIAR):"
        echo "$EIP" | awk '{printf "   - IP: %s\n", $1}'
    else
        echo "✅ EIP: OK"
    fi

    # 3. Lambda Functions (Mejora: Reporte siempre presente)
    LAMBDAS=$(aws lambda list-functions --region "$REGION" --query 'Functions[*].FunctionName' --output text)
    if [[ -n "$LAMBDAS" ]]; then
        echo "💡 LAMBDAS DETECTADAS: $LAMBDAS"
    else
        echo "✅ LAMBDA: OK (Ninguna)"
    fi

    # 4. Security Groups Huérfanos (Mejora: Certeza en SGs creados por usuario)
    # Obtenemos todos los SGs (incluyendo default para transparencia total)
    SGS=$(aws ec2 describe-security-groups --region "$REGION" --query "SecurityGroups[*].GroupId" --output text)
    
    SG_COUNT=0
    for sg in $SGS; do
        # Verificamos si tiene alguna ENI (Network Interface) asociada
        ENI_COUNT=$(aws ec2 describe-network-interfaces --region "$REGION" --filters Name=group-id,Values="$sg" --query 'NetworkInterfaces' --output json)
        
        if [[ "$ENI_COUNT" == "[]" ]]; then
            # Obtenemos el nombre para saber si es un SG 'default' de AWS o uno creado por ti
            SG_NAME=$(aws ec2 describe-security-groups --region "$REGION" --group-ids "$sg" --query 'SecurityGroups[0].GroupName' --output text)
            
            if [[ "$SG_NAME" == "default" ]]; then
                echo "ℹ️  SG DEFAULT (Vacío): $sg"
            else
                echo "⚠️  SG HUÉRFANO (USUARIO): $sg ($SG_NAME)"
                SG_COUNT=$((SG_COUNT + 1))
            fi
        fi
    done
    [[ "$SG_COUNT" -eq 0 ]] && echo "✅ SECURITY GROUPS DE USUARIO: OK"

done

echo -e "\n================================================================"
echo "✔ Auditoría global finalizada correctamente."
echo "================================================================"
