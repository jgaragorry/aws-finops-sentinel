#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# 📦 S3 STORAGE & INFRA-STATE AUDITOR (FinOps Edition)
# =============================================================================
# 📌 DESCRIPCIÓN:
#    Escanea todos los buckets S3 de la cuenta para verificar:
#    1. Existencia de Lifecycle Configuration (Crucial para ahorro).
#    2. Estado del Versionamiento (Protección de datos y control de costos).
#    3. [ANEXO] Integridad de Infraestructura (Específico para Terraform State).
#
# 🚀 OBJETIVO FINOPS:
#    - Identificar buckets que crecen indefinidamente (Falta de Lifecycle).
#    - [NUEVO] Garantizar que los buckets de ESTADO (TFSTATE) sean resilientes.
#
# 📊 QUÉ OBTIENES:
#    Una matriz de cumplimiento que separa el almacenamiento común del 
#    almacenamiento crítico de infraestructura.
#
# 🛡 SEGURIDAD:
#    - 100% IDEMPOTENTE y READ-ONLY.
# =============================================================================

usage() {
    grep '^# ' "$0" | cut -c 3-
    exit 0
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
fi

echo "================================================================"
echo "🎯 INICIANDO AUDITORÍA GLOBAL DE ALMACENAMIENTO S3"
echo "================================================================"

# 2. Obtener lista de todos los buckets
BUCKETS=$(aws s3api list-buckets --query 'Buckets[].Name' --output text)

# 3. Validación de contenido (Manejo de cuenta vacía)
if [[ -z "$BUCKETS" || "$BUCKETS" == "None" ]]; then
    echo -e "🟢 STATUS: No se detectaron buckets de S3 en esta cuenta."
    echo -e "💰 INFO: El consumo de almacenamiento es de 0.00 USD."
    echo "================================================================"
    echo "✔ Auditoría finalizada: Todo limpio."
    exit 0
fi

# 4. Cabecera de tabla
# [MEJORA]: Añadimos columna de "CRITICALITY" para diferenciar S3 normal de Infra
printf "%-40s | %-12s | %-12s | %-12s\n" "NOMBRE DEL BUCKET" "VERSIONING" "LIFECYCLE" "TIPO/RIESGO"
echo "---------------------------------------------------------------------------------------------------"

for BUCKET in $BUCKETS; do
    # 5. Verificar Versionamiento (Original)
    VER=$(aws s3api get-bucket-versioning --bucket "$BUCKET" --query 'Status' --output text)
    [[ "$VER" == "None" ]] && VER="Disabled"

    # 6. Verificar Lifecycle (Original)
    LIFECYCLE="✅ ACTIVE"
    if ! aws s3api get-bucket-lifecycle-configuration --bucket "$BUCKET" >/dev/null 2>&1; then
        LIFECYCLE="❌ MISSING"
    fi

    # 7. [ANEXO] Lógica de Certeza para Infraestructura
    # Identificamos si es el bucket de Terraform State (tfstate)
    TYPE="STANDARD"
    if [[ "$BUCKET" == *"tfstate"* ]]; then
        TYPE="🛠 INFRA"
        # Si es de infra y no tiene versionamiento, marcamos RIESGO CRÍTICO
        if [[ "$VER" != "Enabled" ]]; then
            TYPE="🚨 RISK_TF"
        fi
    fi

    printf "%-40s | %-12s | %-12s | %-12s\n" "$BUCKET" "$VER" "$LIFECYCLE" "$TYPE"
done

echo "================================================================"
echo "💡 RECOMENDACIÓN FINOPS:"
echo "1. Buckets con 'LIFECYCLE: MISSING' incrementan costos indefinidamente."
echo "2. Buckets con 'TYPE: RISK_TF' pueden causar pérdida total de IaC si se borra un archivo."
echo "================================================================"
