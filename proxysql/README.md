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

For a list of available Docker image version, please refer to Supported Tags section.

## Examples

### Deployment and Management

Check out the repository's wiki page.

### proxysql.cnf


### docker-compose.yaml

