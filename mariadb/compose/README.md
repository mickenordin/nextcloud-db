# Running with Docker Compose

In this example of Docker compose, we define two services:

1. **MariaDB server** (mandatory)
  - Service name: nextcloud-mariadb
  - Role: The database server
  - Listening ports: 3306, 4444, 4567, 4568
1. **MariaDB exporter** (optional)
  - Service name: mariadb-exporter
  - Role: Monitoring agent for Prometheus
  - Listening port: 9104
1. **Adminer** (optional)
    - Service name: adminer
    - Role: A lightweight MySQL/MariaDB GUI management tool
    - Listening port: 8080

\* *Feel free to remove the exporter service, if it is not necessary.*

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
docker-compose kill -s SIGTERM
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
docker-compose kill -s SIGTERM # graceful shutdown
docker-compose down # only if you want to remove the container
```

On db2:

```bash
cd compose
docker-compose kill -s SIGTERM # graceful shutdown
docker-compose down # only if you want to remove the container
```

On db1:

```bash
cd compose
docker-compose kill -s SIGTERM # graceful shutdown
docker-compose down # only if you want to remove the container
```
\* *By default, `docker-compose down` sends SIGTERM and wait for 10 seconds for a graceful timeout (followed by a SIGKILL after exceeding 10 seconds). The safest way is to use `kill` flag and send SIGTERM which has no timeout, and MariaDB should have all its time to shutdown gracefully (in case there are long running queries).*

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

In cases where all nodes were shut down ungracefully like a power trip, the MariaDB Cluster will be left with `safe_to_bootstrap: 0` and `seqno: -1` on all nodes. To verify this, check the content of `grastate.dat` under the MySQL data volume:

```bash
$ cat datadir/grastate.dat
# GALERA saved state
version: 2.1
uuid:    cb61f63f-01fd-11eb-9e62-6745e57d17ff
seqno:   -1
safe_to_bootstrap: 0
```

Since all nodes will have the same values (`seqno: -1` and `safe_to_bootstrap: 0`), none of them are guaranteed can be bootstrapped safely. Galera requires manual intervention to set the value back to 1 from the most up-to-date node in the cluster. To check which node is the most up-to-date ones, include the `docker-compose.recover.yaml` which appending the `--wsrep_recover` option:
```bash
cd compose
docker-compose -f docker-compose.yaml -f docker-compose.recover.yaml up --abort-on-container-exit
```

\* *The `--abort-on-container-exit` is necessary because with `--wsrep_recover` flag (defined in `docker-compose.recover.yaml`), MariaDB will be started temporarily, retrieve the Galera information and exit.*

Focus on the last line of the output. You should see something like this:
```
nextcloud-mariadb_1    | 2020-09-30  8:02:02 0 [Note] Plugin 'FEEDBACK' is disabled.
nextcloud-mariadb_1    | 2020-09-30  8:02:02 0 [Note] Server socket created on IP: '::'.
nextcloud-mariadb_1    | 2020-09-30  8:02:02 0 [Note] WSREP: Recovered position: cb61f63f-01fd-11eb-9e62-6745e57d17ff:22,1000-1000-7217
```

The recovered position for this node is 22. The first value (cb61f63f-01fd-11eb-9e62-6745e57d17ff) is the cluster UUID, the next value (22) is the Galera seqno and the last value (1000-1000-7217) is the MariaDB GTID position.

Now compare the Galera seqno value of 22 with other nodes. The highest value of this shall be started with `BOOTSTRAP=1`. If all nodes are reporting a same value, it means all nodes in the cluster are in the same consistent state. Therefore, you can pick any of the nodes to bootstrap.

Now on the chosen node, in this example let's say db1, run the bootstrap command as below:
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
docker-compose kill -s SIGTERM #db1
docker-compose up -d #db1
```

### Restarting a MariaDB node

Restarting a node is a combination of stopping (`kill -S SIGTERM`) and starting a container:

```bash
cd compose
docker-compose kill -s SIGTERM
docker-compose up -d
```

