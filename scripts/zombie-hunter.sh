#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# 🧟 GLOBAL AWS ZOMBIE HUNTER (FinOps Edition)
# =============================================================================
# 📌 DESCRIPCIÓN:
#    Escanea recursivamente todas las regiones de AWS habilitadas en la cuenta
#    en busca de recursos huérfanos que generan costos innecesarios.
#
# 🚀 DETECTA:
#    1. EBS Volumes: Discos en estado 'available' (sin montar).
#    2. Elastic IPs: Direcciones IP públicas sin asociación (penalización horaria).
#
# 🛠 REQUISITOS:
#    - AWS CLI v2 configurado.
#    - Permisos IAM: ec2:DescribeRegions, ec2:DescribeVolumes, ec2:DescribeAddresses.
#
# 📖 USO:
#    ./zombie-hunter.sh          -> Ejecución estándar (todas las regiones).
#    ./zombie-hunter.sh --help   -> Muestra esta ayuda.
#
# 🛡 SEGURIDAD:
#    - Modo 100% LECTURA (Read-Only). No destruye ni modifica recursos.
# =============================================================================

usage() {
    grep '^# ' "$0" | cut -c 3-
    exit 0
}

# Verificar si el usuario pide ayuda
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
fi

echo "================================================================"
echo "🌎 INICIANDO BARRIDO GLOBAL DE RECURSOS ZOMBIE"
echo "================================================================"

# 1. Obtener solo las regiones donde la cuenta tiene permiso de operar
REGIONS=$(aws ec2 describe-regions --query 'Regions[].RegionName' --output text)

for REGION in $REGIONS; do
    echo -e "\n🔍 Región: [ $REGION ]"
    echo "----------------------------------------------------------------"

    # 2. EBS Volumes en estado 'available'
    EBS=$(aws ec2 describe-volumes --region "$REGION" \
        --filters Name=status,Values=available \
        --query 'Volumes[*].[VolumeId,Size]' --output text)

    if [[ -n "$EBS" ]]; then
        echo "⚠️  EBS DISPONIBLES (SIN USAR):"
        echo "$EBS" | awk '{printf "   - ID: %s | Size: %sGB\n", $1, $2}'
    else
        echo "✅ EBS: OK"
    fi

    # 3. Elastic IPs sin asociación
    EIP=$(aws ec2 describe-addresses --region "$REGION" \
        --query 'Addresses[?AssociationId==null].[PublicIp]' --output text)

    if [[ -n "$EIP" ]]; then
        echo "⚠️  EIPs RESERVADAS (SIN ASOCIAR):"
        echo "$EIP" | awk '{printf "   - IP: %s\n", $1}'
    else
        echo "✅ EIP: OK"
    fi
done

echo -e "\n================================================================"
echo "✔ Auditoría global finalizada correctamente."
echo "================================================================"
