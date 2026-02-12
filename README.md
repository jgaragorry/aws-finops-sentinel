# AWS FinOps Sentinel 🛡️

![AWS](https://img.shields.io/badge/AWS-CostExplorer-orange)
![Mode](https://img.shields.io/badge/Mode-ReadOnly-green)
![FinOps](https://img.shields.io/badge/FinOps-Forensics-blue)
![License](https://img.shields.io/badge/License-MIT-lightgrey)

### Zero-Cost / Cost Forensics Toolkit for AWS

Toolkit de scripts **100% no destructivos** para auditar costos en AWS usando **Cost Explorer** y detectar:

- Picos inesperados
- Gasto diario real
- Servicios dominantes
- UsageTypes técnicos (forense)
- Proyección mensual (forecast)
- Anomalías (>3x promedio)

---

## 🎯 Objetivo

Este proyecto nace para resolver una pregunta muy común en Cloud:

> "¿De dónde salió este gasto?"

Permite:

- Identificar **qué día exacto** comenzó el gasto
- Detectar el **servicio responsable**
- Ver el **origen técnico (UsageType)**
- Estimar cierre mensual
- Validar limpieza post-destrucción de infraestructura

---

## 🧩 Cómo Funciona

El toolkit utiliza la API de AWS Cost Explorer (`ce:GetCostAndUsage`) para:

1. Extraer costos diarios.
2. Agrupar por servicio.
3. Analizar UsageTypes.
4. Detectar anomalías relativas.
5. Calcular forecast mensual.

No utiliza CloudWatch, Billing Console scraping ni requiere agentes.

---

## 📦 Scripts incluidos

### 1) `scripts/cost-daily-table.sh`

Tabla diaria legible con 2 decimales:

- Total del período
- Día con mayor gasto
- Gasto de hoy
- Clasificación visual (OK / MEDIO / ALTO)

**Uso:**
```bash
bash scripts/cost-daily-table.sh

# Rango personalizado:
bash scripts/cost-daily-table.sh --start 2026-02-01 --end 2026-02-12
```

### 2) `scripts/finops-sentinel-enterprise.sh`

Auditoría FinOps Enterprise en un solo comando. Incluye:

- Tabla diaria
- Resumen ejecutivo
- Forecast mensual
- Top servicios
- Top UsageTypes (forense)
- Detección automática de anomalías
- Export CSV opcional
- Budget guard opcional
- Webhook opcional (Slack/Telegram)

**Uso básico:**
```bash
bash scripts/finops-sentinel-enterprise.sh

# Con barras ASCII y export CSV:
bash scripts/finops-sentinel-enterprise.sh --bars --csv ./out

# Con Budget Guard:
bash scripts/finops-sentinel-enterprise.sh --budget 20 --guard forecast
```

### 3) `scripts/lab-cost-stopwatch.sh`

Cronómetro visual para laboratorios. Ideal para:

- EKS labs
- NAT Gateway tests
- Load Balancer prácticas
- Cualquier entorno que facture por hora

**Uso:**
```bash
bash scripts/lab-cost-stopwatch.sh

# Detener con: CTRL + C
```

---

## 🔐 Requisitos

- AWS CLI v2 configurado
- Permiso IAM mínimo: `ce:GetCostAndUsage` y `sts:GetCallerIdentity`

**Verificación:**
```bash
aws sts get-caller-identity
```

## 🚀 Quick Demo

```bash
aws sts get-caller-identity
bash scripts/cost-daily-table.sh
mkdir -p out && bash scripts/finops-sentinel-enterprise.sh --bars --csv out/daily.csv

---

## ⚠️ Disclaimer

Este proyecto es únicamente para análisis y auditoría.
No ejecuta acciones destructivas ni modifica recursos.
El autor no se responsabiliza por decisiones de eliminación basadas en estos reportes.

---

## 🛡️ Seguridad

- Scripts **NO modifican recursos**
- 100% modo lectura
- Outputs (csv/json/log) excluidos vía `.gitignore`
- No incluye credenciales
- No almacena Account IDs

**Recomendación:** Usar inicialmente en cuentas de laboratorio o con perfiles dedicados.

---

## 📈 Casos de Uso Reales

- Validación post-destrucción de infraestructura
- Detección de NAT Gateways olvidados
- Identificación de EKS control plane activos
- Investigación de picos en AWS Budgets
- Auditoría FinOps mensual

---

## 🏗 Arquitectura Técnica

El toolkit se basa exclusivamente en:

- AWS Cost Explorer API
- CLI nativa de AWS
- Procesamiento local con bash + awk

No requiere:
- Agentes
- CloudWatch scraping
- SDK externos
- Infraestructura adicional

Diseñado para ser portable, minimalista y seguro.
---

## 📄 Licencia

MIT License

---

## 🤝 Autor

**Jose Garagorry**  
Cloud / DevSecOps / FinOps Engineer

- LinkedIn: https://www.linkedin.com/in/jgaragorry/
- GitHub: https://github.com/jgaragorry/