\* *MariaDB restart must be performed on one node at a time for a 3-node Galera cluster. For a 5-node Galera cluster, you can have maximum of 2 unavailable nodes at a time.*

\* *By default, `docker-compose down` sends SIGTERM and wait for 10 seconds for a graceful timeout (followed by a SIGKILL after exceeding 10 seconds). The safest way is to use `kill` flag and send SIGTERM which has no timeout, and MariaDB should have all its time to shutdown gracefully (in case there are long running queries).*

### Starting a MariaDB node with forced SST

Galera performs initial syncing via IST or SST before allowing a node to join the cluster. In some corner cases, IST could fail and the only way to solve this is to perform a full syncing operation called SST. SST is basically taking a full backup (default is `mariabackup`) of the donor and restore it on the joiner, bringing the joiner closer to the cluster state to catch up.

To force Galera SST, one would need to, at least, remove/rename the `grastate.dat` from the MariaDB directory:

```bash
cd compose
docker-compose down
rm -f datadir/grastate.dat # or simply remove/rename the datadir directory
docker-compose up -d
```

\* *Here we specified `docker-compose down` to force MariaDB to stop, regardless of the state since we are going to have a full syncing afterwards anyway.*

The above will trigger Galera to perform an SST operation before this node is allowed to join the cluster. This is practically useful especially after a restoration process, where you want the joiner node to ignore what it has and follow the bootstrapped (reference) node instead.

Depending on the database size and network, the SST operation could impact the donor (backup streaming process) and saturate the network if you have a limited bandwidth between nodes.

## Connecting to the MariaDB Server

### Networking and ports

MariaDB Cluster requires the following ports open:

