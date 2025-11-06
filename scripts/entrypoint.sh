#!/bin/bash
set -e

# Ensure runtime directories exist
mkdir -p /run/php /run/mysqld /var/run/sshd
chown -R mysql:mysql /run/mysqld

# Initialize MariaDB data directory if empty
if [ ! -d "/var/lib/mysql/mysql" ]; then
  echo "[entrypoint] initializing MariaDB data directory"
  mariadb-install-db --user=mysql --ldata=/var/lib/mysql >/dev/null
fi

# Run migrations/seed scripts on first launch
if [ -d "/docker-entrypoint-initdb.d" ]; then
  echo "[entrypoint] applying database bootstrap scripts"
  mysqld --skip-networking --socket=/run/mysqld/mysqld.sock &
  pid="$!"
  for i in {30..0}; do
    if mysqladmin --socket=/run/mysqld/mysqld.sock ping >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
  if ! mysqladmin --socket=/run/mysqld/mysqld.sock ping >/dev/null 2>&1; then
    echo "[entrypoint] cannot connect to MariaDB" >&2
    exit 1
  fi
  for f in /docker-entrypoint-initdb.d/*.sql; do
    [ -f "$f" ] && mysql --socket=/run/mysqld/mysqld.sock < "$f"
  done
  mysqladmin --socket=/run/mysqld/mysqld.sock shutdown
fi

exec "$@"
