import pymysql as mysql_connector
import random
import time
import numpy as np
from datetime import datetime, timedelta

HOST = "mysql-practica2"
PORT = 3306
USER = "alumne"
PASSWORD = "alumne1234"
DATABASE = "example"
TOTAL_ROWS = 5_000_000
BATCH_SIZE = 10_000

# ── Conexión MySQL ─────────────────────────────────────────────────────────
conn = None
for intento in range(10):
    try:
        conn = mysql_connector.connect(
            host=HOST, port=PORT, user=USER, password=PASSWORD, database=DATABASE
        )
        print("Conectado a MySQL.", flush=True)
        break
    except Exception as e:
        print(f"Intento {intento+1}/10: MySQL no listo ({e}). Esperando 15s...", flush=True)
        time.sleep(15)

if conn is None:
    print("No se pudo conectar a MySQL tras 10 intentos.", flush=True)
    exit(1)

cursor = conn.cursor()

# ── 1. Cargar datos para entrenamiento ────────────────────────────────────
print("\n[1/5] Cargando datos de entrenamiento desde MySQL...", flush=True)

cursor.execute("""
    SELECT hora_dia, consumo, generacion, Poblacion, fecha
    FROM electric_data
    WHERE consumo IS NOT NULL AND generacion IS NOT NULL AND hora_dia IS NOT NULL
    LIMIT 200000
""")
rows = cursor.fetchall()
print(f"  {len(rows):,} filas cargadas para entrenamiento.", flush=True)

cursor.execute("SELECT COALESCE(MAX(idexcel), 0) FROM electric_data")
last_id = int(cursor.fetchone()[0])
print(f"  Ultimo idexcel: {last_id}", flush=True)

cursor.execute("SELECT MIN(fecha), MAX(fecha) FROM electric_data")
fecha_min_raw, fecha_max_raw = cursor.fetchone()

cursor.execute("SELECT DISTINCT Poblacion FROM electric_data WHERE Poblacion IS NOT NULL")
poblaciones = [r[0] for r in cursor.fetchall()]
print(f"  Poblaciones: {poblaciones}", flush=True)

for fmt in ("%Y-%m-%d", "%d/%m/%Y", "%d-%m-%Y", "%Y/%m/%d"):
    try:
        dt_min = datetime.strptime(fecha_min_raw, fmt)
        dt_max = datetime.strptime(fecha_max_raw, fmt)
        fecha_fmt = fmt
        break
    except (ValueError, TypeError):
        continue
else:
    dt_min = datetime(2018, 1, 1)
    dt_max = datetime(2024, 12, 31)
    fecha_fmt = "%Y-%m-%d"

date_range_days = (dt_max - dt_min).days
print(f"  Rango fechas: {fecha_min_raw} -> {fecha_max_raw} ({date_range_days} dias)", flush=True)

# ── 2. Preparar features y entrenar modelo ────────────────────────────────
print("\n[2/5] Preparando features y entrenando modelo...", flush=True)

from sklearn.ensemble import GradientBoostingRegressor
from sklearn.preprocessing import LabelEncoder

pob_encoder = LabelEncoder()
pob_encoder.fit(poblaciones)

X, y_consumo, y_generacion = [], [], []

for row in rows:
    hora_dia, consumo, generacion, poblacion, fecha_str = row[0], row[1], row[2], row[3], row[4]
    try:
        dt = datetime.strptime(str(fecha_str), fecha_fmt)
        dia_semana = dt.weekday()
        mes = dt.month
    except:
        dia_semana = 0
        mes = 1
    try:
        pob_enc = pob_encoder.transform([poblacion])[0]
    except:
        pob_enc = 0
    X.append([hora_dia, dia_semana, mes, pob_enc])
    y_consumo.append(float(consumo))
    y_generacion.append(float(generacion))

X = np.array(X)
y_consumo = np.array(y_consumo)
y_generacion = np.array(y_generacion)

print(f"  Features shape: {X.shape}", flush=True)
print(f"  Entrenando modelo para consumo...", flush=True)
model_consumo = GradientBoostingRegressor(n_estimators=100, max_depth=4, random_state=42)
model_consumo.fit(X, y_consumo)

print(f"  Entrenando modelo para generacion...", flush=True)
model_generacion = GradientBoostingRegressor(n_estimators=100, max_depth=4, random_state=42)
model_generacion.fit(X, y_generacion)
print("  Modelos entrenados correctamente.", flush=True)

consumo_std = float(np.std(y_consumo))
generacion_std = float(np.std(y_generacion))
consumo_min_val = float(np.min(y_consumo))
consumo_max_val = float(np.max(y_consumo))
gen_min_val = float(np.min(y_generacion))
gen_max_val = float(np.max(y_generacion))

# ── 3. Generar e insertar 5M filas ────────────────────────────────────────
print(f"\n[3/5] Generando {TOTAL_ROWS:,} predicciones e insertando en MySQL...", flush=True)

insert_sql = """
    INSERT INTO electric_data (idexcel, fecha, hora_dia, consumo, generacion, Poblacion)
    VALUES (%s, %s, %s, %s, %s, %s)
"""

inserted = 0
current_id = last_id + 1

for batch_start in range(0, TOTAL_ROWS, BATCH_SIZE):
    batch_size_actual = min(BATCH_SIZE, TOTAL_ROWS - batch_start)

    deltas      = np.random.randint(0, date_range_days + 1, batch_size_actual)
    horas       = np.random.randint(0, 24, batch_size_actual)
    pob_indices = np.random.randint(0, len(poblaciones), batch_size_actual)
    pob_enc_arr = pob_encoder.transform([poblaciones[i] for i in pob_indices])

    fechas_dt   = [dt_min + timedelta(days=int(d)) for d in deltas]
    dias_semana = np.array([d.weekday() for d in fechas_dt])
    meses       = np.array([d.month for d in fechas_dt])
    fechas_str  = [d.strftime(fecha_fmt) for d in fechas_dt]

    X_batch = np.column_stack([horas, dias_semana, meses, pob_enc_arr])

    consumos     = model_consumo.predict(X_batch) + np.random.normal(0, consumo_std * 0.1, batch_size_actual)
    generaciones = model_generacion.predict(X_batch) + np.random.normal(0, generacion_std * 0.1, batch_size_actual)

    consumos     = np.clip(consumos, consumo_min_val, consumo_max_val).round(4)
    generaciones = np.clip(generaciones, gen_min_val, gen_max_val).round(4)

    ids = list(range(current_id, current_id + batch_size_actual))
    current_id += batch_size_actual

    batch_data = list(zip(
        ids, fechas_str, horas.tolist(),
        consumos.tolist(), generaciones.tolist(),
        [poblaciones[i] for i in pob_indices]
    ))

    cursor.executemany(insert_sql, batch_data)
    conn.commit()
    inserted += batch_size_actual

    if inserted % 100_000 == 0:
        print(f"  -> {inserted:,} / {TOTAL_ROWS:,} filas insertadas...", flush=True)

print(f"\n[4/5] Insercion completada. Total: {inserted:,} filas. ID final: {current_id - 1}", flush=True)
cursor.close()
conn.close()

# ── 4. Señal para sqoop-init ───────────────────────────────────────────────
print("\n[5/5] Señalizando fin al Sqoop...", flush=True)
with open("/tmp/generador_done", "w") as f:
    f.write("done")
print("✅ Generador finalizado. MySQL listo con 7M+ filas. Sqoop puede continuar.", flush=True)
