FROM alpine:3.18.4

ARG DB_NAME \
    DB_USER \
    DB_PASS \
    DB_ROOT

RUN apk update && apk add --no-cache mariadb mariadb-client

COPY requirements/tools/confedit.sh .
COPY requirements/mariadb/conf/docker.cnf /etc/my.cnf.d/

RUN mkdir /var/run/mysqld; chmod 777 /var/run/mysqld
RUN sh confedit.sh skip-networking 0 /etc/my.cnf.d/mariadb-server.cnf "="

RUN mysql_install_db --user=mysql --datadir=/var/lib/mysql
COPY requirements/mariadb/tools/create_db.sh .
RUN sh create_db.sh && rm -f /*.sh

EXPOSE 3306

USER mysql
CMD ["/usr/bin/mysqld"]