| Protocol | Ports | Description
| --- | --- | ---
| TCP | 3306 | MySQL
| TCP | 4444 | State Snapshot Transfer (SST)
| TCP/UDP | 4567 | Galera group communication and replication (gcomm://)
| TCP | 4568 | Incremental Snapshot Transfer (IST)
| TCP/UDP | 9999 | Backup streaming using socat (optional)

Running on IPv6 is possible but not recommended at the moment, due to many issues reported on SST handling and Galera communication. If IPv4 is not an option, run IPv6 with hostname/FQDN and use hostname/FQDN as the host identifier in the configuration options/variables/file.


### Administrator user

Most of the administration task can be performed by user `backup` since it has been granted with the `SUPER` privilege (except `GRANT`). The safest way to connect to the MySQL server via console as user `backup` is to use the following command:

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

In this example, we create an application user by using an SQL file, [init/04-nextcloud.sql](https://github.com/safespring/nextcloud-db/blob/master/mariadb/compose/init/04-nextcloud.sql) to create `nextcloud` schema and `nextcloud@'%'` database user. All files under `init` directory will only be loaded once during the database initialization on the bootstrapped node. Data on the joiner nodes will always follow the bootstrapped node.

If you are running on a static environment, try to avoid using the wildcard `%`, when granting host. If you have ProxySQL on top of the cluster, the application user must be created on both MariaDB and ProxySQL, and the ProxySQL must be granted host to access the MariaDB server. For example, if you have a static environment with the following topology:

* 2-node Nextcloud: 192.168.10.11, 192.168.10.12
* 2-node ProxySQL: 192.168.10.101, 192.168.10.102
* 3-node MariaDB: 192.168.10.201, 192.168.10.202, 192.168.10.203

The recommended grant should be the following:
```sql
CREATE SCHEMA nextcloud;
GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'192.168.10.101' IDENTIFIED BY '1Z&hw5oiN$2b#wkH'; -- proxysql1
GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'192.168.10.102' IDENTIFIED BY '1Z&hw5oiN$2b#wkH'; -- proxysql2
GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'192.168.10.11' IDENTIFIED BY '1Z&hw5oiN$2b#wkH'; -- nextcloud1
GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'192.168.10.12' IDENTIFIED BY '1Z&hw5oiN$2b#wkH'; -- nextcloud2
```

Run the above statement once on any healthy database node (see [Health Checks](#health-checks)). No `FLUSH PRIVILEGES` necessary if you grant using the `GRANT` statement. If you make changes directly to the `mysql.user` table, only then `FLUSH PRIVILEGES` is required. For example, one wants to modify the host IP address from 192.168.10.12 to 192.168.10.13, one would do the following on one of the healthy database nodes:

```sql
UPDATE mysql.user SET Host = '192.168.10.13' WHERE User = 'nextcloud' AND Host = '192.168.10.12';
FLUSH PRIVILEGES;
```

### Management using GUI

Optionally, you can use Adminer for database administration, accessible on port 8080 of the Docker host. Open the web browser, and go to `http://{Host_IP_Address}:8080/`. You may login using the MariaDB root user or any user created under the `init` directory.

## Health Checks & Monitoring

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

### Network split

When a 3-node cluster is split, for example faulty switch which connect all the DB nodes, every MariaDB node will see itself as 1/3 (minority) and will be demoted to `Non-Primary` state. If this situation happens, your application will see this error:
```
ERROR 1047 WSREP has not yet prepared node for application use
```

To verify on this, check the `wsrep_cluster_status` status:

```bash
docker-compose exec nextcloud-mariadb mysql --defaults-group-suffix=_backup mysql -e 'SHOW STATUS LIKE "wsrep_cluster_status"'
```

When the network issue resolves after replacing the faulty switch, Galera should be able to resume the group communication and replication automatically, by merging the state of the nodes and form a new `Primary` component. If merging is not possible or could cause conflicts, Galera will stay down and require manual intervention to promote one of the node as Primary (a.k.a bootstrap).

Before bootstrapping a partitioned cluster, compare the `wsrep_last_committed` value on every node by using this command:
```bash
docker-compose exec nextcloud-mariadb mysql --defaults-group-suffix=_backup mysql -e 'SHOW STATUS LIKE "wsrep_last_committed"'
```

The node that holds the highest value of `wsrep_last_committed` shall be the reference node. Then, set `pc.bootstrap=YES` on the chosen node (for example db1) by running the following command:

```bash
docker-compose exec nextcloud-mariadb mysql --defaults-group-suffix=_backup mysql -e 'SET GLOBAL wsrep_provider_options="pc.bootstrap=YES"' # assuming db1 has the highest wsrep_last_committed value
```

After setting the above, the remaining nodes (db2 and db3) will recover themselves to rejoin the cluster automatically, because now they can see and compare themselves with the "single source of truth" (db1).

### Monitoring agent

This compose file also includes a monitoring service called `mariadb-exporter`. This is an optional service to be run and can be removed if not necessary. This service is basically a Prometheus agent, exporting the monitoring stats of the MariaDB server using a dedicated database user called `exporter`, as shown in this SQL file, [init/01-prometheus.sql](https://github.com/safespring/nextcloud-db/blob/master/mariadb/compose/init/01-prometheus.sql). The environment variable `DATA_SOURCE_NAME` must be configured with a correct DSN connection string, as in the following example:

```yaml
    environment:
      DATA_SOURCE_NAME: "exporter:BjF4242g5bYRswX490Mw@(127.0.0.1:3306)/information_schema"
```

Prometheus server scraper should be configured to connect to port 9104 of this `mariadb-exporter` container to retrieve the monitoring stats of the MariaDB container. Check out the [mysqld_exporter Github](https://github.com/prometheus/mysqld_exporter) and [Prometheus documentation](https://prometheus.io/docs/prometheus/latest/configuration/configuration/) for details.

## Configuration Management


### Configuration files

This compose example provides two MariaDB configuration files under [conf](https://github.com/safespring/nextcloud-db/blob/master/mariadb/compose/conf) directory, which should be mapped into `/etc/mysql/mariadb.conf.d` inside the container, as shown in the following excerpt:

```yaml
    volumes:
      - ${PWD}/datadir:/var/lib/mysql
      - ${PWD}/init:/docker-entrypoint-initdb.d
      - ${PWD}/conf:/etc/mysql/mariadb.conf.d
      - ${PWD}/backups:/backups
```

If you would like to extend the MariaDB configuration file to include your own configuration file, you can merge the configuration lines into `conf/my.cnf` for non-sensitive variables, or `conf/credentials.cnf` for sensitive variables. Having multiple overlapping configuration files is not recommended and can cause confusion on the order of which variable take precedence to be loaded into MariaDB. Try to stick with these two configuration files if possible.

### Dynamic variables

Most of the MariaDB configuration options (or variables) can be modified during runtime. Check the [MariaDB Server & System Variables](https://mariadb.com/kb/en/server-system-variables/) page and look for the "Dynamic" field. If "Yes", means the variable can be changed without a MariaDB restart. If you want to change a non-dynamic variable, see [Static variables](#static-variables).

To change a dynamic variable, use the `SET GLOBAL` statement. In this example, we want to change a dynamic variable `read_only` to `ON` on db2:

```bash
cd compose
docker-compose exec nextcloud-mariadb mysql --defaults-group-suffix=_backup -e 'SET GLOBAL read_only = "ON"'
```

To verify:
```bash
docker-compose exec nextcloud-mariadb mysql --defaults-group-suffix=_backup -e 'SHOW GLOBAL VARIABLES LIKE "read_only"'
+---------------+-------+
| Variable_name | Value |
+---------------+-------+
| read_only     | ON    |
+---------------+-------+
```

Then, add/append/modify the relevant line inside the MariaDB configuration file at `conf/my.cnf` to make it persistence across restart:

```bash
cd compose
vi conf/my.cnf # modify config file
```

### Static variables

To change a static variable which require a MariaDB restart, modify the `conf/my.cnf` file directly and restart the MariaDB server. For example, to increase the `innodb_read_io_threads` to 16, one would do:

```bash
cd compose
vi conf/my.cnf # modify the line innodb_read_io_threads and set the value to 16
docker-compose kill -s SIGTERM # stop MariaDB
docker-compose up -d # start MariaDB to load the new changes
```

Only perform static configuration changes one node at a time. Make sure the node is started and joined with the cluster before proceed to the next node.

## Backup & Restore

By default, the image will create a backup directory under `/backups`. This should be mapped with a Docker volume when starting the MariaDB container, for example:

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

Using mariabackup is the recommended way to create a full backup, especially if the database size is huge (>10GB). Backup performed by mariabackup is a hot-backup, meaning the process will not lock the database with condition that all tables are running on InnoDB storage engine (except mysql system tables which are running on MyISAM, but this can be neglected because they are relatively small).

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

To create a non-blocking logical backup using `mysqldump`, attach to the running service and specify the backup command with `--single-transaction` flag (only for InnoDB):

```bash
cd compose
docker-compose exec nextcloud-mariadb mysqldump --single-transaction --master-data=2 --all-databases | gzip > backups/mysqldump_$(date '+%Y-%m-%d_%H:%M:%S').sql.gz
```

\* *The above `mysqldump` command reads the user credentials from `[mysqldump]` directive inside `credentials.cnf`. The `--single-transaction` will make the backup non-blocking for InnoDB tables and `--master-data=2` will print out the binary log file, position and GTID in the output file, useful for PITR (See [PITR](#point-in-time-recovery-pitr)).*

Example mysqldump filename: `mysqldump_2020-09-28_09:23:59.sql.gz`

The mysqldump stdout output is redirected to the path **OUTSIDE** of the container, as in this case, the backup is saved to `backups/mysqldump_2020-09-28_09:23:59.sql.gz` relative to the current directory on the Docker host.

### Restoring Backup

### mariabackup

Backup created by Mariabackup is a binary backup, where it performs binary copy of the datadir while monitors the changes happens to the database until the copy operation completes. This means a backup created by Mariabackup is not a consistent backup and has to be prepared first. The prepare operation will roll forward the backup by replaying the InnoDB transaction log to make it consistent again and useful for restoration. After a backup has been prepared, you can simply swap the datadir with the prepared backup but this requires a downtime.

In this example, we would want to restore a full mariabackup located on db1 under directory `/backups/mariabackup_2020-10-06_11:14:15` inside the container.

0) Stop the applications to write to the server.

1) Prepare the backup on db1:

```bash
cd compose
docker-compose exec nextcloud-mariadb mariabackup --prepare --target-dir=/backups/mariabackup_2020-10-06_11:14:15
```

\* *The `--target-dir` is the backup path inside the container.*

You will see some output. Make sure you see `completed OK!` in the last line. That's the indicator the prepare is completed successfully.

2) Stop the cluster:

```bash
cd compose
docker-compose down # db3
docker-compose down # db2
docker-compose down # db1
```

\* *Here we are using `docker-compose down` because the server state does not matter anymore, since we are going to do full syncing afterwards.*

3) We will perform the restoration on db1. Rename the original datadir on db1:

```bash
cd compose
mv datadir datadir_bak
```

4) Copy the prepared backup as directory datadir on db1:

```bash
mkdir datadir
cp -r backups/mariabackup_2020-10-06_11:14:15/* datadir/*
```

5) Now the backup is restored on the db1. We have to bootstrap this node to become the reference node for the cluster:

```bash
docker-compose -f docker-compose.yaml -f docker-compose.bootstrap.yaml up -d
```

6) Proceed to start the remaining nodes, but we have to force SST by renaming/moving the `grastate.dat` on every joiner node:

```bash
cd compose
mv datadir/grastate.dat datadir/grastate.dat.bak # to force SST when starting up, so it will get the fresh copy from db1
docker-compose up -d # wait until the node is synced first
```

Repeat this step on the next nodes, one node at a time, until all nodes join the cluster.

7) Finally, restart the first database node, db1 so it will load up the correct `--wsrep_cluster_address`:

```bash
cd compose
docker-compose kill -s SIGTERM #db1
docker-compose up -d #db1
```

At this point the cluster is restored and operational. If you want to continue with point-in-time recovery (PITR), see [PITR](#point-in-time-recovery-pitr).

### mysqldump

Generally, restoring mysqldump on a running Galera cluster is a slow operation, way slower than restoring on a standalone node. This is due to write events that being generated by the import process, where the MySQL client sends the SQL statements to MariaDB server and every single statement has to be replicated and certified by Galera to the other nodes.

For a small mysqldump size (<100MB), it might not have much impact so we can use the standard mysql import command:
```bash
gunzip backups/mysqldump_2020-09-28_09:23:59.sql.gz # extract the backup
docker-compose exec nextcloud-mariadb mysql --defaults-group-suffix=_backup < backups/mysqldump_2020-09-28_09:23:59.sql # restore the backup
```

For a big mysqldump size (>100MB), it's better to scale down the MariaDB Cluster size (e.g, from 3 nodes to 1, or 5 nodes to 1) to improve the speed of importing. Suppose we have a 3-node MariaDB Cluster, stop the MariaDB nodes on db3 and db2:

```bash
cd compose #db2
docker-compose kill -s SIGTERM #db2
cd compose #db3
docker-compose kill -s SIGTERM #db3
```

At this point, we should have a 1-node MariaDB Cluster (db1). Perform the import operation on this node with a bigger `--max-allowed-packet` value to improve the import process:

```bash
gunzip backups/mysqldump_2020-09-28_09:23:59.sql.gz # extract the backup on db1
docker-compose exec nextcloud-mariadb mysql --defaults-group-suffix=_backup --max-allowed-packet=128M < backups/mysqldump_2020-09-28_09:23:59.sql # restore the backup on db1
```

Then start again the other DB nodes to re-join the cluster (one node at a time):
```bash
cd compose #db2
docker-compose up -d #db2 - wait until it is synced first
cd compose #db3
docker-compose up -d #db3
```

At this point the cluster is restored and operational. If you want to continue with point-in-time recovery (PITR), see [PITR](#point-in-time-recovery-pitr).

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

## Upgrade & Downgrade

### Minor version upgrade

Upgrading a minor version (10.5.y -> 10.5.z) should be pretty straightforward, which require no upgrade on the system tables within the same major version. Basically, we need to stop the current container and run a new container with an older Docker image, pointing to the same MariaDB datadir. Remember to perform this operation on one database node at a time, and if the upgrade on the first node fails, we still have chance to roll back to the current version.

This example shows that we would like to perform minor version upgrade to MariaDB 10.5.6 (image: `safespring/nextcloud-mariadb:10.5.6-2`) from MariaDB 10.5.5 (image: `safespring/nextcloud-mariadb:10.5.5-1`):

1) Before stopping the container, run the following command first to flag InnoDB to perform a slow shutdown, with full purge and change buffer merge:

```bash
docker-compose exec nextcloud-mariadb mysql --defaults-group-suffix=_backup -e 'SET GLOBAL innodb_fast_shutdown = 0'
```

2) Stop the container:

```bash
cd compose
docker-compose kill -s SIGTERM
```

3) Modify the compose file to use the older image:

```yaml
    image: safespring/nextcloud-mariadb:10.5.6-2
```

4) Start the container:

