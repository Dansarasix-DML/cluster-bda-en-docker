FROM ubuntu:22.04

# Evita prompts interactivos
ENV DEBIAN_FRONTEND=noninteractive

# Instalar Java, SSH y utilidades
RUN apt-get update && apt-get install -y \
    openjdk-8-jdk \
    unzip \
    mysql-client \
    python3-pip \
    ssh rsync wget curl nano net-tools iputils-ping vim sudo \
    && apt-get clean

RUN pip install pandas pyarrow kafka-python numpy==1.26.4 --force-reinstall

# Establecer JAVA_HOME
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
ENV PATH=$PATH:$JAVA_HOME/bin

# Descargar e instalar Hadoop
ENV HADOOP_VERSION=3.4.1
RUN wget https://downloads.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz && \
    tar -xvzf hadoop-${HADOOP_VERSION}.tar.gz && mv hadoop-${HADOOP_VERSION} /opt/hadoop && \
    rm hadoop-${HADOOP_VERSION}.tar.gz

# Establecer variables de entorno de Hadoop
ENV HADOOP_HOME=/opt/hadoop
ENV PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin

# Descargar e instalar Spark (sin Hadoop)
ENV SPARK_VERSION=3.5.4

RUN wget https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-without-hadoop.tgz && \
    tar -xzf spark-${SPARK_VERSION}-bin-without-hadoop.tgz && \
    mv spark-${SPARK_VERSION}-bin-without-hadoop /opt/hadoop/spark && \
    rm spark-${SPARK_VERSION}-bin-without-hadoop.tgz

# Variables de entorno para Spark
ENV SPARK_HOME=/opt/hadoop/spark
ENV PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin

# Descargar Kafka 3.9.0 (actual)
ENV KAFKA_VERSION_1=3.9.0
RUN wget https://downloads.apache.org/kafka/${KAFKA_VERSION_1}/kafka_2.13-${KAFKA_VERSION_1}.tgz && \
    tar -xzf kafka_2.13-${KAFKA_VERSION_1}.tgz && \
    mv kafka_2.13-${KAFKA_VERSION_1} /opt/kafka_3.9.0 && \
    rm kafka_2.13-${KAFKA_VERSION_1}.tgz

# Descargar Kafka 4.0.0 (respaldo)
ENV KAFKA_VERSION_2=4.0.0
RUN wget https://downloads.apache.org/kafka/${KAFKA_VERSION_2}/kafka_2.13-${KAFKA_VERSION_2}.tgz && \
    tar -xzf kafka_2.13-${KAFKA_VERSION_2}.tgz && \
    mv kafka_2.13-${KAFKA_VERSION_2} /opt/kafka_4.0.0 && \
    rm kafka_2.13-${KAFKA_VERSION_2}.tgz

RUN mkdir -p /opt/kafka_plugins

# Desgargar Kafka Connect
ENV KAFKA_CONNECT_VERSION=10.8.2
ENV MYSQL_CONNECTOR_VERSION=9.2.0
ENV HADOOP_CONNECTOR_VERSION=1.2.3

RUN wget https://hub-downloads.confluent.io/api/plugins/confluentinc/kafka-connect-jdbc/versions/${KAFKA_CONNECT_VERSION}/confluentinc-kafka-connect-jdbc-${KAFKA_CONNECT_VERSION}.zip && \
    unzip confluentinc-kafka-connect-jdbc-${KAFKA_CONNECT_VERSION}.zip && \
    mv confluentinc-kafka-connect-jdbc-${KAFKA_CONNECT_VERSION} /opt/kafka_plugins && \
    rm confluentinc-kafka-connect-jdbc-${KAFKA_CONNECT_VERSION}.zip && \
    wget https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-j-${MYSQL_CONNECTOR_VERSION}.tar.gz && \
    tar -xzf mysql-connector-j-${MYSQL_CONNECTOR_VERSION}.tar.gz && \
    mv mysql-connector-j-${MYSQL_CONNECTOR_VERSION} /opt/kafka_plugins/mysql-connector-j && \
    rm mysql-connector-j-${MYSQL_CONNECTOR_VERSION}.tar.gz && \
    wget https://hub-downloads.confluent.io/api/plugins/confluentinc/kafka-connect-hdfs3/versions/${HADOOP_CONNECTOR_VERSION}/confluentinc-kafka-connect-hdfs3-${HADOOP_CONNECTOR_VERSION}.zip && \
    unzip confluentinc-kafka-connect-hdfs3-${HADOOP_CONNECTOR_VERSION}.zip && \
    mv confluentinc-kafka-connect-hdfs3-${HADOOP_CONNECTOR_VERSION} /opt/kafka_plugins && \
    rm confluentinc-kafka-connect-hdfs3-${HADOOP_CONNECTOR_VERSION}.zip


