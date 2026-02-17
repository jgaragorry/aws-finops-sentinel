#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# 📦 S3 STORAGE LIFECYCLE AUDITOR (FinOps Edition)
# =============================================================================
# 📌 DESCRIPCIÓN:
#    Escanea todos los buckets S3 de la cuenta para verificar:
#    1. Existencia de Lifecycle Configuration (Crucial para ahorro).
#    2. Estado del Versionamiento (Puede duplicar costos si no se gestiona).
#
# 🚀 OBJETIVO FINOPS:
#    Identificar buckets que crecen indefinidamente sin reglas de transición
#    a clases más baratas (Glacier) o borrado automático de temporales.
#
# 🛠 REQUISITOS:
#    - AWS CLI v2.
#    - Permisos: s3:ListAllMyBuckets, s3:GetLifecycleConfiguration.
#
# 📖 USO:
#    ./s3-storage-audit.sh          -> Ejecución completa.
#    ./s3-storage-audit.sh --help   -> Muestra esta ayuda.
#
# 🛡 SEGURIDAD:
#    - 100% IDEMPOTENTE y READ-ONLY.
# =============================================================================

usage() {
    grep '^# ' "$0" | cut -c 3-
    exit 0
}

# 1. Soporte para ayuda --help
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

# 4. Cabecera de tabla si existen buckets
printf "%-40s | %-12s | %-12s\n" "NOMBRE DEL BUCKET" "VERSIONING" "LIFECYCLE"
echo "--------------------------------------------------------------------------------"

for BUCKET in $BUCKETS; do
    # 5. Verificar Versionamiento
    VER=$(aws s3api get-bucket-versioning --bucket "$BUCKET" --query 'Status' --output text)
    [[ "$VER" == "None" ]] && VER="Disabled"

    # 6. Verificar Lifecycle (Manejo de error si no existe)
    LIFECYCLE="✅ ACTIVE"
    if ! aws s3api get-bucket-lifecycle-configuration --bucket "$BUCKET" >/dev/null 2>&1; then
        LIFECYCLE="❌ MISSING"
    fi

    printf "%-40s | %-12s | %-12s\n" "$BUCKET" "$VER" "$LIFECYCLE"
done

echo "================================================================"
echo "💡 RECOMENDACIÓN FINOPS:"
echo "Los buckets con 'LIFECYCLE: MISSING' deben ser revisados."
echo "Sin reglas de ciclo de vida, el costo de almacenamiento nunca dejará de crecer."
echo "================================================================"
