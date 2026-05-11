#!/usr/bin/env python3
import csv
import datetime
import urllib.request
import urllib.parse
import json
import os


PROMETHEUS_URL = os.getenv("PROMETHEUS_URL", "http://prometheus-equipo2:9090")
OUTPUT_CSV = os.getenv("OUTPUT_CSV", "/outputs/metricas_cluster.csv")

def query(expr):
    url = f"{PROMETHEUS_URL}/api/v1/query?query={urllib.parse.quote(expr)}"
    with urllib.request.urlopen(url, timeout=10) as r:
        data = json.loads(r.read())
    return data["data"]["result"]


def val(results, idx=0):
    try:
        return round(float(results[idx]["value"][1]), 4)
    except (IndexError, KeyError, ValueError):
        return 0.0


def main():
    os.makedirs(os.path.dirname(OUTPUT_CSV), exist_ok=True)

    now = datetime.datetime.utcnow()
    fecha = now.strftime("%Y-%m-%d")
    hora = now.strftime("%H:%M:%S")
    rows = []

    for nodo, job in [("datos-12", "hadoop-datanode-1"), ("datos-22", "hadoop-datanode-2")]:
        mused = val(query(f'hadoop_datanode_jvmmetrics_memheapusedm{{job="{job}"}}'))
        mmax  = val(query(f'hadoop_datanode_jvmmetrics_memheapmaxm{{job="{job}"}}'))
        mem   = round(mused / mmax * 100, 4) if mmax > 0 else 0.0

        dused = val(query(f'hadoop_datanode_fsdatasetstate_dfsused{{job="{job}"}}'))
        dcap  = val(query(f'hadoop_datanode_fsdatasetstate_capacity{{job="{job}"}}'))
        disk  = round(dused / dcap * 100, 4) if dcap > 0 else 0.0

        cpu = val(query(f'hadoop_datanode_jvmmetrics_gctimemillisps{{job="{job}"}}'))

        rows.append({
            "fecha": fecha,
            "hora": hora,
            "contenedor": nodo,
            "cpu_usage": cpu,
            "mem_usage": mem,
            "disk_usage": disk,
        })
        print(f"[OK] {nodo} → cpu={cpu}ms/s mem={mem}% disk={disk}%")

    mused = val(query('hadoop_namenode_jvm_memheapusedm{job="hadoop-namenode"}'))
    mmax  = val(query('hadoop_namenode_jvm_memheapmaxm{job="hadoop-namenode"}'))
    mem   = round(mused / mmax * 100, 4) if mmax > 0 else 0.0

    dused = val(query('hadoop_namenode_capacityused{job="hadoop-namenode"}'))
    dcap  = val(query('hadoop_namenode_capacitytotal{job="hadoop-namenode"}'))
    disk  = round(dused / dcap * 100, 4) if dcap > 0 else 0.0

    cpu = val(query('hadoop_namenode_jvm_gctimemillisps{job="hadoop-namenode"}'))

    rows.append({
        "fecha": fecha,
        "hora": hora,
        "contenedor": "Nodo-principal2",
        "cpu_usage": cpu,
        "mem_usage": mem,
        "disk_usage": disk,
    })
    print(f"[OK] Nodo-principal2 → cpu={cpu}ms/s mem={mem}% disk={disk}%")

    file_exists = os.path.isfile(OUTPUT_CSV)
    with open(OUTPUT_CSV, "a", newline="") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=["fecha", "hora", "contenedor", "cpu_usage", "mem_usage", "disk_usage"]
        )
        if not file_exists:
            writer.writeheader()
        writer.writerows(rows)

    print(f"[DONE] {len(rows)} filas añadidas en {OUTPUT_CSV}")


if __name__ == "__main__":
    main()