```bash
cd compose
docker-compose up -d
```

Check the Docker logs and make sure the node joins the cluster back without problem. Only proceed to the next nodes only the if the upgrade succeeds on this node, one node at a time.

### Major version upgrade

Upgrading a major version (10.5.x -> 10.6.x) should be handled with care. For a best result, make you sure you have upgraded to the latest minor version first, before attempting to upgrade to the new major version. For example, if you are running on MariaDB 10.5.5 and would like to upgrade 10.6.1, while the latest 10.5 version is 10.5.17, perform minor version upgrade first to 10.5.17, before attempting to upgrade to 10.6.1.

0) Make sure the MariaDB server have been updated to the latest minor version, and the new major version image is ready.

1) To be safe, stop the applications from writing on the database server because mixing nodes running on a different major version in a cluster could have a side-effect of writeset replication failure due to different Galera API version, different replication checksum, etc.

2) Stop the cluster with `innodb_fast_shutdown=0`:

```bash
docker-compose exec nextcloud-mariadb mysql --defaults-group-suffix=_backup -e 'SET GLOBAL innodb_fast_shutdown = 0' # db3
docker-compose kill -s SIGTERM # db3

docker-compose exec nextcloud-mariadb mysql --defaults-group-suffix=_backup -e 'SET GLOBAL innodb_fast_shutdown = 0' # db2
docker-compose kill -s SIGTERM # db2

docker-compose exec nextcloud-mariadb mysql --defaults-group-suffix=_backup -e 'SET GLOBAL innodb_fast_shutdown = 0' # db1
docker-compose kill -s SIGTERM # db1
```

