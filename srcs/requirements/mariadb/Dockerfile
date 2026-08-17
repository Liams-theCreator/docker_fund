FROM debian:bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
        mariadb-server \
        mariadb-client \
        && rm -rf /var/lib/apt/lists/* \
        && find /var/lib/mysql -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +

COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 3306

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]