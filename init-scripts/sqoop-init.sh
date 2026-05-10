#!/usr/bin/env bash
set -e

echo ">>> Esperando a que el generador de datos termine..."
while [ ! -f /tmp/generador_done ]; do
  echo "Generador aun trabajando, esperando 30s..."
  sleep 30
done

echo ">>> Generador completado. Arrancando Sqoop..."

echo ">>> Esperando HDFS..."
while ! hdfs dfsadmin -fs hdfs://Nodo-principal2:9000 -report > /dev/null 2>&1; do
  echo "HDFS no listo, esperando 10s..."
  sleep 10
done

echo ">>> Saliendo de Safe Mode..."
hdfs dfsadmin -fs hdfs://Nodo-principal2:9000 -safemode leave || true

echo ">>> Lanzando Sqoop import..."
sqoop import \
  -Dmapreduce.framework.name=local \
  -Dmapreduce.jobtracker.address=local \
  --connect jdbc:mysql://mysql-practica2:3306/example \
  --username alumne \
  --password alumne1234 \
  --table electric_data \
  --target-dir hdfs://Nodo-principal2:9000/user/root/electric_data_sqoop \
  --delete-target-dir \
  --num-mappers 1

echo ">>> Sqoop completado! HDFS actualizado."