FROM ubuntu:22.04

# Evita prompts interactivos
ENV DEBIAN_FRONTEND=noninteractive

# Instalar Java, SSH y utilidades
RUN apt-get update && apt-get install -y \
    openjdk-8-jdk \
    net-tools \
    mysql-client \
    python3-pip \
    ssh rsync wget curl nano net-tools iputils-ping vim sudo \
    && apt-get clean

RUN pip install pandas pyarrow kafka-python numpy==1.26.4 --force-reinstall

# Establecer JAVA_HOME
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
ENV PATH=$PATH:$JAVA_HOME/bin

# Descargar e instalar Hadoop
ENV HADOOP_VERSION=3.3.6
RUN wget https://downloads.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz && \
    tar -xvzf hadoop-${HADOOP_VERSION}.tar.gz && mv hadoop-${HADOOP_VERSION} /opt/hadoop && \
    rm hadoop-${HADOOP_VERSION}.tar.gz

# Establecer variables de entorno de Hadoop
ENV HADOOP_HOME=/opt/hadoop
ENV PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin

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
    chown -R hadoop:hadoop /opt/hadoop/hadoop_data

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

COPY scripts/entrypoint.sh /scripts/entrypoint.sh
RUN chmod +x /scripts/entrypoint.sh
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["/bin/bash"]
