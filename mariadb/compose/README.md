# Running with Docker Compose

## Service Control

### Bootstrapping the MariaDB cluster (3 or more nodes)

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
```bash
$ docker-compose logs nextcloud-mariadb -f
...
2020-09-30  8:14:59 2 [Note] WSREP: Synchronized with group, ready for connections
...
```

2) On the second database node (db2), run:

```bash
cd compose
docker-compose up -d
```
*This will load the default `docker-compose.yaml` in the current directory.*

You shall see the following line, indicating this node is started with Galera replication:
```bash
$ docker-compose logs nextcloud-mariadb -f
...
2020-09-30  8:14:59 2 [Note] WSREP: Synchronized with group, ready for connections
...
```

3) On the second database node (db3), run:

```bash
cd compose
docker-compose up -d
```
*This will load the default `docker-compose.yaml` in the current directory.*

You shall see the following line, indicating this node is started with Galera replication:
```bash
$ docker-compose logs nextcloud-mariadb -f
...
2020-09-30  8:14:59 2 [Note] WSREP: Synchronized with group, ready for connections
...
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

### Bootstrapping a one-node MariaDB cluster

There are 2 ways:

1) Include the `docker-compose.bootstrap.yaml` in the `docker-compose` command on the first node. On the first node (db1), run:

```bash
cd compose
docker-compose -f docker-compose.yaml -f docker-compose.bootstrap.yaml up -d
```
**OR**

2) Set the `--wsrep_cluster_address` in the `command` section to `gcomm://`:

```yaml
   command:
     - --wsrep_cluster_address=gcomm://
```

Then, use the standard up command:

```bash
cd compose
docker-compose up -d
```

Either way chosen, you shall see the following line, indicating this node is started with Galera replication:
```bash
$ docker-compose logs nextcloud-mariadb -f
...
2020-09-30  8:14:59 2 [Note] WSREP: Synchronized with group, ready for connections
...
```

That's it.

### Shutting down the MariaDB cluster

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

### Starting the cluster after an ungraceful shutdown

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

### Restarting a MariaDB node

Restarting a node is similar to stopping and starting a container:

```bash
cd compose
docker-compose down
docker-compose up -d
```

** MariaDB restart must be performed on one node at a time for a 3-node Galera cluster. For a 5-node Galera cluster, you can have maximum of 2 unavailable nodes at a time.

## Connecting to the MariaDB Server

### Networking and ports

By default, MariaDB Cluster should have the following ports open:

