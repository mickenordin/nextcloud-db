# Compose file


# Commands

## Bootstrapping a server

1) Set environment variables accordingly. For the first node that you want to bootstrap, set the compose file as the following:

```yaml
   environment:
     MYSQL_ROOT_PASSWORD: "{mandatory}"
     BOOTSTRAP: 1
     FORCE_BOOTSTRAP: 0
```

While for the joiner nodes (remaining nodes):

```yaml
   environment:
     MYSQL_ROOT_PASSWORD: "{mandatory}"
     BOOTSTRAP: 0
     FORCE_BOOTSTRAP: 0
```

2) Set the `--wsrep_cluster_address` in the `command` sesction to all nodes in the cluster. For example, if the 3 Galera nodes are 192.168.0.241, 192.168.0.242 and 192.168.0.243, the `--wsrep_cluster_address` value should be:

```yaml
   command:
     - --wsrep_cluster_address=gcomm://192.168.0.241,192.168.0.242,192.68.0.243
```


3) On the first database node, run:

```bash
cd compose
docker-compose up -d
```

*This will load the default docker-compose.yaml in the current directory*

Attention!! Only bootstrap one node in a Galera cluster. The rest of the nodes, BOOTSTRAP should be set to 0 or skip defining it. Don't proceed to start the other node until the first node is bootstrapped.

4) Proceed to start the rest of the nodes, one node at a time:

```bash
cd compose
docker-compose up -d
```



## Backup

By default, the image will create a backup directory under `/backups/`. This should be mapped in the volume when starting the MariaDB container, for example:

```yaml
    volumes:
      - ${PWD}/datadir:/var/lib/mysql
      - ${PWD}/init:/docker-entrypoint-initdb.d
      - ${PWD}/conf:/etc/mysql/mariadb.conf.d
      - ${PWD}/backups:/backups
```

All backup credentails are stored in a specific files, `/etc/mysql/mariadb.conf.d/credentials.cnf`. The backup user is created automatically by `init/02-sst_user.sql` during container initialization stage.

### Mariabackup

To create a physical backup using mariabackup, attach to the service with the following command:

```bash
docker-compose exec nextcloud-mariadb /usr/bin/mariabackup --defaults-file=/etc/mysql/mariadb.conf.d/credentials.cnf --backup --target-dir=/backups/mariabackup
```

** You will see some output. Make sure you see `Completed OK` in the last line. That's the indicator the backup is completed successfully.


### mysqldump

```bash
docker-compose exec nextcloud-mariadb /bin/mysqldump --defaults-file=/etc/mysql/mariadb.conf.d/credentials.cnf --single-transaction --all-databases | gzip > /backups/mysqldump_$(date '+%Y-%m-%d_%H:%M:%S').sql.gz
```

The example mysqldump output: `mysqldump_2020-09-28_09:23:59.sql.gz`
