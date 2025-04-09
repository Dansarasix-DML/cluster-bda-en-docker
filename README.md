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

### Comandos para ssh

```
ssh-keygen -R [localhost]:2222
ssh hadoop@localhost -p 2222
```