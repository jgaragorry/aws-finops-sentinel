#!/bin/bash
# ==============================================================================
# SCRIPT: old-snapshot-auditor.sh
# DESCRIPCIÓN: Identifica Snapshots EBS > 90 días sin etiqueta de retención.
# CUÁNDO USARLO: Limpieza mensual de backups y auditoría de cumplimiento.
# VALOR FINOPS: Optimiza el costo de almacenamiento EBS sin romper el compliance.
# AUTOR: José Julio Garagorry Arias
# ==============================================================================

# Definir fecha de corte (90 días atrás)
CUTOFF_DATE=$(date -d "90 days ago" +%Y-%m-%d)

echo "----------------------------------------------------------------"
echo "🔍 [SENTINEL] Buscando Snapshots antiguos (anteriores a $CUTOFF_DATE)..."
echo "⚠️ Nota: Se ignorarán los recursos con etiqueta 'Retention: Legal'."
echo "----------------------------------------------------------------"

# Listar snapshots propios creados antes de la fecha de corte
aws ec2 describe-snapshots --owner-ids self \
    --query "Snapshots[?StartTime<='$CUTOFF_DATE'].{ID:SnapshotId,Date:StartTime,Tags:Tags}" \
    --output json | jq -c '.[]' | while read -r snap; do
        
    SNAP_ID=$(echo $snap | jq -r '.ID')
    SNAP_DATE=$(echo $snap | jq -r '.Date')
    TAGS=$(echo $snap | jq -r '.Tags')

    # Verificar si NO tiene la etiqueta 'Retention: Legal'
    if [[ "$TAGS" != *"Retention"* ]] || [[ "$TAGS" != *"Legal"* ]]; then
        echo "🔴 CRÍTICO: Snapshot [$SNAP_ID] creado el [$SNAP_DATE] no tiene protección legal."
        echo "👉 Acción: Candidato para ELIMINAR para reducir costo de EBS Storage."
    else
        echo "🛡️ PROTEGIDO: Snapshot [$SNAP_ID] cumple con política de retención legal."
    fi
done

echo "----------------------------------------------------------------"
echo "✅ Auditoría de Almacenamiento finalizada."
