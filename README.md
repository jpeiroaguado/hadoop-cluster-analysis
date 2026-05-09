# Práctica 8.1 — Análisis Histórico del Clúster Hadoop y Predicción

> **Módulo:** IA i Big Data  
> **Equipo:** [Javier Peiro](https://github.com/jpeiroaguado) · [Dennis Eckerskorn](https://github.com/DennisEckerskorn)  
> **Centro:** IES La Mar de Xàbia  
> **Curso:** 2025–2026

## 📋 Descripción

Análisis de métricas históricas del clúster Hadoop exportadas desde Prometheus, almacenadas en Hive y usadas para generar predicciones de comportamiento mediante regresión lineal en R.

Todo el stack es **100% dockerizado**: un único `docker compose up -d --build` levanta todos los servicios en cualquier máquina sin configuración adicional.  
Los datos se autogeneran en el arranque gracias al servicio `data-generator`.

---

## 🏗️ Arquitectura

```text
data-generator ──▶ MySQL ──Sqoop──▶ HDFS ──▶ Hive
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

| Servicio | Puerto | Descripción |
|---|---:|---|
| nodo-principal | 9000 | NameNode Hadoop + ResourceManager |
| datanode1 | — | DataNode 1 |
| datanode2 | — | DataNode 2 |
| hive | 10000 | HiveServer2 |
| mysql | 3306 | Base de datos + Metastore de Hive |
| data-generator | — | Genera los 7M de registros de electricidad |
| prometheus | 9090 | Recolección de métricas |
| cadvisor | 8080 | Exporter métricas de contenedores |
| grafana | 3000 | Visualización de dashboards |
| prometheus-export | — | Contenedor Python exportador |
| r-prediccion | — | Contenedor R con regresión lineal |

---

## 🚀 Despliegue rápido

```bash
# 1. Clonar el repositorio
git clone https://github.com/jpeiroaguado/hadoop-cluster-analysis.git
cd hadoop-cluster-analysis

# 2. Levantar todo el stack y seguir el log del generador de datos
docker compose up -d --build && docker logs -f generador-datos
```

> ⚠️ **Requisitos:** Docker ≥ 24.x · Docker Compose ≥ 2.x · 8 GB RAM mínimo  
> Puertos necesarios libres: `9000`, `9090`, `3000`, `8080`, `10000`, `3306`

---

## 📁 Estructura del proyecto

```text
hadoop-cluster-analysis/
├── docker-compose.yml
├── Dockerfile
├── prometheus/
│   └── prometheus.yml              # Targets de scrape (cadvisor, etc.)
├── config/
│   ├── jmx-exporter.yml
│   ├── jmx_prometheus_javaagent.jar
│   └── mysql.cnf
├── scripts/
│   ├── generando_datos.py          # Genera 7M de registros de electricidad
│   ├── Dockerfile                  # Imagen Python exportador Prometheus
│   ├── export_prometheus.py        # Consulta API Prometheus → CSV → Hive
│   └── load_hive.sh                # Carga CSV en HDFS e inserta en Hive
├── hive/
│   ├── create_tables.hql           # DDL: metricas_cluster + predicciones_cluster
│   └── queries_analisis.hql        # Consultas análisis (medias, máximos, tendencias)
├── init-scripts/
│   ├── hive-init.sh
│   ├── mysql-loader.sh
│   └── sqoop-init.sh
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

## 👥 Reparto de tareas

El proyecto se divide en **dos ramas independientes** que se integran en `main` vía Pull Request.

### 🧑‍💻 Javier — `feature/javier`

> Infraestructura, pipeline de datos y modelo predictivo

**Parte 1 — Exportación de métricas a Hive**
- Script Python `export_prometheus.py`: consulta la API de Prometheus y exporta `cpu_usage`, `mem_usage` y `disk_usage` a CSV.
- Script `load_hive.sh`: sube el CSV a HDFS y ejecuta `LOAD DATA` en Hive.
- DDL de la tabla `metricas_cluster` (particionada por día, formato Parquet).
- Dockerización del servicio `prometheus-export`.

**Parte 2 — Análisis con HiveQL**
- Consultas de medias, máximos y tendencias temporales.
- Identificación de los contenedores más cargados (CPU/RAM).
- Análisis del crecimiento de almacenamiento HDFS.
- Dashboard Grafana con los resultados visualizados.

**Parte 3 — Predicción con R**
- Script `prediccion.R`: regresión lineal `cpu_usage ~ timestamp`.
- Predicción de los próximos 7 días con intervalo de confianza.
- Inserción de los resultados en la tabla `predicciones_cluster` en Hive.
- Dockerfile del contenedor R con todas las dependencias.

**Parte 4 — Conclusiones de Javier**

### 🧑‍💻 Dennis — `feature/dennis`

> Análisis, validación y redacción del informe

**Parte 2 — Análisis complementario**
- Ejecutar todas las consultas de Javier y capturar los resultados con screenshots.
- Escribir consultas propias adicionales:
  - Distribución de carga por hora del día.
  - Comparativa reposo vs carga por contenedor.
- Redactar la sección de análisis del informe (Parte 2): interpretar los picos, identificar el cuello de botella y comparar nodos.

**Parte 3 — Validación del modelo**
- Verificar que las predicciones del modelo R tienen sentido.
- Generar la versión visual del gráfico de predicción con `ggplot2`.
- Exportar el gráfico como imagen para incluirla en el informe.

**Parte 4 — Conclusiones de Dennis**
- Detectar problemas observados en los datos con evidencia.
- Proponer mejoras concretas y justificadas: ajuste de memoria en contenedores, replication factor HDFS y particionamiento de tablas Hive.

---

## 🌿 Flujo de trabajo Git

```text
main
 ├── feature/javier   → Scripts Python, DDL Hive, modelo R, Dockerfiles
 └── feature/dennis   → Consultas complementarias, validación, redacción informe
```

**Reglas:**
1. Cada miembro trabaja exclusivamente en su rama.
2. Cuando una parte está lista, abre una **Pull Request** a `main`.
3. El otro miembro revisa y aprueba antes de hacer merge.
4. Los commits deben seguir un formato descriptivo:
   - `feat: add export_prometheus.py`
   - `feat: add hive DDL tables`
   - `fix: hive partition query`
   - `docs: add analysis section to report`

---

## 📊 Esquema de las tablas Hive

```sql
-- Métricas del clúster (Parte 1)
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

-- Predicciones (Parte 3)
CREATE TABLE predicciones_cluster (
  fecha_prediccion  STRING,
  contenedor        STRING,
  cpu_predicted     DOUBLE,
  cpu_lower         DOUBLE,
  cpu_upper         DOUBLE
)
STORED AS PARQUET;
```

---

## 📄 Licencia

Proyecto académico — CFGS IA i Big Data 2025–2026  
**IES La Mar de Xàbia**