| Protocol | Ports | Description
| --- | --- | ---
| TCP | 3306 | MySQL
| TCP | 4444 | State Snapshot Transfer (SST)
| TCP/UDP | 4567 | Galera group communication and replication (gcomm://)
| TCP | 4568 | Incremental Snapshot Transfer (IST)
| TCP/UDP | 9999 | Backup streaming using socat (optional)

Running on IPv6 is possible but not recommended at the moment, due to many issues reported on SST handling and Galera communication. If IPv4 is not an option, run IPv6 with hostname/FQDN and use hostname/FQDN as the host identifier in the configuration options/variables/file.


### Administrator user

Most of the administration task can be performed by user `backup` since it has been granted with the `SUPER` privilege. The safest way to connect to the MySQL server via console as user `backup` is to use the following command:

```bash
docker-compose exec nextcloud-mariadb mysql --defaults-group-suffix=_backup
```

The above will connect to the MariaDB via socket, where we can verify that with `status` command:

```
MariaDB [(none)]> status
--------------
mysql  Ver 15.1 Distrib 10.5.5-MariaDB, for debian-linux-gnu (x86_64) using readline 5.2

Connection id:        138
Current database:
Current user:         backup@localhost
SSL:                  Not in use
Current pager:        stdout
Using outfile:        ''
Using delimiter:      ;
Server:               MariaDB
Server version:       10.5.5-MariaDB-1:10.5.5+maria~focal-log mariadb.org binary distribution
Protocol version:     10
Connection:           Localhost via UNIX socket
Server characterset:  utf8mb4
Db     characterset:  utf8mb4
Client characterset:  latin1
Conn.  characterset:  latin1
UNIX socket:          /run/mysqld/mysqld.sock
Uptime:               3 hours 29 min 8 sec

Threads: 13  Questions: 36259  Slow queries: 0  Opens: 19  Open tables: 13  Queries per second avg: 2.889
--------------
```

If you would like to connect as the `root` user (e.g, granting user), use the following command to access the MariaDB server via console:

```bash
docker-compose exec nextcloud-mariadb mysql -uroot -p
```

Specify the password as defined under `MYSQL_ROOT_PASSWORD` environment variable.

### Application user

The recommended way to create an application user is to use SQL files as in this example, [init/04-nextcloud.sql](https://github.com/safespring/nextcloud-db/blob/master/mariadb/compose/init/04-nextcloud.sql) to create `nextcloud` schema and `nextcloud@'%'` database user.

If you are running on a static environment, try to avoid using the wildcard `%`, when granting host. If you have ProxySQL on top of the cluster, the application user must be created on both MariaDB and ProxySQL, and the ProxySQL must be granted host to access the MariaDB server. For example, if you have a static environment with the following topology:

* 2-node Nextcloud: 192.168.10.11, 192.168.10.12
* 2-node ProxySQL: 192.168.10.101, 192.168.10.102
* 3-node MariaDB: 192.168.10.201, 192.168.10.202, 192.168.10.203

The recommended grant should be the following:
```sql
CREATE SCHEMA nextcloud;
CREATE USER 'nextcloud'@'%' IDENTIFIED BY '1Z&hw5oiN$2b#wkH';
GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'192.168.10.101'; -- proxysql1
GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'192.168.10.102'; -- proxysql2
GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'192.168.10.11'; -- nextcloud1
GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'192.168.10.12'; -- nextcloud1
```

If you choose to run the above SQL statements on the MariaDB server directly, just run it once on any healthy database node (see [Health Checks](#health-checks)). No `FLUSH PRIVILEGES` necessary if you grant using the `GRANT` statement. If you make changes directly to the `mysql.user` table, only then `FLUSH PRIVILEGES` is required. For example, one wants to modify the host IP address from 192.168.10.12 to 192.168.10.13, one would do the following on one of the healthy database nodes:

```sql
UPDATE mysql.user SET Host = '192.168.10.13' WHERE User = 'nextcloud' AND Host = '192.168.10.12';
FLUSH PRIVILEGES;
```


## Health Checks

### Cluster Integrity

In MariaDB Cluster, a node could be up and running (`mysqld` is running, port 3306 is listening) but the particular node is not in a healthy state. A healthy node/cluster in a MariaDB Cluster means:

1. `SHOW STATUS LIKE 'wsrep_ready'` = 'ON'
1. `SHOW STATUS LIKE 'wsrep_cluster_status'` = 'Primary'
1. `SHOW STATUS LIKE 'wsrep_cluster_size'` = {total number of nodes}
1. `SHOW STATUS LIKE 'wsrep_local_state_comment'` = 'Synced' OR
1. `SHOW STATUS LIKE 'wsrep_local_state_comment'` = 'Donor/Desynced' AND `SHOW GLOBAL VARIABLES LIKE 'wsrep_sst_method'` = 'mariabackup' or 'xtrabackup' or 'xtrabackup-v2'

ProxySQL performs the above health checks procedure to determine if a MariaDB Cluster node is healthy and operational. If you are connecting directly to the MariaDB server (bypassing load balancer), the above health checks might be required from the client point-of-view, to ensure you are connecting/querying/writing to the right node.

Common practice is to use the following statement:
```bash
docker-compose exec nextcloud-mariadb mysql --defaults-group-suffix=_backup -e "SHOW GLOBAL STATUS LIKE 'wsrep_%'"
```

If the node is not reporting as above, check the Docker logs since Galera will log everything into MySQL error log (syslog by default), regardless of the severity level:
```bash
docker-compose logs nextcloud-mariadb
```

In MariaDB 10.4 and later, we can also query the `wsrep_cluster_members` table to oversee the current cluster state:

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

## Backup & Restore

By default, the image will create a backup directory under `/backups/`. This should be mapped in the volume when starting the MariaDB container, for example:

```yaml
    volumes:
      - ${PWD}/datadir:/var/lib/mysql
      - ${PWD}/init:/docker-entrypoint-initdb.d
      - ${PWD}/conf:/etc/mysql/mariadb.conf.d
      - ${PWD}/backups:/backups
```

All backup credentials are stored in a specific files, `/etc/mysql/mariadb.conf.d/credentials.cnf`. The backup user is created automatically by [init/02-backup_user.sql](https://github.com/safespring/nextcloud-db/blob/master/mariadb/compose/init/02-backup_user.sql) during container initialization stage.

### Creating Backup

#### mariabackup

To create a physical backup using `mariabackup`, attach to the running service and specify the backup command:

```bash
cd compose
docker-compose exec nextcloud-mariadb mariabackup --backup --target-dir=/backups/mariabackup_$(date '+%Y-%m-%d_%H:%M:%S')
```

\* *The above `mariabackup` command reads the user credentials from `[mariabackup]` directive inside `credentials.cnf`.*

You will see some output. Make sure you see `Completed OK` in the last line. That's the indicator the backup is completed successfully.

Example created directory: `mariabackup_2020-10-02_06:40:39`

The `--target-dir` is the path **INSIDE** the container, as in this case, `/backups/mariabackup_2020-10-02_06:40:39/` of the container, mapped to `${PWD}/backups` on the Docker host.


#### mysqldump

To create a logical backup using `mysqldump`, attach to the running service and specify the backup command:

```bash
cd compose
docker-compose exec nextcloud-mariadb mysqldump --single-transaction --master-data=2 --all-databases | gzip > backups/mysqldump_$(date '+%Y-%m-%d_%H:%M:%S').sql.gz
```

\* *The above `mysqldump` command reads the user credentials from `[mysqldump]` directive inside `credentials.cnf`. The `--single-transaction` will make the backup non-blocking for InnoDB tables and `--master-data=2` will print out the binary log file, position and GTID in the output file, useful for PITR (See [PITR](#point-in-time-recovery-pitr)).*

Example mysqldump filename: `mysqldump_2020-09-28_09:23:59.sql.gz`

The mysqldump stdout output is redirected to the path **OUTSIDE** of the container, as in this case, the backup is saved to `backups/mysqldump_2020-09-28_09:23:59.sql.gz` relative to the current directory on the Docker host.

### Restoring Backup

### mariabackup



### mysqldump

Generally speaking, restoring mysqldump on a running Galera cluster is a slow operation, way slower than restoring on a standalone node. This is due to write events that being generated by the import process, where the MySQL client sends the SQL statements to MariaDB server and every single statement has to be replicated and certified by Galera to the other nodes.

For a small mysqldump size (<100MB), it might not have much impact so we can use the standard mysql import command:
```bash
gunzip backups/mysqldump_2020-09-28_09:23:59.sql.gz # extract the backup
docker-compose exec nextcloud-mariadb mysql --default-group-suffix=_backup < backups/mysqldump_2020-09-28_09:23:59.sql # restore the backup
```

For a big mysqldump size (>100MB), it's better to scale down the MariaDB Cluster size (e.g, from 3 nodes to 1, or 5 nodes to 1) to improve the speed of importing. Suppose we have a 3-node MariaDB Cluster, stop the MariaDB nodes on db3 and db2:

```bash
cd compose #db2
docker-compose down #db2
cd compose #db3
docker-compose down #db3
```

At this point, we should have a 1-node MariaDB Cluster (db1). Perform the import operation on this node with a bigger `--max-allowed-packet` value to improve the import process:

```bash
gunzip backups/mysqldump_2020-09-28_09:23:59.sql.gz # extract the backup on node1
docker-compose exec nextcloud-mariadb mysql --max-allowed-packet=128M --default-group-suffix=_backup < backups/mysqldump_2020-09-28_09:23:59.sql # restore the backup on node1
```

Then start again the other DB nodes to re-join the cluster (one node at a time):
```bash
cd compose #db2
docker-compose up -d #db2 - wait until it is synced first
cd compose #db3
docker-compose up -d #db3
```


### Point-in-time Recovery (PITR)

By default, binary log is enabled as in [conf/my.cnf](https://github.com/safespring/nextcloud-db/blob/master/mariadb/compose/conf/my.cnf). The binary log can be used to roll forward a MariaDB server to a point of time by replaying the binary events stored in the binary logs, e.g, restoring up until the moment right before the server crashed. To perform a MariaDB point-in-time recovery, the following are necessary:

1. Binary logs starting from the time the backup is restored, until the moment you want to recover.
1. `mysqlbinlog` utility.
1. A working full backup (mysqldump with `--master-data=1` or `--master-data=2`, or mariabackup).

Preferably, only the binary logs in the host where the backup is taken should be used to perform PITR. For example, if the backup was taken on db1, binary logs on db1 shall be replayed.

After restoring to backup on any of the nodes, extract the binary log file and position. For mysqldump, check at the dump file and look for the 'CHANGE MASTER' statement:

```bash
cd compose/backups
$ head -50 mysqldump_2020-10-06_11\:11\:59.sql | grep CHANGE
-- CHANGE MASTER TO MASTER_LOG_FILE='binlog.000030', MASTER_LOG_POS=339;
```

For mariabackup, the information is inside `xtrabackup_binlog_info`:

```bash
$ cd compose/backups
$ cat mariabackup_2020-10-06_11:14:15/xtrabackup_binlog_info
binlog.000030	339	1000-1000-7217
```

\* The starting point is binlog.000030 with position 339.

Then run the following command to start parsing the binary logs using `mysqlbinlog` and pass the output to the MariaDB client which then pass them to the MariaDB server:

```bash
docker-compose exec nextcloud-mariadb mysqlbinlog --start-position=339 /var/lib/mysql/binlog.000030 | mysql -uroot -p
```

The above will replay all events from that position until the last binary logs available in the directory. You could also use date & time and timestamp, and configure the end-time or end-position as well. Consult [MariaDB mysqlbinlog knowledgebase](https://mariadb.com/kb/en/using-mysqlbinlog/) for details.

### Flashback

Flashback (only for MariaDB) is a feature that will allow instances, databases or tables to be rolled back to an old snapshot. Traditionally, to perform a point-in-time recovery (PITR), one would restore a database from a backup, and replay the binary logs to roll forward the database state at a certain time or position.

With Flashback, the database can be rolled back to a point of time in the past, which is way faster if we just want to see the past that just happened not a long time ago. Occasionally, using flashback might be inefficient if you want to see a very old snapshot of your data relative to the current date and time. Restoring from a delayed slave, or from a backup plus replaying the binary log might be the better options.

1. Enable binary log with the following setting:

  a. `binlog_format` = 'ROW' (default since MySQL 5.7.7).

  b. `binlog_row_image` = 'FULL' (default since MySQL 5.6).
2. Use `msqlbinlog` utility from any MariaDB 10.2.4 and later installation.
3. Flashback is currently supported only over DML statements (INSERT, DELETE, UPDATE). An upcoming version of MariaDB will add support for flashback over DDL statements (DROP, TRUNCATE, ALTER, etc.) by copying or moving the current table to a reserved and hidden database, and then copying or moving back when using flashback.

## Upgrade
