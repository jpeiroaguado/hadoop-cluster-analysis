#!/bin/bash
echo ">>> Esperando a que el generador de datos termine..."
until [ -f /tmp/generador_done ]; do
  echo "  Generador aun trabajando, esperando 30s..."
  sleep 30
done
echo ">>> Generador completado. Arrancando Sqoop..."

echo ">>> Esperando HDFS..."
until hdfs dfsadmin -fs hdfs://Nodo-principal2:9000 -report > /dev/null 2>&1; do
  sleep 10
done

echo ">>> Saliendo de Safe Mode..."
hdfs dfsadmin -fs hdfs://Nodo-principal2:9000 -safemode leave

echo ">>> Lanzando Sqoop import (reimportacion completa con todos los datos)..."
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

echo ">>> Sqoop completado! HDFS actualizado con todos los datos."
