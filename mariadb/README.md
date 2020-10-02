# nextcloud-mariadb Docker Image

## Supported Tags

* 10.5.5-1,latest,beta (Dockerfile)

## Overview

MariaDB image to run on Docker, specifically built, tested and tuned for the following workload:

* Nextcloud
* MariaDB Cluster (Galera)
* ProxySQL read-write splitting
* Docker "host" networking
* Docker host is running on Ubuntu 20.04 (focal) amd64 architecture

## Image Description

Derived from the [official MariaDB Docker repository](https://hub.docker.com/_/mariadb), this image is maintained by Severalnines and will be updated regularly for every MariaDB minor release on the same major version. It follows the same build flow, environment variables, coding style and volume mapping configuration as the official MariaDB image.

The image is based on Ubuntu 20.04 (Focal) and consists of:

* MariaDB packages for Ubuntu 20.04 (focal) - mariadb-server, mariadb-client, mariadb-backup
* Helper and debugging tools - sysstat, rsync, pigz, pv

Some customizations/improvements have been added into this image, particularly:

1. Allows database initialization if `wsrep_on` is set to `ON`.
2. A backup directory called `backups`, for Docker volume mapping.
3. Additional packages for MariaDB helper and debugging (sysstat, pigz, pv).
4. Two new environment variables:
  * `BOOTSTRAP={1|0}` - If set to 1, the container will be started as a bootstrapped node with `--wsrep_cluster_address=gcomm://`.
  * `FORCE_BOOTSTRAP={1|0}` - If set to 1, the entrypoint script will override the `safe_to_bootstrap` option inside Galera state file, `grastate.dat`. The value is usually set to 0 if the Galera node was terminated ungracefully.


## Build

To build the image with the `latest` tag:

```bash
$ git clone https://github.com/safespring/nextcloud-db
$ cd nextcloud-db/mariadb
$ docker build -t safespring/nextcloud-mariadb:latest .
```
It's recommended to have a proper versioning number to track changes between images:

```bash
$ docker build -t safespring/nextcloud-mariadb:10.5.5-1 .
```

### Versioning

The tag naming format is:
`{vendor}/{image_name}:{software_version}-{build_number_identifier}`

The `build_number` is an identifier in integer format, identical for every build and shall be incrementing. For example, suppose we have an image tagged as `safespring/nextcloud-mariadb:10.5.5-89`. For a new MariaDB version 10.5.6, the image tag should be:

```bash
$ docker build -t safespring/nextcloud-mariadb:10.5.6-90 .
```

## Docker Run

The recommended way to run a production MariaDB Galera container:

**[bootstrap]** - Only on the first node (e.g, db1)

```bash
$ docker run -d \
--name mariadb-bootstrap \
--net=host \
--restart=unless-stopped \
-e MYSQL_ROOT_PASSWORD='mypassw0rd' \
-e BOOTSTRAP=1 \
-e FORCE_BOOTSTRAP=0 \
-v $(pwd)/datadir:/var/lib/mysql \
-v $(pwd)/init:/docker-entrypoint-initdb.d \
-v $(pwd)/conf:/etc/mysql/mariadb.conf.d \
-v $(pwd)/backups:/backups \
safespring/nextcloud-mariadb:latest \
--wsrep_cluster_address=gcomm://192.168.0.101,192.168.0.102,192.168.0.103
```

**[start]** - The subsequent nodes (e.g, db2 and db3)

```bash
$ docker run -d \
--name mariadb2 \
--net=host \
--restart=unless-stopped \
-e MYSQL_ROOT_PASSWORD='mypassw0rd' \
-e BOOTSTRAP=0 \
-e FORCE_BOOTSTRAP=0 \
-v $(pwd)/datadir:/var/lib/mysql \
-v $(pwd)/init:/docker-entrypoint-initdb.d \
-v $(pwd)/conf:/etc/mysql/mariadb.conf.d \
-v $(pwd)/backups:/backups \
safespring/nextcloud-mariadb:latest \
--wsrep_cluster_address=gcomm://192.168.0.101,192.168.0.102,192.168.0.103
```

*The only difference between the above commands are the `--name` and the `-e BOOTSTRAP` values.*

The above commands requires a number of pre-configuration as below:

1) Prepare 3 hosts for a 3-node MariaDB Cluster. Specify all hosts in the `--wsrep_cluster_address` option, started with `gcomm://`, followed by the hostname/IP address/FQDN and separate them by a comma. No whitespaces allowed. Note that `--wsrep_cluster_address`(underscore) and `--wsrep-cluster-address`(dash) are treated as the same variable in MariaDB.

