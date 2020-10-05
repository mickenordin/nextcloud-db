#!/bin/bash
set -e

## ProxySQL entrypoint
## ===================
##
## Supported environment variable:
##
## INITIALIZE={1|0}
## - Initialize SQLite database during startup to respect /etc/proxysql.cnf over proxysql.db

# If command has arguments, prepend proxysql
if [ "${1:0:1}" == '-' ]; then
	CMDARG="$@"
fi

export MYSQL_PS1="\u@$(hostname) [ProxySQL Admin]> "

if [ ! -z $INITIALIZE ] && [ $INITIALIZE -eq 1 ]; then

	echo 'Env INITIALIZE=1, start ProxySQL with --initial parameter'
	# Start ProxySQL with PID 1
	exec proxysql --initial -f $CMDARG
else
	# Start ProxySQL with PID 1
	exec proxysql -f $CMDARG
fi
