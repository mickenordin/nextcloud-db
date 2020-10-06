# Running ProxySQL with Docker Compose

## Service Control

### Starting ProxySQL

It's important to understand how ProxySQL loads the configuration options, so we know what to expect when running ProxySQL service. When starting up a fresh installation of ProxySQL instance, ProxySQL will:

1. Read the configuration options from `/etc/proxysql.cnf`, since `proxysql.db` does not exist yet.
2. Load the configuration options into runtime (memory).
3. Save the configuration options into disk (SQLite database - `/var/lib/proxysql/proxysql.db`).
4. If `proxysql.db` exists, `/etc/proxysql.cnf` will be ignored, unless ProxySQL is started with `--initial` flag.

Therefore, the first step is to prepare ProxySQL configuration file, `proxysql.cnf` and map it into the container. Use the example `proxysql.cnf` as the template. Modify the following sections/lines accordingly:

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

## Configuration Management

There are 2 ways to perform configuration management in ProxySQL when running on Docker, depending whether you want to restart the service or not.

### Config changes on configuration file (require restart)

If you prefer to perform configuration changes via configuration file (modifying the configuration file and restart ProxySQL), the ProxySQL must be started with environment variable `INITIALIZE=1`, as shown in the following excerpt of `docker-compose.yaml`:

```yaml
    environment:
      INITIALIZE: 1
```

With this flag, ProxySQL will be started with `--initial` flag to ignore the existing `proxysql.db` SQLite and delete this database. Next, ProxySQL will parse the configuration options from the configuration file and load it into runtime and finally save it into the disk on a new `proxysql.db`.

----
!! IMPORTANT NOTE !!

If a database file (`proxysql.db`) is found, the `/etc/proxysql.cnf `config file is not parsed.

----

### Config changes on runtime (no restart required)

ProxySQL config change works similar to a Cisco router, with 3 different configuration layers:

1. Runtime - Operators can never modify the contents of the RUNTIME. It must be performed from the lower layer like MEMORY or DISK.
2. Memory - When making a direct modification via a MySQL client, you are basically at this layer.
3. Disk and configuration file - When making a direct modification to ProxySQL configuration file or via an SQLite DB client, you are basically at this layer.

Modifying the config at runtime is done through the MySQL admin port of ProxySQL (6032 by default) with the username and password as in `admin-admin_credentials`. After connecting to it, you’ll see a MySQL-compatible interface for querying the various ProxySQL-related tables:

```bash
docker-compose exec nextcloud-proxysql mysql -u
```


### Modifyinng a new
