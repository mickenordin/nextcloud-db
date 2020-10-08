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

Therefore, the first step is to prepare ProxySQL configuration file, `proxysql.cnf` and map it into the container. Use the example [proxysql.cnf](https://github.com/safespring/nextcloud-db/blob/master/proxysql/compose/proxysql.cnf) as the template. Modify the following sections/lines accordingly:

1. IP address/hostname/FQDN of all ProxySQL servers:

```
proxysql_servers =
(
    { hostname="192.168.10.101" , port=6032 , comment="proxysql1" },
    { hostname="192.168.10.102" , port=6032 , comment="proxysql2" }
)
```

2. IP address/hostname/FQDN of all MariaDB Cluster servers:

```
mysql_servers =
(
    { address="192.168.10.201" , port=3306 , hostgroup=10, max_connections=100 },
    { address="192.168.10.202" , port=3306 , hostgroup=10, max_connections=100 },
    { address="192.168.10.203" , port=3306 , hostgroup=10, max_connections=100 }
)
```

3. Username and password of the MySQL users to pass through this ProxySQL:

```
mysql_users =
(
    { username = "nextcloud", password = "1Z&hw5oiN$2b#wkH", default_hostgroup = 10, transaction_persistent = 0, active = 1 },
    { username = "sbtest", password = "passw0rd", default_hostgroup = 10, transaction_persistent = 0, active = 1 }
)
```

Once `proxysql.cnf` is created, map it with the container as shown in the following excerpt of `docker-compose.yaml`:

```yaml
    volumes:
      - ${PWD}/proxysql.cnf:/etc/proxysql.cnf
```

Then start the ProxySQL container, using the common way:

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
ProxySQL> SHOW SCHEMAS;
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

## Load Balancer Management

###  Backend server status

To check the current backend server status from the ProxySQL point-of-view, we should query the runtime-related tables:

```sql
ProxySQL> SELECT hostgroup_id,hostname,status,weight FROM runtime_mysql_servers;
+--------------+---------------+---------+--------+
| hostgroup_id | hostname      | status  | weight |
+--------------+---------------+---------+--------+
| 10           | 89.45.237.133 | SHUNNED | 1      |
| 20           | 89.45.237.133 | ONLINE  | 1      |
| 30           | 89.45.237.133 | ONLINE  | 1      |
| 10           | 89.45.237.218 | ONLINE  | 1      |
+--------------+---------------+---------+--------+
```

| Status | Description |
| --- | --- |
| `ONLINE` | The backend server is fully operational.
| `OFFLINE_SOFT` | When a server is put into `OFFLINE_SOFT` mode, new incoming connections aren’t accepted anymore, while the existing connections are kept until they become inactive. In other words, connections are kept in use until the current transaction is completed. This makes it possible to gracefully detach a backend.
| `OFFLINE_HARD` | When a server is put into `OFFLINE_HARD` mode, the existing connections are dropped, while new incoming connections aren’t accepted either. This is equivalent to deleting the server from a hostgroup, or temporarily taking it out of the hostgroup for maintenance work.
| `SHUNNED` | The backend sever is temporarily taken out of use because of either too many connection errors in a time that was too short, or the replication lag exceeded the allowed threshold.


### Gracefully disabling a backend server

asd

### Setting server's weight

asd

### Adding a query rule

asd

### Adding a MySQL user

asd
