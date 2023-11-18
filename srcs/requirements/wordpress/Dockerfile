FROM alpine:3.18.4

ARG PHP_VERSION=82 DB_NAME \
    DB_ROOT \
    DB_USER \
    DB_PASS \
    WP_ADMIN \
    WP_ADMIN_PASS \
    WP_ADMIN_MAIL \
    WP_USER \
    WP_USER_PASS \
    WP_USER_MAIL

RUN apk update && apk upgrade && apk add --no-cache \
    php${PHP_VERSION} \
    php${PHP_VERSION}-fpm \
    php${PHP_VERSION}-mysqli \
    php${PHP_VERSION}-json \
    php${PHP_VERSION}-curl \
    php${PHP_VERSION}-dom \
    php${PHP_VERSION}-exif \
    php${PHP_VERSION}-fileinfo \
    php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-openssl \
    php${PHP_VERSION}-xml \
    php${PHP_VERSION}-zip \
    php${PHP_VERSION}-redis \
    php${PHP_VERSION}-phar \
    wget \
    unzip;

COPY requirements/tools/confedit.sh .

RUN sh confedit.sh "listen =" 9000  /etc/php82/php-fpm.d/www.conf " " && \
	ln -s /usr/bin/php${PHP_VERSION} /usr/bin/php && \
	ln -s /etc/php${PHP_VERSION}/php.ini /etc/php.ini

WORKDIR /var/www

RUN wget https://wordpress.org/latest.zip && \
    unzip latest.zip && \
    cp -rf wordpress/* . && \
    rm -rf wordpress latest.zip

RUN wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp

RUN apk del wget && \
	apk del unzip && \
	apk upgrade && \
	apk cache clean

COPY ./requirements/wordpress/conf/wp-config-create.sh .

RUN sh wp-config-create.sh && rm wp-config-create.sh && chmod -R 0777 wp-content/

CMD ["/usr/sbin/php-fpm82", "-F"]
