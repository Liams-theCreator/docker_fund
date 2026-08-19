#!/bin/bash
set -euo pipefail

WP_PATH="/var/www/html"
DB_HOST="${DB_HOST:-mariadb}"

read_secret( ) {
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

: "${DOMAIN_NAME:?DOMAIN_NAME is required}"
: "${DB_NAME:?DB_NAME is required}"
: "${DB_USER:?DB_USER is required}"
: "${WP_TITLE:?WP_TITLE is required}"
: "${WP_ADMIN_USER:?WP_ADMIN_USER is required}"
: "${WP_STANDARD_USER:?WP_STANDARD_USER is required}"

if [[ "${WP_ADMIN_USER,,}" == *admin* ]]; then
    echo "WP_ADMIN_USER must not contain admin" >&2
    exit 1
fi

read_secret DB_PASSWORD
read_secret WP_ADMIN_PASSWORD
read_secret WP_STANDARD_PASSWORD

WP_ADMIN_EMAIL="${WP_ADMIN_EMAIL:-${WP_ADMIN_USER}@${DOMAIN_NAME}}"
WP_STANDARD_EMAIL="${WP_STANDARD_EMAIL:-${WP_STANDARD_USER}@${DOMAIN_NAME}}"

mkdir -p "$WP_PATH"
chown -R www-data:www-data "$WP_PATH"
cd "$WP_PATH"

echo "Waiting for MariaDB"
for _ in $(seq 1 30); do
    if MYSQL_PWD="$DB_PASSWORD" mariadb \
        --protocol=TCP \
        --host="$DB_HOST" \
        --user="$DB_USER" \
        "$DB_NAME" \
        --execute="SELECT 1" >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

if ! MYSQL_PWD="$DB_PASSWORD" mariadb \
    --protocol=TCP \
    --host="$DB_HOST" \
    --user="$DB_USER" \
    "$DB_NAME" \
    --execute="SELECT 1" >/dev/null 2>&1; then
    echo "MariaDB did not become ready for the WordPress account" >&2
    exit 1
fi

if [ ! -f "wp-load.php" ]; then
    echo "Downloading WordPress core"
    wp core download --allow-root
fi

if [ ! -f "wp-config.php" ]; then
    echo "Creating wp-config.php"
    wp config create \
        --dbname="$DB_NAME" \
        --dbuser="$DB_USER" \
        --dbpass="$DB_PASSWORD" \
        --dbhost="$DB_HOST" \
        --allow-root
fi

if ! wp core is-installed --allow-root >/dev/null 2>&1; then
    echo "Installing WordPress"
    wp core install \
        --url="https://${DOMAIN_NAME}" \
        --title="$WP_TITLE" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_password="$WP_ADMIN_PASSWORD" \
        --admin_email="$WP_ADMIN_EMAIL" \
        --skip-email \
        --allow-root
fi

if ! wp user get "$WP_STANDARD_USER" --field=ID --allow-root >/dev/null 2>&1; then
    echo "Creating the standard WordPress user"
    wp user create "$WP_STANDARD_USER" "$WP_STANDARD_EMAIL" \
        --user_pass="$WP_STANDARD_PASSWORD" \
        --role=subscriber \
        --allow-root
fi

chown -R www-data:www-data "$WP_PATH"

exec php-fpm8.2 -F
