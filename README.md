# Pràctica 8.1 — Anàlisi Històric del Clúster Hadoop i Predicció

> **Mòdul:** IA i Big Data
> **Equip:** [Javier Peiro](https://github.com/jpeiroaguado) · [Dennis Eckerskorn](https://github.com/DennisEckerskorn)
> **Centre:** IES La Mar de Xàbia
> **Curs:** 2025–2026

## 📋 Descripció

Anàlisi de mètriques històriques del clúster Hadoop exportades des de Prometheus,
emmagatzemades a Hive i usades per generar prediccions de comportament
mitjançant regressió lineal en R.

Tot l'stack és **100% dockeritzat**: un únic `docker compose up -d --build`
aixeca tots els serveis en qualsevol màquina sense configuració addicional.
Les dades s'autogeneren en l'arrancada gràcies al servei `data-generator`.

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

## 🧱 Serveis Docker

| Servei | Port | Descripció |
|---|---:|---|
| nodo-principal | 9000 | NameNode Hadoop + ResourceManager |
| datanode1 | — | DataNode 1 |
| datanode2 | — | DataNode 2 |
| hive | 10000 | HiveServer2 |
| mysql | 3306 | Base de dades + Metastore de Hive |
| data-generator | — | Genera els 7M de registres d'electricitat |
| prometheus | 9090 | Recol·lecció de mètriques |
| cadvisor | 8080 | Exporter mètriques de contenidors |
| grafana | 3000 | Visualització de dashboards |
| prometheus-export | — | Contenidor Python exportador |
| r-prediccion | — | Contenidor R amb regressió lineal |

---

## 🚀 Desplegament ràpid

```bash
# 1. Clonar el repositori
git clone https://github.com/jpeiroaguado/hadoop-cluster-analysis.git
cd hadoop-cluster-analysis

# 2. Aixecar tot l'stack i seguir el log del generador de dades
docker compose up -d --build && docker logs -f generador-datos

```

> ⚠️ **Requisits:** Docker ≥ 24.x · Docker Compose ≥ 2.x · 8 GB RAM mínim  
> Ports necessaris lliures: `9000`, `9090`, `3000`, `8080`, `10000`, `3306`

---

## 📁 Estructura del projecte

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
│   ├── generando_datos.py          # Genera 7M de registres d'electricitat
│   ├── Dockerfile                  # Imatge Python exportador Prometheus
│   ├── export_prometheus.py        # Consulta API Prometheus → CSV → Hive
│   └── load_hive.sh                # Carrega CSV a HDFS i insereix a Hive
├── hive/
│   ├── create_tables.hql           # DDL: metricas_cluster + predicciones_cluster
│   └── queries_analisis.hql        # Consultes anàlisi (mitjanes, màxims, tendències)
├── init-scripts/
│   ├── hive-init.sh
│   ├── mysql-loader.sh
│   └── sqoop-init.sh
├── r-prediccion/
│   ├── Dockerfile                  # Imatge R amb tidyverse + RHive
│   ├── prediccion.R                # Regressió lineal + inserció a Hive
│   └── graficas_prediccion.R       # Visualització amb ggplot2 → PNG
├── grafana/
│   └── dashboards/
│       └── cluster_dashboard.json  # Dashboard llest per importar
└── informe/
    └── Practica8.1_Informe.pdf
```

---

## 👥 Repartiment de tasques

El projecte es divideix en **dues branques independents** que s'integren a `main` via Pull Request.

---

### 🧑‍💻 Javier — `feature/javier`

> Infraestructura, pipeline de dades i model predictiu

**Part 1 — Exportació de mètriques a Hive**
- Script Python `export_prometheus.py`: consulta l'API de Prometheus i exporta `cpu_usage`, `mem_usage` i `disk_usage` a CSV
- Script `load_hive.sh`: puja el CSV a HDFS i fa `LOAD DATA` a Hive
- DDL de la taula `metricas_cluster` (particionada per dia, format Parquet)
- Dockerització del servei `prometheus-export`

**Part 2 — Anàlisi amb HiveQL**
- Consultes de mitjanes, màxims i tendències temporals
- Identificació dels contenidors més carregats (CPU/RAM)
- Anàlisi del creixement d'emmagatzematge HDFS
- Dashboard Grafana amb els resultats visualitzats

**Part 3 — Predicció amb R**
- Script `prediccion.R`: regressió lineal `cpu_usage ~ timestamp`
- Predicció dels pròxims 7 dies amb interval de confiança
- Inserció dels resultats a la taula `predicciones_cluster` a Hive
- Dockerfile del contenidor R amb totes les dependències

**Part 4 — Conclusions de Javier**

---

### 🧑‍💻 Dennis — `feature/dennis`

> Anàlisi, validació i redacció de l'informe

**Part 2 — Anàlisi complementari**
- Executar totes les consultes de Javier i capturar els resultats amb screenshots
- Escriure consultes pròpies addicionals:
  - Distribució de càrrega per hora del dia
  - Comparativa repòs vs càrrega per contenidor
- Redactar la secció d'anàlisi de l'informe (Part 2): interpretar els pics, identificar el coll d'ampolla, comparar nodes

**Part 3 — Validació del model**
- Verificar que les prediccions del model R tenen sentit
- Generar la versió visual del gràfic de predicció amb `ggplot2`
- Exportar el gràfic com a imatge per incloure-la a l'informe

**Part 4 — Conclusions de Dennis**
- Detectar problemes observats en les dades amb evidència
- Proposar millores concretes i justificades: ajust de memòria als contenidors, replication factor HDFS, particionament de taules Hive

---

## 🌿 Flux de treball Git

```text
main
 ├── feature/javier   → Scripts Python, DDL Hive, model R, Dockerfiles
 └── feature/dennis   → Consultes complementàries, validació, redacció informe
```

**Regles:**
1. Cada membre treballa exclusivament a la seua branca
2. Quan una part està llesta → obrir **Pull Request** a `main`
3. L'altre membre revisa i aprova abans de fer merge
4. Commits en format descriptiu:
   - `feat: add export_prometheus.py`
   - `feat: add hive DDL tables`
   - `fix: hive partition query`
   - `docs: add analysis section to report`

---

## 📊 Esquema de les taules Hive

```sql
-- Mètriques del clúster (Part 1)
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

-- Prediccions (Part 3)
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

## 📄 Llicència

Projecte acadèmic — CFGS IA i Big Data 2025–2026  
**IES La Mar de Xàbia**