# Crear usuario 'hadoop' con bash y permisos sudo
RUN useradd -m -s /bin/bash hadoop && \
    echo "hadoop:hadoop" | chpasswd && \
    adduser hadoop sudo

# Configurar prompt personalizado para el usuario hadoop
RUN echo "export PS1='\\u@\\h:\\w\\$ '" >> /home/hadoop/.bashrc

RUN echo "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64" >> /home/hadoop/.bashrc && \
    echo "export PATH=$PATH:$JAVA_HOME/bin" >> /home/hadoop/.bashrc

# Agregar variables de Hadoop al bashrc del usuario hadoop
RUN echo '\
# Hadoop environment variables\n\
export HADOOP_HOME=/opt/hadoop\n\
export HADOOP_INSTALL=$HADOOP_HOME\n\
export HADOOP_MAPRED_HOME=$HADOOP_HOME\n\
export HADOOP_COMMON_HOME=$HADOOP_HOME\n\
export HADOOP_HDFS_HOME=$HADOOP_HOME\n\
export HADOOP_YARN_HOME=$HADOOP_HOME\n\
export HADOOP_COMMON_LIB_NATIVE_DIR=$HADOOP_HOME/lib/native\n\
export PATH=$PATH:$HADOOP_HOME/sbin:$HADOOP_HOME/bin\n\
export HADOOP_OPTS="-Djava.library.path=$HADOOP_HOME/lib/native"\n\
' >> /home/hadoop/.bashrc

# Agregar variables de Spark al bashrc del usuario hadoop
RUN echo 'export SPARK_HOME=/opt/hadoop/spark' >> /home/hadoop/.bashrc && \
    echo 'export SPARK_DIST_CLASSPATH=$(hadoop classpath)' >> /home/hadoop/.bashrc && \
    echo 'export PATH=$PATH:$SPARK_HOME/bin' >> /home/hadoop/.bashrc

# Preparar carpeta de trabajo
RUN mkdir -p /data /scripts && chown hadoop:hadoop /data /scripts

# Permitir login SSH sin contraseña (para el cluster después)
RUN mkdir /home/hadoop/.ssh && chown hadoop:hadoop /home/hadoop/.ssh && chmod 700 /home/hadoop/.ssh

# Definir el directorio de trabajo
WORKDIR /home/hadoop

# Crear estructura de datos para HDFS
RUN mkdir -p /opt/hadoop/hadoop_data/hdfs/namenode && \
    mkdir -p /opt/hadoop/hadoop_data/hdfs/datanode && \
    mkdir -p /opt/hadoop/hadoop_data/hdfs/secondary_namenode && \
    chown -R hadoop:hadoop /opt/hadoop/hadoop_data && \
    chown -R hadoop:hadoop /opt/kafka_plugins

# Crear el directorio de logs y establecer permisos
RUN mkdir -p /opt/hadoop/logs && \
    chown -R hadoop:hadoop /opt/hadoop/logs && \
    chmod -R 755 /opt/hadoop/logs

# Generar claves SSH sin frase de paso
RUN mkdir -p /home/hadoop/.ssh && \
    ssh-keygen -t rsa -P "" -f /home/hadoop/.ssh/id_rsa && \
    cat /home/hadoop/.ssh/id_rsa.pub >> /home/hadoop/.ssh/authorized_keys && \
    chown -R hadoop:hadoop /home/hadoop/.ssh && \
    chmod 700 /home/hadoop/.ssh && \
    chmod 600 /home/hadoop/.ssh/authorized_keys




# Abrir puerto SSH y definir CMD
EXPOSE 22

COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["/bin/bash"]
