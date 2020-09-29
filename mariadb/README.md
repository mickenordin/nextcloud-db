# nextcloud-mariadb Docker Image

## Supported Tags

* 10.5.5-1,latest,beta (Dockerfile)

## Overview

MariaDB image to run on Docker, specifically built, tested and tuned for the following:

* Nextcloud workload
* MariaDB Cluster (Galera)
* ProxySQL read-write splitting
* Docker "host" networking
* Docker host is running on Ubuntu 20.04 (focal) amd64 architecture

## Image Description

Derived from the official MariaDB Docker repository, this image is maintained by Severalnines and will be updated regularly for every MariaDB release on the same major version. It follows the same build flow, environmet variables, code formatting and volume mapping as the official MariaDB image.

The image is based on Ubuntu 20.04 (Focal) and consists of:

* MariaDB packages for Ubuntu 20.04 (focal) - mariadb-server, mariadb-client, mariadb-backup
* Helper tools - sysstat, rsync, pigz, pv

Some customizations have been added to this image, to allow database initialization if `wsrep_on=ON` is set and also addition of two new environment variables:

* `BOOTSTRAP={1|0}` - If set to 1, the container will be started as a bootstrapped node with `--wsrep_cluster_address=gcomm://`.
* `FORCE_BOOTSTRAP{=1|0}` - If set to 1, the container will override `safe_to_bootstrap` option inside Galera state file, `grasate.dat`. This usually happens during ungraceful Galera shutdown.

For more details, check out the Environment Variables section.


## Build

To build the image:

```
$ git clone https://github.com/safespring/nextcloud-db
$ cd nextcloud-db/mariadb
$ docker build -t safespring/nextcloud-mariadb:latest .
```

## Run

To run a MariaDB Galera container with a custom MySQL configuration files located at `$(pwd)/conf`:

```
$ docker run -d \
--name mariadb1 \
--publish 3306:3306 \
--publish 4444:4444 \
--publish 4567:4567 \
--publish 4568:4568 \
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

## Environment Variables

| Variables | Description  |
| --------- | ------------ |
| `MYSQL_ROOT_PASSWORD='{string}'` | This variable is mandatory and specifies the password that will be set for the MariaDB root superuser account. In the above example, it was set to `mypassw0rd`.
| `BOOTSTRAP={0|1}` | If set to 1, the container will be started as a bootstrapped node with `--wsrep_cluster_address=gcomm://`. Default is 0.
| `FULL_BOOTSRAP={0|1}` | If set to 1, the container will override `safe_to_bootstrap` option inside Galera state file, `grasate.dat`. This usually happens during ungraceful Galera shutdown. Default is 0.


## Examples

### Deployment and Management

Check out the repository's wiki page.

### MySQL configurationn files


### Volume mapping

