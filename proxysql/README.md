# nextcloud-proxysql Docker Image

## Supported Tags

* 2.0.14-1,latest,beta (Dockerfile)

## Overview

ProxySQL image to run on Docker, specifically built, tested and tuned for the following:

* Nextcloud workload
* MariaDB Cluster 10.5 (Galera) as the database backend
* ProxySQL clustering
* Integration with Keepalived for virtual IP address
* Docker "host" networking
* Docker host is running on Ubuntu 20.04 (focal) amd64 architecture

## Image Description

This image is maintained by Severalnines and will be updated regularly for every ProxySQL minor release (2.0.x. The image is based on Ubuntu 20.04 (Focal) and consists of:

* mysql client
* ProxySQL package for Ubuntu 20.04 (focal)

## Build

To build the image:

```
$ git clone https://github.com/safespring/nextcloud-db
$ cd nextcloud-db/proxysql
$ docker build -t safespring/nextcloud-proxysql:latest .
```

It's recommended to have a proper versioning number to track changes between images:

```bash
$ docker build -t safespring/nextcloud-proxysql:2.0.14-1 .
```

### Versioning

The tag naming format is:
`{vendor}/{image_name}:{software_version}-{build_number_identifier}`

The `build_number` is an identifier in integer format, identical for every build and shall be incrementing. For example, suppose we have an image tagged as `safespring/nextcloud-proxysql:2.0.14-89`. For a new ProxySQL version 2.0.15, the image tag should be:

```bash
$ docker build -t safespring/nextcloud-proxysql:2.0.15-90 .
```

## Run

To run a ProxySQL container with a custom ProxySQL configuration file:

```
$ docker run -d \
--name proxysql1 \
--publish 6033:6033 \
--publish 6032:6032 \
--publish 6080:6080 \
--restart=unless-stopped \
-v /root/proxysql/proxysql.cnf:/etc/proxysql.cnf \
safespring/nextcloud-proxysql:latest
```

The above commands requires a number of pre-configuration as below:

1. A `proxysql.cnf` must be prepared first. Example as in [](https://github.com/safespring/nextcloud-db/tree/master/proxsqyl#proxysqlcnf). This file shall be mapped with `/etc/proxysql.cnf` inside the container.
2. Default ProxySQL ports are:

  a. 6033 - MySQL/MariaDB load-balanced port.

  b. 6032 - ProxySQL management port.

  c. 6080 - Web UI for stats.

## Docker Compose

The [compose](https://github.com/safespring/nextcloud-db/tree/master/proxysql/compose) directory provides example compose files including instructions and documentation.

## Environment Variables

| Variables | Description  |
| --------- | ------------ |
| `INITIALIZE=0\|1` | Default is 0, means ProxySQL will be started as normal, loading the configuration options inside its `proxysql.db`. Set to 1 if you make direct modification to the ProxySQL configuration file and you want ProxySQL to load everything from it.

## ProxySQL.cnf

```bash
datadir="/var/lib/proxysql"

# ProxySQL admin configuration section
admin_variables=
{
    admin_credentials="admin:P6dg&6sKJc$Z#ysVx;cluster_admin:Ly7Gsdt^SfWnx1Xb3"
    mysql_ifaces="0.0.0.0:6032"
    refresh_interval=2000
    web_enabled=true
    web_port=6080
    stats_credentials="stats:P6dg&6sKJc$Z#ysVx"
    cluster_username="cluster_admin"
    cluster_password="Ly7Gsdt^SfWnx1Xb3"
    cluster_check_interval_ms=200
    cluster_check_status_frequency=100
    cluster_mysql_query_rules_save_to_disk=true
    cluster_mysql_servers_save_to_disk=true
    cluster_mysql_users_save_to_disk=true
    cluster_proxysql_servers_save_to_disk=true
    cluster_mysql_query_rules_diffs_before_sync=3
    cluster_mysql_servers_diffs_before_sync=3
    cluster_mysql_users_diffs_before_sync=3
    cluster_proxysql_servers_diffs_before_sync=3
}

# MySQL/MariaDB related section
mysql_variables=
{
    threads=4
    max_connections=2048
    default_query_delay=0
    default_query_timeout=36000000
    have_compress=true
    poll_timeout=2000
    interfaces="0.0.0.0:6033;/tmp/proxysql.sock"
    default_schema="information_schema"
    stacksize=1048576
    server_version="10.5.5"
    connect_timeout_server=10000
    monitor_history=60000
    monitor_connect_interval=200000
    monitor_ping_interval=200000
    ping_interval_server_msec=10000
    ping_timeout_server=200
    commands_stats=true
    sessions_sort=true
    monitor_username="proxysql"
    monitor_password="Cs923js&&Sv2kjBtw^s"
    monitor_galera_healthcheck_interval=2000
    monitor_galera_healthcheck_timeout=800
}


# Specify all ProxySQL hosts here
proxysql_servers =
(
    { hostname="89.45.237.193" , port=6032 , comment="proxysql1" },
    { hostname="89.45.237.218" , port=6032 , comment="proxysql2" }
)

# HG10 - single-writer
# HF30 - multi-writer
mysql_galera_hostgroups =
(
    {
        writer_hostgroup=10
        backup_writer_hostgroup=20
        reader_hostgroup=30
        offline_hostgroup=9999
        max_writers=1
        writer_is_also_reader=2
        max_transactions_behind=30
        active=1
    }
)

# List all MariaDB Galera nodes here
mysql_servers =
(
    { address="89.45.237.193" , port=3306 , hostgroup=10, max_connections=100 },
    { address="89.45.237.218" , port=3306 , hostgroup=10, max_connections=100 },
    { address="89.45.237.133" , port=3306 , hostgroup=10, max_connections=100 }
)

# Default query rules:
#  - All writes -> HG10 (single-writer)
#  - All reads  -> HG30 (multi-writer)
mysql_query_rules =
(
    {
        rule_id=100
        active=1
        match_pattern="^SELECT .* FOR UPDATE"
        destination_hostgroup=10
        apply=1
    },
    {
        rule_id=200
        active=1
        match_pattern="^SELECT .*"
        destination_hostgroup=30
        apply=1
    },
    {
        rule_id=300
        active=1
        match_pattern=".*"
        destination_hostgroup=10
        apply=1
    }
)

# All MySQL user that you want to pass through this instance
#  - The MySQL user must be created first in the DB server and grant it to access from this ProxySQL host
mysql_users =
(
    { username = "nextcloud", password = "1Z&hw5oiN$2b#wkH", default_hostgroup = 10, transaction_persistent = 0, active = 1 },
    { username = "sbtest", password = "passw0rd", default_hostgroup = 10, transaction_persistent = 0, active = 1 }
)
```
