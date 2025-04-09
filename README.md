# cluster-bda en Docker

---

### Requerimientos

Crea la red en Docker:

```
docker network create --driver bridge bigdata
```

Tras eso, formatea Hadoop para el primer uso:

```
$HADOOP_HOME/bin/hdfs namenode -format -force
start-dfs.sh
start-yarn.sh
```