2) In the current directory, prepare 2 directories to be mapped into the container, one called `init` and another one called `conf`.

3) For `init` directory, create all SQL files prefixed with a numeric to determine the order of execution. See examples in the [init](https://github.com/safespring/nextcloud-db/tree/master/mariadb/compose/init) directory. All SQL files under this directory will be executed right after MariaDB is initalized after a fresh start.

4) For `conf` directory, create all MariaDB custom configuration files under this directory. See examples in the [conf](https://github.com/safespring/nextcloud-db/tree/master/mariadb/compose/conf) directory. In the examples, the sensitive information is separated inside `credentials.cnf`. The username and password for the user was created during MariaDB initialization stage as in the `init` directory.

After a cluster has been started successfully, where all nodes are in `Synced` state, stop the "bootstrap" container on the first node (db1), and use the same start command as others (with `BOOTSTRAP=0`):

```bash
$ docker stop mariadb-bootstrap
$ docker run -d \
--name mariadb1 \
--net=host \
--restart=unless-stopped \
-e MYSQL_ROOT_PASSWORD='mypassw0rd' \
-e BOOTSTRAP=0 \
-e FORCE_BOOTSTRAP=0 \
-v $(pwd)/datadir:/var/lib/mysql \
-v $(pwd)/init:/docker-entrypoint-initdb.d \
-v $(pwd)/conf:/etc/mysql/mariadb.conf.d \
-v $(pwd)/backups:/backups \
safespring/nextcloud-mariadb:latest \
--wsrep_cluster_address=gcomm://192.168.0.101,192.168.0.102,192.168.0.103
```

## Docker Compose

The [compose](https://github.com/safespring/nextcloud-db/tree/master/mariadb/compose) directory provides example compose files including instructions and documentation.


## Environment Variables

| Variables | Description  |
| --------- | ------------ |
| `MYSQL_ROOT_PASSWORD='{string}'` | This variable is mandatory and specifies the password that will be set for the MariaDB root superuser account. In the above example, it was set to `mypassw0rd`.
| `BOOTSTRAP={0\|1}` | If set to 1, the container will be started as a bootstrapped node with `--wsrep_cluster_address=gcomm://`, regardless of the `--wsrep_cluster_address` value defined when running this container. Default is 0, meaning the node will be started with the defined `--wsrep_cluster_address` value.
| `FORCE_BOOTSRAP={0\|1}` | If set to 1, the container will override `safe_to_bootstrap` option inside Galera state file, `grasate.dat`. This usually happens during ungraceful Galera shutdown. Default is 0. Otherwise, you will get this error: `It may not be safe to bootstrap the cluster from this node. It was not the last one to leave the cluster and may not contain all the updates. To force cluster bootstrap with this node, edit the grastate.dat file manually and set safe_to_bootstrap to 1 .`
| `MYSQL_DATABASE={string}` | This variable is optional and allows you to specify the name of a database to be created on image startup. If a user/password was supplied (see below) then that user will be granted superuser access (corresponding to `GRANT ALL`) to this database.
| `MYSQL_USER={string}` | These variables are optional, used in conjunction to create a new user. This user will be granted superuser permissions (see above) for the database specified by the `MYSQL_DATABASE` variable. Both variables are required for a user to be created.
| `MYSQL_PASSWORD={string}` | The password for `MYSQL_USER`.
| `MYSQL_ALLOW_EMPTY_PASSWORD={string}` | This is an optional variable. Set to a non-empty value, like `yes`, to allow the container to be started with a blank password for the root user. NOTE: Setting this variable to `yes` is not recommended unless you really know what you are doing, since this will leave your MariaDB instance completely unprotected, allowing anyone to gain complete superuser access.
| `MYSQL_RANDOM_ROOT_PASSWORD={string}` | This is an optional variable. Set to a non-empty value, like `yes`, to generate a random initial password for the root user (using `pwgen`). The generated root password will be printed to stdout (`GENERATED ROOT PASSWORD: .....`).
| `MYSQL_INITDB_SKIP_TZINFO={string}` | By default, the entrypoint script automatically loads the timezone data needed for the `CONVERT_TZ()` function. If it is not needed, any non-empty value disables timezone loading.
