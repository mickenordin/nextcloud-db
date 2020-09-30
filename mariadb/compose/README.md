# Running with Docker Compose

## Bootstrapping the MariaDB cluster

0) Set the `--wsrep_cluster_address` in the `command` section with the IP address/hostname/FQDN of all database nodes in the cluster. For example, if the 3 Galera nodes are 192.168.0.241, 192.168.0.242 and 192.168.0.243, the `--wsrep_cluster_address` value inside `docker-compose.yaml` should be:

```yaml
   command:
     - --wsrep_cluster_address=gcomm://192.168.0.241,192.168.0.242,192.68.0.243
```

1) Include the `docker-compose.bootstrap.yaml` in the `docker-compose` command when bootstrapping the cluster on the first node only. On the first node (db1), run:

```bash
cd compose
docker-compose -f docker-compose.yaml -f docker-compose.bootstrap.yaml up -d
```

2) On the second database node (db2), run:

```bash
cd compose
docker-compose up -d
```
*This will load the default `docker-compose.yaml` in the current directory.*

3) On the second database node (db3), run:

```bash
cd compose
docker-compose up -d
```
*This will load the default `docker-compose.yaml` in the current directory.*

4) Verify if all nodes are connected to the cluster with the following command on any node:

```bash
$ docker-compose exec nextcloud-mariadb mysql -e 'SELECT * FROM mysql.wsrep_cluster_members'
+--------------------------------------+--------------------------------------+-----------------+-----------------------+
| node_uuid                            | cluster_uuid                         | node_name       | node_incoming_address |
+--------------------------------------+--------------------------------------+-----------------+-----------------------+
| 4bf57c03-0200-11eb-b58f-43df190a249b | cb61f63f-01fd-11eb-9e62-6745e57d17ff | mariadb3-docker | AUTO                  |
| 4cd4987e-02da-11eb-b5e3-3369b449c01a | cb61f63f-01fd-11eb-9e62-6745e57d17ff | mariadb1-docker | AUTO                  |
| 564cb0e4-0200-11eb-8b35-0f7cbcbf3ea1 | cb61f63f-01fd-11eb-9e62-6745e57d17ff | mariadb2-docker | AUTO                  |
+--------------------------------------+--------------------------------------+-----------------+-----------------------+
```

---

**!! ATTENTION !!**

Only bootstrap one node in a Galera cluster (commonly the first node). The rest of the nodes, BOOTSTRAP should be set to 0 or skip defining it. Don't proceed to start the remaining node until the first node is bootstrapped.

---

5) Once all nodes have joined the cluster, stop the "bootstrap" container on the first node (db1) so we can start it with the same `--wsrep_cluster_address` value as the rest of the nodes:

```bash
cd compose
docker-compose down -d
docker-compose up -d
```
*This will load the default `docker-compose.yaml` in the current directory.*


## Shutting down the MariaDB cluster

Stop one node at a time, starting from the lowest priority node like the multi-reader nodes first, and the single-writer node should be the last to go down:

On db3:

```bash
cd compose
docker-compose down -d
```

On db2:

```bash
cd compose
docker-compose down -d
```

On db1:

```bash
cd compose
docker-compose down -d
```

The last node that goes down, should have `safe_to_bootstrap` set to 1. To verify this, we can look at the content of `grastate.dat` file under the MySQL data volume:

```bash
$ cat datadir/grastate.dat
# GALERA saved state
version: 2.1
uuid:    cb61f63f-01fd-11eb-9e62-6745e57d17ff
seqno:   5
safe_to_bootstrap: 1
```

## Restarting a MariaDB node

Restarting a node is similar to stopping and starting a container:

```bash
cd compose
docker-compose down -d
docker-compose up -d
```

** MariaDB restart must be performed on one node at a time for a 3-node Galera cluster. For a 5-node Galera cluster, you can have maximum of 2 unavailable nodes at a time.

## Backup

By default, the image will create a backup directory under `/backups/`. This should be mapped in the volume when starting the MariaDB container, for example:

```yaml
    volumes:
      - ${PWD}/datadir:/var/lib/mysql
      - ${PWD}/init:/docker-entrypoint-initdb.d
      - ${PWD}/conf:/etc/mysql/mariadb.conf.d
      - ${PWD}/backups:/backups
```

All backup credentails are stored in a specific files, `/etc/mysql/mariadb.conf.d/credentials.cnf`. The backup user is created automatically by `init/02-backup_user.sql` during container initialization stage.

### Mariabackup

To create a physical backup using mariabackup, attach to the service with the following command:

```bash
docker-compose exec nextcloud-mariadb /usr/bin/mariabackup --defaults-file=/etc/mysql/mariadb.conf.d/credentials.cnf --backup --target-dir=/backups/mariabackup
```

** You will see some output. Make sure you see `Completed OK` in the last line. That's the indicator the backup is completed successfully.


### mysqldump

```bash
docker-compose exec nextcloud-mariadb /bin/mysqldump --defaults-file=/etc/mysql/mariadb.conf.d/credentials.cnf --single-transaction --all-databases | gzip > /backups/mysqldump_$(date '+%Y-%m-%d_%H:%M:%S').sql.gz
```

The example mysqldump output: `mysqldump_2020-09-28_09:23:59.sql.gz`
