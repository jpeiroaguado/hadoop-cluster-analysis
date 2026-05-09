#!/bin/bash
set -e

echo "Cargando CSV en MySQL..."
mysql -uroot -p"$MYSQL_ROOT_PASSWORD" example -e "
SET sql_mode='';
CREATE TABLE IF NOT EXISTS electric_data (
  idexcel INT,
  fecha VARCHAR(50),
  hora_dia INT,
  consumo DOUBLE,
  generacion DOUBLE,
  Poblacion VARCHAR(100)
);
LOAD DATA INFILE '/var/lib/mysql-files/datos_electricidad_bueno.csv'
INTO TABLE electric_data
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '\"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(fecha, consumo, generacion, hora_dia, idexcel, Poblacion);
"
echo "Filas cargadas:"
mysql -uroot -p"$MYSQL_ROOT_PASSWORD" example -e "SELECT COUNT(*) FROM electric_data;"
