# Running ProxySQL with Docker Compose

In this example of Docker compose, we define 1 service:

1. **ProxySQL** (mandatory)
    - Service name: nextcloud-proxysql
    - Role: The database load balancer, sitting on top of MariaDB Cluster
    - Listening ports: 6033, 6032, 6080

## Service Control

### Starting ProxySQL

It's important to understand how ProxySQL loads the configuration options, so we know what to expect when administering ProxySQL. When starting up a fresh installation of ProxySQL instance, ProxySQL will:

1. Read the configuration options from `/etc/proxysql.cnf`, since `proxysql.db` does not exist yet.
2. Load the configuration options into runtime (memory).
3. Save the configuration options into disk (SQLite database - `/var/lib/proxysql/proxysql.db`).
4. If `proxysql.db` exists, `/etc/proxysql.cnf` will be ignored, unless ProxySQL is started with `--initial` flag.

Therefore, the first step is to prepare ProxySQL configuration file, `proxysql.cnf` and map it into the container. Use the example [proxysql.cnf](https://github.com/safespring/nextcloud-db/blob/master/proxysql/compose/proxysql.cnf) as the template. It is recommended to have at least 2 ProxySQL instances for redundancy purposes, and these instances should be configured with ProxySQL Clustering, by adding all ProxySQL instances into the `proxysql_servers` table as shown in the step 1.

0. Prepare 2 ProxySQL hosts and get the primary IP address of them. We will define all ProxySQL hosts inside `proxysql_servers` section as shown in step 1. The MariaDB Clusters should also be running in full capacity (3/3 nodes or 5/5 nodes) at this point. See [mariadb/compose](https://github.com/safespring/nextcloud-db/blob/master/mariadb/compose/) if you don't have a cluster running.

1. Modify the IP address/hostname/FQDN of all ProxySQL servers under `proxysql_servers` section:

```
proxysql_servers =
(
    { hostname="192.168.10.101" , port=6032 , comment="proxysql1" },
    { hostname="192.168.10.102" , port=6032 , comment="proxysql2" }
)
```

2. Modify the IP address/hostname/FQDN and the comment fields of all MariaDB Cluster servers:

```
mysql_servers =
(
    { address="89.45.237.193" , port=3306 , hostgroup=10, max_connections=100, comment="db1" },
    { address="89.45.237.218" , port=3306 , hostgroup=10, max_connections=100, comment="db2" },
    { address="89.45.237.133" , port=3306 , hostgroup=10, max_connections=100, comment="db3" }
)
```

3. Modify the username and password of the MySQL users to pass through this ProxySQL:

```
mysql_users =
(
    { username = "nextcloud", password = "1Z&hw5oiN$2b#wkH", default_hostgroup = 10, transaction_persistent = 0, active = 1 },
    { username = "sbtest", password = "passw0rd", default_hostgroup = 10, transaction_persistent = 0, active = 1 }
)
```

4. Modify the username and password of the ProxySQL monitoring user under `mysql_variables` section to be identical with [init/03-proxysql.sql](https://github.com/safespring/nextcloud-db/blob/master/mariadb/compose/init/03-proxysql.sql):

```
mysql_variables=
{
    ...
    monitor_username="proxysql"
    monitor_password="Cs923js&&Sv2kjBtw^s"
    ...
}
```

5. Modify the username and password of the ProxySQL `admin` user and `cluster_admin` under `admin_variables`:

```
admin_variables=
{
    admin_credentials="admin:P6dg&6sKJc$Z#ysVx;cluster_admin:Ly7Gsdt^SfWnx1Xb3"
    ...
}
```

\* *Note that we defined `admin_credentials` with 2 admin users - `admin` and `cluster_admin`, separated by a semi-colon. The `admin` user is for ProxySQL administration while the `cluster_admin` is for automatic configuration syncing between ProxySQL servers (a.k.a ProxySQL Clustering). The `cluster_admin` credentials in this line must be identical with `cluster_username` and `cluster_password` variables.*

6. Once `proxysql.cnf` is created, map it with the container as shown in the following excerpt of `docker-compose.yaml`:

```yaml
    volumes:
      - ${PWD}/proxysql.cnf:/etc/proxysql.cnf
      - ${PWD}/conf:/etc/mysql/conf.d/
```

7. Then start the ProxySQL container on the first node, using the common way:

```bash
cd compose
docker-compose up -d
```


8. Then start the ProxySQL container on the second node, using the common way:

```bash
cd compose
docker-compose up -d
```


### Stopping ProxySQL

Stopping a ProxySQL is similar to stopping a container:

```bash
cd compose
docker-compose down
```

### Restarting ProxySQL

Restarting a ProxySQL is similar to restarting a container:

```bash
cd compose
docker-compose restart
```

## Connecting to ProxySQL

### Connect as ProxySQL admin user

ProxySQL administrator user is created during the start up using the value specified as in `admin-admin_credentials` inside `proxysql.cnf`. By default, you can connect to the ProxySQL instance on port 6032 using the `mysql` client:

```bash
docker-compose exec nextcloud-proxysql mysql
```

\* *The above `mysql` command reads the user credentials from `[mysql]` directive inside `conf/my.cnf`.*

After connecting to it, you’ll see a MySQL-compatible interface for querying the various ProxySQL-related tables. Some basic commands:

```sql
ProxySQL> SHOW DATABASES;
ProxySQL> SHOW TABLES; -- ProxySQL administration tables
ProxySQL> SHOW TABLES FROM stats; -- stats & monitoring tables
ProxySQL> status; -- connection status
ProxySQL> LOAD ADMIN VARIABLES INTO RUNTIME;
ProxySQL> LOAD MYSQL VARIABLES INTO RUNTIME;
ProxySQL> LOAD MYSQL SERVERS INTO RUNTIME;
ProxySQL> LOAD MYSQL USERS INTO RUNTIME;
ProxySQL> SAVE ADMIN VARIABLES TO DISK;
ProxySQL> SAVE MYSQL VARIABLES TO DISK;
ProxySQL> SAVE MYSQL SERVERS TO DISK;
ProxySQL> SAVE MYSQL USERS TO DISK;
```

To perform a configuration change using this interface, see [Config changes on runtime (no restart required)](#config-changes-on-runtime-no-restart-required).

### Connect as application user

ProxySQL acts as a middle-man between the client and the database servers. When a client connect to the load balanced port 6033 (configurable with `mysql-interfaces` variable), the client will see this ProxySQL as "another MariaDB server". ProxySQL treats the front-end (client <-> ProxySQL) and back-end (ProxySQL <-> MariaDB server) connections as two different entities. Sometimes, ProxySQL doesn't even need to create a backend connection to response to the client, e.g, if the query is already in ProxySQL's query cache.

However, ProxySQL requires the MariaDB user credentials to be stored inside `mysql_users`, so it can perform the necessary actions on behalf of the client. Therefore, the ProxySQL host must be granted to access the MariaDB server in the `CREATE USER` or `GRANT` statement. See [Adding a MariaDB user](#adding-a-mariadb-user) section for examples.

The following example shows a standard mysql client to access the MariaDB server via ProxySQL:

```bash
mysql -u nextcloud -p -h 192.168.10.101 -P 6033
```

## Configuration Management

There are 2 ways to perform configuration management in ProxySQL when running on Docker, depending whether you want to restart the ProxySQL service or not.

### Config changes on configuration file (require restart)

If you prefer to perform configuration changes via configuration file (modifying the configuration file and restart ProxySQL), the ProxySQL must be started with environment variable `INITIALIZE=1`, as shown in the following excerpt of `docker-compose.yaml`:

```yaml
    environment:
      INITIALIZE: 1
```

If `INITIALIZE=1`, ProxySQL will be started with `--initial` flag to ignore the existing `proxysql.db` SQLite and delete this database. Next, ProxySQL will parse the configuration options from the configuration file and load them into runtime and finally save it into the disk on a new `proxysql.db`.

----
!! IMPORTANT NOTE !!

If a database file (`proxysql.db`) is found, the `/etc/proxysql.cnf` config file will be ignored.

----

### Config changes on runtime (no restart required)

ProxySQL config change works similar to a Cisco router, with 3 different configuration layers:

1. Runtime - Operators can never modify the contents of the RUNTIME. It must be performed from the lower layer like MEMORY or DISK.
2. Memory - When making a direct modification via a MySQL client, you are basically at this layer.
3. Disk and configuration file - When making a direct modification to ProxySQL configuration file or via an SQLite DB client, you are basically at this layer.

Modifying the config at runtime is done through the MySQL admin port of ProxySQL (6032 by default) with the username and password as in `admin-admin_credentials`. After connecting to it, you’ll see a MySQL-compatible interface for querying the various ProxySQL-related tables:

```bash
docker-compose exec nextcloud-proxysql mysql
```

\* *The above `mysql` command reads the user credentials from `[mysql]` directive inside `conf/my.cnf`.*

Once you are connecting to the console, you can use the SQL statement to make modification. In this example, we would like to change the `mysql-server_version` to "10.5.6" inside `global_variables` table:

```sql
ProxySQL> UPDATE global_variables SET variable_value = '10.5.6' WHERE variable_name = 'mysql-server_version';
```

The above change is happening in memory and is not loaded into runtime. After making the above modification, we have to run the following command to activate it:

```sql
ProxySQL> LOAD MYSQL VARIABLES TO RUNTIME;
```

To verify if our MySQL-related variable has been loaded into runtime, query the `runtime_global_variables` table:

```sql
ProxySQL> SELECT * FROM runtime_global_variables WHERE variable_name = 'mysql-server_version';
```

Then, we need to push this change into disk to make it persistent across restart:

```sql
ProxySQL> SAVE MYSQL VARIABLES TO DISK;
```

Configuration change should be performed on ONE ProxySQL node only, and it will be automatically synced over to the other nodes defined inside `proxysql_servers` table.

## Load Balancer Management

###  Backend server and routing status

To understand the current backend servers and routing status, we should query the runtime-related tables as shown below:

```sql
ProxySQL> SELECT hostgroup_id,hostname,port,status,weight,comment FROM runtime_mysql_servers ORDER BY hostgroup_id;
+--------------+---------------+------+---------+--------+---------+
| hostgroup_id | hostname      | port | status  | weight | comment |
+--------------+---------------+------+---------+--------+---------+
| 10           | 89.45.237.133 | 3306 | SHUNNED | 1      | db3     |
| 10           | 89.45.237.193 | 3306 | SHUNNED | 1      | db1     |
| 10           | 89.45.237.218 | 3306 | ONLINE  | 1      | db2     |
| 20           | 89.45.237.133 | 3306 | ONLINE  | 1      | db3     |
| 20           | 89.45.237.193 | 3306 | ONLINE  | 1      | db1     |
| 30           | 89.45.237.133 | 3306 | ONLINE  | 1      | db3     |
| 30           | 89.45.237.193 | 3306 | ONLINE  | 1      | db1     |
+--------------+---------------+------+---------+--------+---------+
```

ProxySQL backend host status:

| Status | Description |
| --- | --- |
| `ONLINE` | The backend server is fully operational.
| `OFFLINE_SOFT` | When a server is put into `OFFLINE_SOFT` mode, new incoming connections aren’t accepted anymore, while the existing connections are kept until they become inactive. In other words, connections are kept in use until the current transaction is completed. This makes it possible to gracefully detach a backend.
| `OFFLINE_HARD` | When a server is put into `OFFLINE_HARD` mode, the existing connections are dropped, while new incoming connections aren’t accepted either. This is equivalent to deleting the server from a hostgroup, or temporarily taking it out of the hostgroup for maintenance work.
| `SHUNNED` | The backend sever is temporarily taken out of use because of too many connection errors in a time that was too short, or the replication lag exceeded the allowed threshold, or to comply with Galera hostgroup `max_writers` configuration.

To understand the query routing, we also need to check the ProxySQL query rules:

```sql
ProxySQL> SELECT rule_id,match_pattern,apply,active,destination_hostgroup FROM runtime_mysql_query_rules;
+---------+-----------------------+-------+--------+-----------------------+
| rule_id | match_pattern         | apply | active | destination_hostgroup |
+---------+-----------------------+-------+--------+-----------------------+
| 100     | ^SELECT .* FOR UPDATE | 1     | 1      | 10                    |
| 200     | ^SELECT .*            | 1     | 1      | 30                    |
| 300     | .*                    | 1     | 1      | 10                    |
+---------+-----------------------+-------+--------+-----------------------+

```

To understand how ProxySQL performs host grouping, check Galera hostgroup settings:

```sql
ProxySQL> SELECT * FROM runtime_mysql_galera_hostgroups\G
*************************** 1. row ***************************
       writer_hostgroup: 10
backup_writer_hostgroup: 20
       reader_hostgroup: 30
      offline_hostgroup: 9999
                 active: 1
            max_writers: 1
  writer_is_also_reader: 2
max_transactions_behind: 30
                comment:
```

From the `runtime_mysql_servers`, `runtime_mysql_query_rules` and `runtime_mysql_galera_hostgroups` output, we can summarise the following:

* [ Rule ID : 100 & 300 ]
The ONLINE MariaDB node of hostgroup 10 is the single writer, because we configure `max_writers=1` inside `runtime_mysql_galera_hostgroups`. Therefore, all writes will be processed by 89.45.237.218 (db2).

* [ Rule ID : 200 ] The ONLINE MariaDB nodes of hostgroup 30 are the multi-reader. Therefore, all reads (all `SELECT` except `SELECT .. FOR UPDATE`) will be processed by 89.45.237.193 (db1) and 89.45.237.133 (db3).

* The ONLINE MariaDB nodes of hostgroup 20 are the backup writers. This hostgroup is not being used as a destination in the query rules.

### Adding a new query rule

Important notes regarding ProxySQL query rules:

* Query rules are processed as ordered by `rule_id`.
* Only rules that have `active=1` are processed. Because query rules is a very powerful tool and if it’s misconfigured, it can lead to difficult debugging, by default `active=0`. You should double check rules RegExes before enabling them.
* Pay a lot of attention to RegEx to avoid some rules matching what they shouldn’t.
* The `apply=1` means that no further rules are checked if there is a match. With `apply=0`, we can make rule chaining.

In this example, we would like to have a specific SELECT query to always hit the single-writer node (hostgroup 10). Ideally, we would want to process this SELECT query before the wildcard SELECT (rule 200). Hence, we will add a new rule with ID 150 using the following statement:

```sql
ProxySQL> INSERT INTO mysql_query_rules (rule_id,match_pattern,active,apply,destination_hostgroup) VALUES (150,'^ SELECT session FROM active_users',1,1,10);
ProxySQL> LOAD MYSQL QUERY RULES TO RUNTIME; -- to activate the changes
ProxySQL> SAVE MYSQL QUERY RULES TO DISK; -- after verify the query rule is correct
```

\* *Do not forget to commit the changes in MEMORY into RUNTIME to activate the query rule processing.*

### Adding a MariaDB user

The MariaDB user must be created on both MariaDB and ProxySQL, and the ProxySQL must be granted host to access the MariaDB server. For example, if you have a static environment with the following topology:

* 2-node Nextcloud: 192.168.10.11, 192.168.10.12
* 2-node ProxySQL: 192.168.10.101, 192.168.10.102
* 3-node MariaDB: 192.168.10.201, 192.168.10.202, 192.168.10.203

The recommended grant on the MariaDB server should be:
```sql
GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud2'@'192.168.10.101' IDENTIFIED BY '1Z&hw5oiN$2b#wkH'; -- proxysql1
GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud2'@'192.168.10.102' IDENTIFIED BY '1Z&hw5oiN$2b#wkH'; -- proxysql2
GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud2'@'192.168.10.11' IDENTIFIED BY '1Z&hw5oiN$2b#wkH'; -- nextcloud1
GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud2'@'192.168.10.12' IDENTIFIED BY '1Z&hw5oiN$2b#wkH'; -- nextcloud2
```
\* *You could also grant multiple hosts at once using wildcard, for example `192.168.10.%`.*

Once the above user is created on the MariaDB server, login to ProxySQL admin console:

```bash
docker-compose exec nextcloud-proxysql mysql
```

Then, add the user into ProxySQL:

```sql
ProxySQL> INSERT INTO mysql_users (username,password,default_hostgroup,transaction_persistent) VALUES ('nextcloud2','1Z&hw5oiN$2b#wkH',10,0);
ProxySQL> LOAD MYSQL USERS TO RUNTIME;
ProxySQL> SAVE MYSQL USERS TO DISK;
```

Make sure `default_hostgroup` value is set to 10, the `writer_hostgroup` value. At this point, the database user `nextcloud2` should be able to connect to the MariaDB server via ProxySQL, on port 6033.

### Disable a backend server gracefully

If a backend server (MariaDB server) needs to be put under maintenance, it's recommended to set the status to `OFFLINE_SOFT`, which indicates ProxySQL to start to mark the backend server gracefully, waiting for any active connections to complete and will not create a new connection to the database servers anymore.

To set `OFFLINE_SOFT`, use the following command:

```sql
ProxySQL> UPDATE mysql_servers SET status = 'OFFLINE_SOFT' WHERE hostname = '89.45.237.133';
ProxySQL> LOAD MYSQL SERVERS TO RUNTIME; -- to activate the changes
```

Wait for a couple of minutes (ProxySQL has to gracefully terminate any active connections, connection pooling, persistent connection, etc) and verify by querying at the `runtime_mysql_servers` table:

```sql
ProxySQL> SELECT hostgroup_id,hostname,port,status,weight,comment FROM runtime_mysql_servers ORDER BY hostgroup_id;
```

Note that you only need to make this modification on one of the ProxySQL nodes. The modification will get synced to the other ProxySQL nodes after `LOAD .. TO RUNTIME` statement is executed.

## System Statistics and Monitoring

### Stats database

ProxySQL exports a lot of metrics, all visible in the `stats` schema and queryable using any client that uses the MySQL protocol.

Log in as ProxySQL administrator:

```bash
docker-compose exec nextcloud-proxysql mysql
```

Once logged in, we can query any the tables inside `stats` schema to get monitoring insights:

```sql
ProxySQL> SHOW TABLES FROM stats;
+--------------------------------------+
| tables                               |
+--------------------------------------+
| global_variables                     |
| stats_memory_metrics                 |
| stats_mysql_commands_counters        |
| stats_mysql_connection_pool          |
| stats_mysql_connection_pool_reset    |
| stats_mysql_errors                   |
| stats_mysql_errors_reset             |
| stats_mysql_free_connections         |
| stats_mysql_global                   |
| stats_mysql_gtid_executed            |
| stats_mysql_prepared_statements_info |
| stats_mysql_processlist              |
| stats_mysql_query_digest             |
| stats_mysql_query_digest_reset       |
| stats_mysql_query_rules              |
| stats_mysql_users                    |
| stats_proxysql_servers_checksums     |
| stats_proxysql_servers_metrics       |
| stats_proxysql_servers_status        |
+--------------------------------------+
```

Some important tables when monitoring and debugging:

| Table | Description |
| --- | --- |
| `stats_mysql_query_digest` |  Summary of queries that have been processed by ProxySQL. To reset the sampling, just query the `stats_mysql_query_digest_reset` table which resets the internal statistics to zero.
| `stats_mysql_processlist` | Shows all process list that are currently being performed by ProxySQL.
| `stats_mysql_connection_pool` | Connection pooling stats. To reset the sampling, just query the `stats_mysql_connection_pool_reset` table which resets the internal statistics to zero.
| `stats_proxysql_servers_checksums` | Summary of ProxySQL configuration checksums, to track configuration changes between ProxySQL servers.

### Web GUI (stats only)

Web UI stats is available at port 6080, [https://{Host_IP_Address}:6080/](https://{Host_IP_Address}:6080/) and login as user `stats` as in `admin-stats_credentials` variable.

It's mandatory to use HTTPS to access this interface. Use browser that can tolerate unsecured HTTPS site like Firefox. Once you login, a dashboard with generic information is displayed. From here, you can choose a category to get useful metrics. This feature is still in beta, and subject to changes in the future.
