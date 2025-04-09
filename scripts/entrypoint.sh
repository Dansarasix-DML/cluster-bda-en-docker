#!/bin/bash
service ssh start

ROLE=$1

# Configurar Hadoop
cp /scripts/hadoop-env.sh $HADOOP_HOME/etc/hadoop/hadoop-env.sh
cp /scripts/core-site.xml $HADOOP_HOME/etc/hadoop/core-site.xml
cp /scripts/hdfs-site.xml $HADOOP_HOME/etc/hadoop/hdfs-site.xml
cp /scripts/yarn-site.xml $HADOOP_HOME/etc/hadoop/yarn-site.xml
cp /scripts/mapred-site.xml $HADOOP_HOME/etc/hadoop/mapred-site.xml
cp /scripts/workers $HADOOP_HOME/etc/hadoop/workers

# Verifica que se haya pasado un rol válido
if [ -z "$ROLE" ]; then
    echo "ERROR: No role specified. Use 'master' or 'worker'."
    exit 1
fi

# Formatear el NameNode solo en el master
if [[ $ROLE == "master" ]]; then
    # Formatear el HDFS
    $HADOOP_HOME/bin/hdfs namenode -format -force

    # Iniciar Hadoop (NameNode y ResourceManager)
    start-dfs.sh
    start-yarn.sh

    # Dejar el contenedor corriendo
    tail -f /dev/null
else
    # Iniciar DataNode y NodeManager
    $HADOOP_HOME/sbin/hadoop-daemon.sh start datanode
    $HADOOP_HOME/sbin/yarn-daemon.sh start nodemanager
    tail -f /dev/null
fi

exec "$@"  # ejecuta cualquier otro comando (como bash si entras con docker exec)
# Fin del script