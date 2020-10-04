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

You shall see the following line, indicating this node is started with Galera replication:
```
2020-09-30  8:14:59 2 [Note] WSREP: Synchronized with group, ready for connections
```

2) On the second database node (db2), run:

```bash
cd compose
docker-compose up -d
```
*This will load the default `docker-compose.yaml` in the current directory.*

You shall see the following line, indicating this node is started with Galera replication:
```
2020-09-30  8:14:59 2 [Note] WSREP: Synchronized with group, ready for connections
```

3) On the second database node (db3), run:

```bash
cd compose
docker-compose up -d
```
*This will load the default `docker-compose.yaml` in the current directory.*

You shall see the following line, indicating this node is started with Galera replication:
```
2020-09-30  8:14:59 2 [Note] WSREP: Synchronized with group, ready for connections
```

4) Verify if all nodes are connected to the cluster with the following command on any node:

```bash
$ docker-compose exec nextcloud-mariadb mysql --defaults-group-suffix=_backup -e 'SELECT * FROM mysql.wsrep_cluster_members'
+--------------------------------------+--------------------------------------+-----------------+-----------------------+
| node_uuid                            | cluster_uuid                         | node_name       | node_incoming_address |
+--------------------------------------+--------------------------------------+-----------------+-----------------------+
| 4bf57c03-0200-11eb-b58f-43df190a249b | cb61f63f-01fd-11eb-9e62-6745e57d17ff | mariadb3-docker | AUTO                  |
| 4cd4987e-02da-11eb-b5e3-3369b449c01a | cb61f63f-01fd-11eb-9e62-6745e57d17ff | mariadb1-docker | AUTO                  |
| 564cb0e4-0200-11eb-8b35-0f7cbcbf3ea1 | cb61f63f-01fd-11eb-9e62-6745e57d17ff | mariadb2-docker | AUTO                  |
+--------------------------------------+--------------------------------------+-----------------+-----------------------+
```

\* *The above `mysql` command reads the user credentials from `[mysql_backup]` directive inside `credentials.cnf`, as supplied by `--defaults-group-suffix` parameter.*

---

**!! ATTENTION !!**

Only bootstrap one node in a Galera cluster (commonly the first node). The rest of the nodes, BOOTSTRAP should be set to 0 or skip defining it. Don't proceed to start the remaining node until the first node is bootstrapped.

---

5) Once all nodes have joined the cluster, stop the "bootstrap" container on the first node (db1) so we can start it with the same `--wsrep_cluster_address` value as the rest of the nodes:

```bash
cd compose
docker-compose down
docker-compose up -d
```
*This will load the default `docker-compose.yaml` in the current directory.*

\* *Step 5 is important, so when the Docker host is rebooted, the container will be auto-started with the correct `--wsrep_cluster_address` as in `docker-compose.yaml`, identical with the rest of the members in the cluster.*

## Shutting down the MariaDB cluster

Stop one node at a time, starting from the lowest priority node like the multi-reader nodes first, and the single-writer node should be the last to go down:

On db3:

```bash
cd compose
docker-compose down
```

On db2:

```bash
cd compose
docker-compose down
```

On db1:

```bash
cd compose
docker-compose down
```

The last node that goes down, shall have `safe_to_bootstrap` set to 1. To verify this, we can look at the content of `grastate.dat` file under the MySQL data volume:

```bash
$ cat datadir/grastate.dat
# GALERA saved state
version: 2.1
uuid:    cb61f63f-01fd-11eb-9e62-6745e57d17ff
seqno:   5
safe_to_bootstrap: 1
```

## Start the cluster after an ungraceful shutdown

In cases where all nodes were shut down ungracefully like a power trip, the MariaDB Cluster shall be left with `safe_to_bootstrap: 0` and `seqno: -1` on all nodes. To verify this, check the content of `grastate.dat` under the MySQL data volume:

```bash
$ cat datadir/grastate.dat
# GALERA saved state
version: 2.1
uuid:    cb61f63f-01fd-11eb-9e62-6745e57d17ff
seqno:   -1
safe_to_bootstrap: 0
```

