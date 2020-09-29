CREATE USER 'exporter'@'127.0.0.1' IDENTIFIED BY 'BjF4242g5bYRswX490Mw';
GRANT PROCESS, REPLICATION CLIENT ON *.* TO 'exporter'@'127.0.0.1';
GRANT SELECT ON performance_schema.* TO 'exporter'@'127.0.0.1';
