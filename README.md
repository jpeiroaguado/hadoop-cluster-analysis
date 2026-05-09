# Práctica 8.1 — Análisis Histórico del Clúster Hadoop y Predicción

> **Módulo:** IA i Big Data
> **Equipo:** Javier Peiro · Dennis
> **Curso:** 2025–2026

## 📋 Descripción

Análisis de métricas históricas del clúster Hadoop exportadas desde Prometheus,
almacenadas en Hive y utilizadas para generar predicciones de comportamiento
mediante regresión lineal en R.

Todo el stack es **100% dockerizado**: un único `docker compose up -d --build`
levanta todos los servicios en cualquier máquina sin configuración adicional.

---

## 🏗️ Arquitectura

```
Prometheus ──API──▶ export_prometheus.py ──CSV──▶ HDFS ──▶ Hive
                                                              │
                                                   HiveQL queries
                                                              │
                                               prediccion.R ──▶ Hive (predicciones_cluster)
                                                              │
                                                          Grafana
```

---

## 🧱 Servicios Docker

| Servicio           | Puerto | Descripción                          |
|--------------------|--------|--------------------------------------|
| nodo-principal     | 9000   | NameNode Hadoop + ResourceManager    |
| datanode1          | —      | DataNode 1                           |
| datanode2          | —      | DataNode 2                           |
| hive               | 10000  | HiveServer2                          |
| mysql              | 3306   | Metastore de Hive                    |
| prometheus         | 9090   | Recolección de métricas              |
| cadvisor           | 8080   | Exporter métricas de contenedores    |
| grafana            | 3000   | Visualización de dashboards          |
| prometheus-export  | —      | Contenedor Python exportador         |
| r-prediccion       | —      | Contenedor R con regresión lineal    |

---

## 🚀 Despliegue rápido

```bash
# 1. Clonar el repositorio
git clone https://github.com/equipo2/practica8-1.git
cd practica8-1

# 2. Levantar todo el stack
docker compose up -d --build

# 3. Esperar ~2 min a que Hive esté listo y ejecutar el pipeline
docker compose run prometheus-export   # Exporta métricas → Hive
docker compose run r-prediccion        # Calcula predicciones → Hive
```

> ⚠️ **Requisitos:** Docker ≥ 24.x · Docker Compose ≥ 2.x · 8 GB RAM mínimo
> Puertos necesarios libres: `9000`, `9090`, `3000`, `8080`, `10000`, `3306`

---

## 📁 Estructura del proyecto

```
practica8-1/
├── docker-compose.yml
├── prometheus/
│   └── prometheus.yml              # Targets de scrape (cadvisor, etc.)
├── scripts/
│   ├── Dockerfile                  # Imagen Python exportador
│   ├── export_prometheus.py        # Consulta API Prometheus → CSV
│   └── load_hive.sh                # Carga CSV en HDFS e inserta en Hive
├── hive/
│   ├── create_tables.hql           # DDL: metricas_cluster + predicciones_cluster
│   └── queries_analisis.hql        # Consultas análisis (medias, máximos, tendencias)
├── r-prediccion/
│   ├── Dockerfile                  # Imagen R con tidyverse + RHive
│   ├── prediccion.R                # Regresión lineal + inserción en Hive
│   └── graficas_prediccion.R       # Visualización con ggplot2 → PNG
├── grafana/
│   └── dashboards/
│       └── cluster_dashboard.json  # Dashboard listo para importar
└── informe/
    └── Practica8.1_Informe.pdf
```

---

## 📊 Parte 1 — Exportación de métricas a Hive

El contenedor `prometheus-export` ejecuta automáticamente al arrancarse:

1. Consulta `http://prometheus:9090/api/v1/query_range` para las métricas:
   - `container_cpu_usage_seconds_total`
   - `container_memory_usage_bytes`
   - `container_fs_usage_bytes`
2. Guarda los resultados en `/data/metricas.csv`
3. Sube el CSV a HDFS y ejecuta `LOAD DATA` en Hive

**Esquema de la tabla principal:**

```sql
CREATE TABLE metricas_cluster (
  timestamp   BIGINT,
  fecha       STRING,
  hora        STRING,
  contenedor  STRING,
  cpu_usage   DOUBLE,
  mem_usage   DOUBLE,
  disk_usage  DOUBLE
)
PARTITIONED BY (dia STRING)
STORED AS PARQUET;
```

---

## 🔍 Parte 2 — Análisis con HiveQL

```sql
-- Media de CPU por contenedor
SELECT contenedor, ROUND(AVG(cpu_usage), 4) AS media_cpu
FROM metricas_cluster
GROUP BY contenedor ORDER BY media_cpu DESC;

-- Nodo con mayor pico de RAM
SELECT contenedor, MAX(mem_usage) AS max_ram
FROM metricas_cluster
GROUP BY contenedor;

-- Tendencia de uso de disco por día
SELECT dia, SUM(disk_usage) AS disco_total
FROM metricas_cluster
GROUP BY dia ORDER BY dia;

-- Distribución de carga por hora del día
SELECT hora, AVG(cpu_usage) AS media_cpu
FROM metricas_cluster
GROUP BY hora ORDER BY hora;

-- Comparativa reposo vs carga (por contenedor)
SELECT contenedor,
       AVG(CASE WHEN cpu_usage < 0.1 THEN cpu_usage END) AS cpu_reposo,
       AVG(CASE WHEN cpu_usage >= 0.1 THEN cpu_usage END) AS cpu_carga
FROM metricas_cluster
GROUP BY contenedor;
```

---

## 🤖 Parte 3 — Predicción con R

El contenedor `r-prediccion` ejecuta `prediccion.R`:

- Lee la tabla `metricas_cluster` desde Hive vía JDBC
- Aplica regresión lineal: `cpu_usage ~ timestamp`
- Predice los próximos 7 días con intervalo de confianza
- Inserta los resultados en la tabla `predicciones_cluster` en Hive
- Genera `graficas_prediccion.png` con ggplot2

```r
# Núcleo del modelo
model <- lm(cpu_usage ~ timestamp, data = metricas)
future_ts <- seq(max(metricas$timestamp), by = 86400, length.out = 7)
predicciones <- predict(model,
                        newdata = data.frame(timestamp = future_ts),
                        interval = "confidence")
```

---

## 👥 Reparto de tareas

| Tarea                                            | Responsable |
|--------------------------------------------------|-------------|
| Script Python exportación Prometheus → Hive      | Javier      |
| DDL tablas Hive + dockerización exportador       | Javier      |
| Consultas HiveQL análisis completo               | Javier      |
| Dashboard Grafana con métricas del clúster       | Javier      |
| Script R regresión lineal + dockerización        | Javier      |
| Inserción predicciones en Hive                   | Javier      |
| Ejecución de queries y capturas de resultados    | Dennis      |
| Consultas complementarias (carga por hora, etc.) | Dennis      |
| Redacción sección análisis del informe (Parte 2) | Dennis      |
| Validación modelo R + gráficas ggplot2           | Dennis      |
| Conclusiones                                     | Ambos       |

---

## 🌿 Flujo de trabajo Git

```
main
 ├── feature/javier   → Scripts, DDL, modelo R, Dockerfiles
 └── feature/dennis   → Consultas complementarias, validación, informe
```

- Cada miembro trabaja en su rama y abre una **Pull Request** a `main`
- El otro miembro revisa antes de hacer merge
- Commits descriptivos: `feat: add export_prometheus.py`, `fix: hive table ddl`

---

## 📄 Licencia

Proyecto académico — CFGS IA i Big Data 2025–2026
