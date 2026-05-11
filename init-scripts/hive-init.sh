#!/bin/bash
# hive-init.sh

set -e

HIVE_URI="jdbc:hive2://hive2:10000/"
HDFS_URI="hdfs://Nodo-principal2:9000"
CSV_LOCAL="/data/metricas_cluster.csv"
CSV_PRED="/data/predicciones_javier.csv"
HDFS_METRICAS="${HDFS_URI}/user/hive/metricas_cluster"
HDFS_PRED="${HDFS_URI}/user/hive/predicciones_cluster"

echo ">>> Esperando HiveServer2..."
until beeline -u "${HIVE_URI}" -e "SHOW DATABASES;" > /dev/null 2>&1; do
    echo "    HiveServer2 no listo, esperando 15s..."
    sleep 15
done
echo ">>> HiveServer2 listo."

# ─────────────────────────────────────────────────────────────────────
# TABLA ORIGINAL: electric_data (Dennis / Sqoop)
# ─────────────────────────────────────────────────────────────────────
echo ">>> Creando tabla electric_data..."
beeline -u "${HIVE_URI}" -e "
CREATE EXTERNAL TABLE IF NOT EXISTS electric_data (
    consumo     DOUBLE,
    fecha       STRING,
    generacion  DOUBLE,
    hora_dia    INT,
    idexcel     INT,
    Poblacion   STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '${HDFS_URI}/user/root/electric_data_sqoop';
"
echo ">>> Tabla electric_data creada."

# ─────────────────────────────────────────────────────────────────────
# ESPERAR CSV DE MÉTRICAS
# ─────────────────────────────────────────────────────────────────────
echo ">>> Esperando CSV de métricas en ${CSV_LOCAL}..."
for i in $(seq 1 30); do
    if [ -f "${CSV_LOCAL}" ]; then
        echo "    CSV métricas encontrado."
        break
    fi
    echo "    Intento $i/30 - esperando 10s..."
    sleep 10
done

if [ ! -f "${CSV_LOCAL}" ]; then
    echo "ERROR: No se encontró ${CSV_LOCAL}. Abortando."
    exit 1
fi

# ─────────────────────────────────────────────────────────────────────
# ESPERAR CSV DE PREDICCIONES
# ─────────────────────────────────────────────────────────────────────
echo ">>> Esperando CSV de predicciones en ${CSV_PRED}..."
for i in $(seq 1 30); do
    if [ -f "${CSV_PRED}" ]; then
        echo "    CSV predicciones encontrado."
        break
    fi
    echo "    Intento $i/30 - esperando 10s..."
    sleep 10
done

if [ ! -f "${CSV_PRED}" ]; then
    echo "ERROR: No se encontró ${CSV_PRED}. Abortando."
    exit 1
fi

# ─────────────────────────────────────────────────────────────────────
# COPIAR CSVs A HDFS
# ─────────────────────────────────────────────────────────────────────
echo ">>> Copiando métricas a HDFS..."
hdfs dfs -mkdir -p ${HDFS_METRICAS}
hdfs dfs -put -f ${CSV_LOCAL} ${HDFS_METRICAS}/metricas_cluster.csv

echo ">>> Copiando predicciones a HDFS..."
hdfs dfs -mkdir -p ${HDFS_PRED}
hdfs dfs -put -f ${CSV_PRED} ${HDFS_PRED}/predicciones_javier.csv

# ─────────────────────────────────────────────────────────────────────
# CREAR TABLAS Y CARGAR DATOS EN HIVE
# ─────────────────────────────────────────────────────────────────────
echo ">>> Creando base de datos y tablas del clúster..."
beeline -u "${HIVE_URI}" <<'HIVEEOF'

CREATE DATABASE IF NOT EXISTS cluster_db
COMMENT 'Métricas históricas del clúster Hadoop';
USE cluster_db;

-- TABLA: metricas_cluster (Parquet + partición por fecha)
CREATE EXTERNAL TABLE IF NOT EXISTS metricas_cluster (
    hora        STRING  COMMENT 'HH:MM:SS',
    contenedor  STRING  COMMENT 'Nombre del nodo',
    cpu_usage   DOUBLE  COMMENT '% CPU',
    mem_usage   DOUBLE  COMMENT '% Heap JVM usado',
    disk_usage  DOUBLE  COMMENT '% DFS usado'
)
PARTITIONED BY (fecha STRING COMMENT 'Fecha YYYY-MM-DD')
STORED AS PARQUET
LOCATION 'hdfs://Nodo-principal2:9000/user/hive/metricas_cluster'
TBLPROPERTIES ("parquet.compression"="SNAPPY");

-- TABLA: predicciones_cluster (columnas reales del CSV de R)
CREATE EXTERNAL TABLE IF NOT EXISTS predicciones_cluster (
    contenedor  STRING  COMMENT 'Nombre del nodo',
    t_sec       DOUBLE  COMMENT 'Tiempo en segundos',
    cpu_real    DOUBLE  COMMENT 'CPU real observada',
    fit         DOUBLE  COMMENT 'Valor predicho',
    lwr         DOUBLE  COMMENT 'Límite inferior IC 95%',
    upr         DOUBLE  COMMENT 'Límite superior IC 95%',
    intercept   DOUBLE  COMMENT 'Intercepto del modelo',
    pendiente   DOUBLE  COMMENT 'Pendiente del modelo',
    r_squared   DOUBLE  COMMENT 'R² del modelo',
    p_valor     DOUBLE  COMMENT 'P-valor del modelo'
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION 'hdfs://Nodo-principal2:9000/user/hive/predicciones_cluster'
TBLPROPERTIES ("skip.header.line.count"="1");

-- STAGING: CSV métricas → Parquet particionado
CREATE TABLE IF NOT EXISTS metricas_staging (
    fecha       STRING,
    hora        STRING,
    contenedor  STRING,
    cpu_usage   DOUBLE,
    mem_usage   DOUBLE,
    disk_usage  DOUBLE
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
TBLPROPERTIES ("skip.header.line.count"="1");

LOAD DATA INPATH
    'hdfs://Nodo-principal2:9000/user/hive/metricas_cluster/metricas_cluster.csv'
INTO TABLE metricas_staging;

SET hive.exec.dynamic.partition=true;
SET hive.exec.dynamic.partition.mode=nonstrict;

INSERT INTO TABLE metricas_cluster PARTITION (fecha)
SELECT hora, contenedor, cpu_usage, mem_usage, disk_usage, fecha
FROM metricas_staging;

DROP TABLE IF EXISTS metricas_staging;

SHOW TABLES;
SELECT contenedor, t_sec, cpu_real, fit, r_squared, p_valor
FROM predicciones_cluster LIMIT 10;

HIVEEOF

echo ">>> hive-init.sh completado."