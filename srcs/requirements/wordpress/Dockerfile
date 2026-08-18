FROM debian:bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
        php-fpm \
        php-cli \
        php-mysql \
        php-curl \
        php-gd \
        php-intl \
        php-mbstring \
        php-xml \
        php-zip \
        mariadb-client \
        curl \
        ca-certificates \
        unzip \
    && curl -fsSL -o /usr/local/bin/wp \
        https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x /usr/local/bin/wp \
    && wp --info \
    && mkdir -p /var/www/html \
    && chown -R www-data:www-data /var/www/html \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /var/www/html

COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
