# AWS FinOps Sentinel 🛡️

![AWS](https://img.shields.io/badge/AWS-CostExplorer-orange)
![Mode](https://img.shields.io/badge/Mode-SoloLectura-green)
![FinOps](https://img.shields.io/badge/FinOps-Gobernanza-blue)
![License](https://img.shields.io/badge/License-MIT-lightgrey)
![Version](https://img.shields.io/badge/version-v1.2.0-blue)

## Capa Ligera de Gobernanza FinOps para AWS

AWS FinOps Sentinel es una **capa ligera de gobernanza financiera (solo lectura)** diseñada para proporcionar visibilidad, análisis forense y control proactivo de costos en entornos AWS.

No es solo un conjunto de scripts.  
Es un enfoque práctico de **FinOps aplicado a ingeniería real**.

**Diseñado por un Cloud Architect con experiencia en gobernanza, seguridad ISO 27001 y control FinOps en entornos productivos.**

---

## 🏢 Posicionamiento Empresarial

Este proyecto puede utilizarse como:

- 🔍 Motor de análisis forense de costos
- 🚨 Sistema temprano de detección de anomalías
- 💰 Mecanismo de control presupuestario
- 🧠 Capa de validación financiera en CI/CD
- 📊 Componente de gobernanza cloud ligera

Diseñado para equipos:

- Cloud Engineering
- Platform Engineering
- DevOps / DevSecOps
- FinOps
- Arquitectura Empresarial

---

## 👥 Público Objetivo

- Cloud Architects
- FinOps Practitioners
- Platform Engineers
- CTOs en startups con control presupuestario limitado
- Equipos DevOps que requieren validación financiera en pipeline

---

## 🎯 Problema que Resuelve

En la mayoría de organizaciones, la visibilidad de costos es:

- Reactiva
- Dependiente de la Consola de Facturación
- Limitada a dashboards agregados

La pregunta crítica siempre aparece tarde:

> "¿De dónde salió este gasto?"

FinOps Sentinel permite:

- Identificar el **día exacto** donde comenzó el consumo
- Detectar el **servicio responsable**
- Analizar el **origen técnico (UsageType)**
- Estimar cierre mensual proyectado
- Validar limpieza post-destrucción de infraestructura

---

## 🧠 Enfoque Arquitectónico
```
Ingeniero / Pipeline CI
       ↓
FinOps Sentinel Layer
       ↓
AWS Cost Explorer API
       ↓
Decisión de Gobernanza
```

No requiere agentes.
No modifica recursos.
No accede a infraestructura.
Opera 100% en modo lectura.

---

## 🧩 Cómo Funciona

Utiliza la API `ce:GetCostAndUsage` de AWS Cost Explorer para:

1. Extraer costos diarios.
2. Agrupar por servicio.
3. Analizar UsageTypes (nivel técnico).
4. Detectar anomalías relativas (>3x promedio).
5. Calcular forecast mensual.
6. Evaluar riesgo presupuestario (Budget Guard).

---

## 📦 Componentes Incluidos

### 1️⃣ cost-daily-table.sh

Auditoría diaria ligera.

Entrega:

- Tabla diaria financiera (2 decimales)
- Día con mayor gasto
- Estado visual (OK / MEDIO / ALTO)
- Detección de consumo actual

Uso:
```bash
./scripts/cost-daily-table.sh
./scripts/cost-daily-table.sh --start 2026-02-01 --end 2026-02-12
```

### 2️⃣ finops-sentinel-enterprise.sh

Motor principal de gobernanza.

Incluye:

- Tabla diaria
- Resumen ejecutivo
- Forecast mensual
- Top servicios
- Top UsageTypes (nivel técnico)
- Comparación vs mes anterior
- Score FinOps (0–100)
- Budget Guard
- Export CSV
- Integración webhook
- Modo silencioso para CI/CD

Uso básico:
```bash
./scripts/finops-sentinel-enterprise.sh
```

### 3️⃣ lab-cost-stopwatch.sh

Herramienta educativa para concientización de costos en laboratorios.

Ideal para:

- EKS
- NAT Gateway
- Load Balancers
- Entornos efímeros

---

## 🚀 Demo Rápida (30 segundos)
```bash
aws sts get-caller-identity

./scripts/cost-daily-table.sh

mkdir -p out
./scripts/finops-sentinel-enterprise.sh --bars --csv out/daily.csv
```

---

## 🏗️ Escenarios Empresariales

### Executive FinOps Review
```bash
./scripts/finops-sentinel-enterprise.sh \
  --bars \
  --score \
  --compare-prev
```

Uso: comité financiero / revisión mensual.

### Budget Early Warning System
```bash
./scripts/finops-sentinel-enterprise.sh \
  --budget 1000 \
  --guard forecast
```

Uso: control preventivo antes de cierre mensual.

### CI/CD Financial Gate
```bash
./scripts/finops-sentinel-enterprise.sh \
  --quiet \
  --csv out/report.csv
```

Uso: paso de validación en pipeline.

### Cost Incident Investigation Mode
```bash
./scripts/finops-sentinel-enterprise.sh \
  --start 2026-01-01 \
  --end 2026-01-31 \
  --bars \
  --compare-prev \
  --score \
  --show-account
```

Uso: análisis post-incidente.

---

## 🔐 Seguridad

- 100% modo lectura
- No modifica recursos
- No requiere credenciales embebidas
- Account ID oculto por defecto
- Compatible con IAM de mínimo privilegio

Permisos mínimos:

- `ce:GetCostAndUsage`
- `sts:GetCallerIdentity`

---

## 📈 Casos Reales de Aplicación

- Validación post-destrucción de EKS
- Detección de NAT Gateways olvidados
- Identificación de control plane activo
- Auditoría mensual de consumo
- Gobernanza financiera ligera en startups y scale-ups

---

## ⚙️ Limitaciones Técnicas

- Depende de AWS Cost Explorer (datos con retraso de hasta 24h)
- No reemplaza AWS Budgets ni herramientas SaaS FinOps
- No ejecuta remediación automática
- No realiza análisis avanzado de tagging

---

## 🛣️ Roadmap (Visión Evolutiva)

Posibles extensiones futuras:

- Integración con AWS Budgets API
- Export JSON estructurado para SIEM / Data Lake
- Tag-based cost analysis
- Multi-account aggregation
- Versión Dockerizada
- GitHub Action oficial

---

## ⚠️ Aviso

Este proyecto es una herramienta de análisis.
No ejecuta acciones destructivas.
No reemplaza una plataforma FinOps completa.

---

## 👨‍💻 Autor

**Jose Garagorry**  
Cloud Architect | DevSecOps | FinOps Strategy

- LinkedIn: https://www.linkedin.com/in/jgaragorry/
- GitHub: https://github.com/jgaragorry/

---

## 📄 Licencia

MIT License