3) Modify the `docker-compose.yaml` to use the new image, assuming the new image name is `safespring/nextcloud-mariadb:10.6.1-18`:

```yaml
    image: safespring/nextcloud-mariadb:10.6.1-18
```

4) Bootstrap the last node that goes down (db1):

```bash
cd compose
docker-compose -f docker-compose.yaml -f docker-compose.bootstrap.yaml up -d #db1
```

5) Run the upgrade script to upgrade MariaDB system tables on db1:

```bash
docker-compose exec nextcloud-mariadb mysql_upgrade -uroot -p --skip-write-binlog
```

\* *Make sure you see the last line reported as “OK”.*

Proceed to the next node only if all the commands above are successfully executed.

6) On the remaining nodes (db2 and db3), modify the `docker-compose.yaml` as shown in step 3, start the container and perform the `mysql_upgrade` script (one node at a time):

```bash
cd compose
vi docker-compose.yaml # modify the image name
docker-compose up -d # bring up the container
docker-compose exec nextcloud-mariadb mysql_upgrade -uroot -p --skip-write-binlog # upgrade system tables
```

Proceed to the next node only if all the commands above are successfully executed.

7) Finally, restart the bootstrapped node (db1) once more so it will load the correct `--wsrep_cluster_address` like the rest of the nodes:

