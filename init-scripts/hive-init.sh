#!/bin/bash
echo ">>> Esperando HiveServer2..."
until beeline -u 'jdbc:hive2://hive2:10000/' -e "SHOW DATABASES;" > /dev/null 2>&1; do
  echo "HiveServer2 no listo, esperando..."
  sleep 15
done

echo ">>> Creando tabla externa en Hive..."
beeline -u 'jdbc:hive2://hive2:10000/' -e "
CREATE EXTERNAL TABLE IF NOT EXISTS electric_data (
  consumo DOUBLE,
  fecha STRING,
  generacion DOUBLE,
  hora_dia INT,
  idexcel INT,
  Poblacion STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION 'hdfs://Nodo-principal2:9000/user/root/electric_data_sqoop';"

echo ">>> Tabla Hive creada!"
