#!/bin/bash
set -euo pipefail

DATADIR="/var/lib/mysql"
SOCKET="/run/mysqld/mysqld.sock"

read_secret() {
    local variable_name="$1"
    local file_variable="${variable_name}_FILE"
    local file_path="${!file_variable:-}"

    if [ -z "$file_path" ] || [ ! -r "$file_path" ]; then
        echo "Missing readable secret file for ${variable_name}" >&2
        exit 1
    fi

    printf -v "$variable_name" '%s' "$(cat "$file_path")"

    if [ -z "${!variable_name}" ]; then
        echo "Empty secret for ${variable_name}" >&2
        exit 1
    fi
}

: "${DB_NAME:?DB_NAME is required}"
: "${DB_USER:?DB_USER is required}"

if [[ ! "$DB_NAME" =~ ^[A-Za-z0-9_]+$ ]] || [[ ! "$DB_USER" =~ ^[A-Za-z0-9_]+$ ]]; then
    echo "DB_NAME and DB_USER may contain only letters, numbers, and underscores" >&2
    exit 1
fi

read_secret DB_ROOT_PASSWORD
read_secret DB_PASSWORD

if [[ "$DB_ROOT_PASSWORD" == *"'"* ]] || [[ "$DB_PASSWORD" == *"'"* ]]; then
    echo "Database passwords must not contain a single quote" >&2
    exit 1
fi

mkdir -p /run/mysqld "$DATADIR"
chown -R mysql:mysql /run/mysqld "$DATADIR"

if [ ! -d "$DATADIR/mysql" ]; then
    echo "Initializing MariaDB data directory"

    mariadb-install-db \
        --user=mysql \
        --datadir="$DATADIR" \
        --auth-root-authentication-method=normal

    mariadbd \
        --user=mysql \
        --datadir="$DATADIR" \
        --socket="$SOCKET" \
        --skip-networking &

    temporary_pid="$!"

    for _ in $(seq 1 30); do
        if mariadb-admin --protocol=socket --socket="$SOCKET" --user=root ping --silent; then
            break
        fi
        sleep 1
    done

    if ! mariadb-admin --protocol=socket --socket="$SOCKET" --user=root ping --silent; then
        echo "Temporary MariaDB server did not become ready" >&2
        exit 1
    fi

    mariadb --protocol=socket --socket="$SOCKET" --user=root <<EOSQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
ALTER USER '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;
EOSQL

    MYSQL_PWD="$DB_ROOT_PASSWORD" mariadb-admin \
        --protocol=socket \
        --socket="$SOCKET" \
        --user=root \
        shutdown

    wait "$temporary_pid"
fi

exec mariadbd --user=mysql --datadir="$DATADIR" --socket="$SOCKET"