```bash
cd compose
docker-compose kill -s SIGTERM #db1
docker-compose up -d #db1
```

### Minor version downgrade

Downgrading a minor version (10.5.y -> 10.5.z) should be pretty straightforward, since the MariaDB system tables should be the identical within the same major version. Simply stop the current container and run a new container with an older Docker image, pointing to the same MariaDB datadir.

This example shows that we would like to downgrade from MariaDB 10.5.6 (image: `safespring/nextcloud-mariadb:10.5.6-2`) to an older version MariaDB 10.5.5 (image: `safespring/nextcloud-mariadb:10.5.5-1`):

1) Before stopping the container, run the following command first to flag InnoDB to perform a slow shutdown, with full purge and change buffer merge:

```bash
docker-compose exec nextcloud-mariadb mysql --defaults-group-suffix=_backup -e 'SET GLOBAL innodb_fast_shutdown = 0'
```

2) Stop the container:

```bash
cd compose
docker-compose kill -s SIGTERM
```

3) Modify the compose file to use the older image:

```yaml
    image: safespring/nextcloud-mariadb:10.5.5-1
```

4) Start the container:

```bash
docker-compose up -d
```

Proceed to the remaining nodes, one node at a time.

### Major version downgrade

Downgrading a major version (e.g, 10.5.x -> 10.6.x) is possible, but the safest way is to be done via logical downgrade, meaning you have to export the database first and import it back to the version that you want.

