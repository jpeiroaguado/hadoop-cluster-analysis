FROM bde2020/hadoop-namenode:2.0.0-hadoop3.2.1-java8

USER root

# ── 1. Sqoop ──────────────────────────────────────────────────────────────
ADD http://archive.apache.org/dist/sqoop/1.4.7/sqoop-1.4.7.bin__hadoop-2.6.0.tar.gz /tmp/sqoop.tar.gz

RUN tar -xvf /tmp/sqoop.tar.gz -C /usr/local/ && \
    mv /usr/local/sqoop-1.4.7.bin__hadoop-2.6.0 /usr/local/sqoop && \
    rm /tmp/sqoop.tar.gz

ADD https://repo1.maven.org/maven2/commons-lang/commons-lang/2.6/commons-lang-2.6.jar /usr/local/sqoop/lib/commons-lang-2.6.jar
ADD https://repo1.maven.org/maven2/mysql/mysql-connector-java/8.0.28/mysql-connector-java-8.0.28.jar /usr/local/sqoop/lib/mysql-connector-java-8.0.28.jar

RUN cp /opt/hadoop-3.2.1/share/hadoop/common/*.jar /usr/local/sqoop/lib/ && \
    cp /opt/hadoop-3.2.1/share/hadoop/common/lib/*.jar /usr/local/sqoop/lib/ && \
    cp /opt/hadoop-3.2.1/share/hadoop/mapreduce/*.jar /usr/local/sqoop/lib/

# ── 2. JMX Exporter ──────────────────────────────────────────────────────
# Descarga el agente JMX Exporter (convierte métricas JMX al formato Prometheus)
ADD https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.20.0/jmx_prometheus_javaagent-0.20.0.jar /opt/jmx_exporter/jmx_prometheus_javaagent.jar

# Configuración del JMX Exporter para Hadoop NameNode
COPY config/jmx-exporter.yml /opt/jmx_exporter/jmx-exporter.yml

# Inyectar el agente JMX en las opciones de arranque del NameNode
# Puerto 9090 → expone métricas Prometheus del NameNode
ENV HDFS_NAMENODE_OPTS="-javaagent:/opt/jmx_exporter/jmx_prometheus_javaagent.jar=9094:/opt/jmx_exporter/jmx-exporter.yml"

# ── 3. Variables de entorno ───────────────────────────────────────────────
ENV PATH=$PATH:/usr/local/sqoop/bin
ENV HADOOP_CLASSPATH="/usr/local/sqoop/lib/*"