Since all nodes will have the same values (`seqno: -1` and `safe_to_bootstrap: 0`), none of them can be bootstrapped safely. Galera requires manual intervention to set the value back to 1 from the most up-to-date node in the cluster. To check which node is the most up-to-date ones, include the `docker-compose.recover.yaml` which appending the `--wsrep_recover` option:
```bash
cd compose
docker-compose -f docker-compose.yaml -f docker-compose.recover.yaml up --abort-on-container-exit
```

\* *The `--abort-on-container-exit` is necessary because with `--wsrep_recover` flag, MariaDB will be started temporarily, retrieve the Galera information and exit.*

Focus on the last line of the output. You should see something like this:
```
nextcloud-mariadb_1    | 2020-09-30  8:02:02 0 [Note] Plugin 'FEEDBACK' is disabled.
nextcloud-mariadb_1    | 2020-09-30  8:02:02 0 [Note] Server socket created on IP: '::'.
nextcloud-mariadb_1    | 2020-09-30  8:02:02 0 [Note] WSREP: Recovered position: cb61f63f-01fd-11eb-9e62-6745e57d17ff:22,1000-1000-7217
```

The recovered position for this node is 22. The first value (cb61f63f-01fd-11eb-9e62-6745e57d17ff) is the cluster UUID, the next value (22) is the Galera seqno and the last value (1000-1000-7217) is the MariaDB GTID position.

Now compare the Galera seqno value of 22 with other nodes. The highest value of this shall be started with `BOOTSTRAP=1`. If all nodes are reporting a same value, it means all nodes in the cluster are in the same consistent state. Therefore, you can pick any of the nodes to bootstrap.

Now on the chosen node, run the bootstrap command as below:
```bash
cd compose
docker-compose -f docker-compose.yaml -f docker-compose.bootstrap.yaml up -d
```

\* *The `docker-compose.bootstrap.yaml` contains `FORCE_BOOTSTRAP=1` which will set `safe_to_bootstrap: 1` in `grastate.dat` during MariaDB startup, allowing this node to be bootstrapped correctly by Galera.*

Then, start the rest of the nodes (one node at a time) using the default compose file:
```bash
cd compose
docker-compose up -d # db2
docker-compose up -d # db3
```

Finally, back to the bootstrapped node (db1) and restart the node with the default compose file:
```bash
cd compose
docker-compose down #db1
docker-compose up -d #db1
```

## Restarting a MariaDB node

Restarting a node is similar to stopping and starting a container:

```bash
cd compose
docker-compose down
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

All backup credentials are stored in a specific files, `/etc/mysql/mariadb.conf.d/credentials.cnf`. The backup user is created automatically by [init/02-backup_user.sql](https://github.com/safespring/nextcloud-db/blob/master/mariadb/compose/init/02-backup_user.sql) during container initialization stage.

### Mariabackup

To create a physical backup using `mariabackup`, attach to the running service and specify the backup command:

```bash
cd compose
docker-compose exec nextcloud-mariadb mariabackup --backup --target-dir=/backups/mariabackup_$(date '+%Y-%m-%d_%H:%M:%S')
```

\* *The above `mariabackup` command reads the user credentials from `[mariabackup]` directive inside `credentials.cnf`.*

You will see some output. Make sure you see `Completed OK` in the last line. That's the indicator the backup is completed successfully.

Example created directory: `mariabackup_2020-10-02_06:40:39`

The `--target-dir` is the path **INSIDE** the container, as in this case, `/backups/mariabackup_2020-10-02_06:40:39/` of the container, mapped to `${PWD}/backups` on the Docker host.


### mysqldump

To create a logical backup using `mysqldump`, attach to the running service and specify the backup command:

```bash
cd compose
docker-compose exec nextcloud-mariadb mysqldump --single-transaction --all-databases | gzip > backups/mysqldump_$(date '+%Y-%m-%d_%H:%M:%S').sql.gz
```

\* *The above `mysqldump` command reads the user credentials from `[mysqldump]` directive inside `credentials.cnf`.*

Example mysqldump filename: `mysqldump_2020-09-28_09:23:59.sql.gz`

The mysqldump stdout output is redirected to the path **OUTSIDE** of the container, as in this case, the backup is saved to `backups/mysqldump_2020-09-28_09:23:59.sql.gz` relative to the current directory on the Docker host.