Therefore, one would do the following if one wants to perform major version downgrade. The following example shows how to downgrade from MariaDB 10.6.1 (image: `safespring/nextcloud-mariadb:10.6.1-10`) to an older major version MariaDB 10.5.5 (image: `safespring/nextcloud-mariadb:10.5.5-1`):

1) Stop writing to the MariaDB server, otherwise data written after the backup has initiated will be lost.

2) Take a mysqldump backup on one of the host:

``` bash
cd compose
docker-compose exec nextcloud-mariadb mysqldump --single-transaction --master-data=2 --all-databases > backups/mysqldump_downgrade.sql
```

3) Stop the cluster.

```bash
cd compose
docker-compose down # db3
docker-compose down # db2
docker-compose down # db1
```
\* *Here we are using `docker-compose down` because the server state does not matter anymore, since we are going to do full syncing afterwards.*

4) Wipe the datadir:

```bash
cd compose
rm -Rf datadir/* # db1
rm -Rf datadir/* # db2
rm -Rf datadir/* # db3
```

5) Modify the `docker-compose.yaml` to the older image:

```yaml
    image: safespring/nextcloud-mariadb:10.5.5-1
```

6) Bootstrap a 1-node cluster first, to perform database import. On db1, run:

```bash
cd compose
docker-compose -f docker-compose.yaml -f docker-compose.bootstrap.yaml up -d
```

7) Start importing the database from mysqldump as user `root`. On db1, run:

```bash
cd compose
docker-compose exec nextcloud-mariadb mysql -uroot -p --max-allowed-packet=128M < backups/mysqldump_downgrade.sql
```

8) Start the remaining nodes (one node at a time):

```bash
cd compose
docker-compose up -d #db2, wait until it is synced first
docker-compose up -d #db3
```

Node joining might take some time, depending on the database size and network connection. Monitor the Docker logs output to see the progress.

9) Finally, restart the bootstrapped node (db1) once more so it will load the correct `--wsrep_cluster_address` like the rest of the nodes:

```bash
cd compose
docker-compose kill -s SIGTERM #db1
docker-compose up -d #db1
```


# Disclaimer

The configuration tuning in this example does not apply to all Nextcloud workloads. Some might require further tuning to improve read/write performance which based on the hardware specs, network latency, access pattern, number of simultaneous active users and many more.
