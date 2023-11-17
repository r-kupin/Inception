FROM alpine:3.18.4

ARG PHP_VERSION=82 \
    DB_NAME \
    DB_USER \
    DB_PASS

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
    wget \
    unzip;

COPY requirements/tools/confedit.sh .

RUN sh confedit.sh "listen =" 9000  /etc/php82/php-fpm.d/www.conf " "

WORKDIR /var/www

RUN wget https://wordpress.org/latest.zip && \
    unzip latest.zip && \
    cp -rf wordpress/* . && \
    rm -rf wordpress latest.zip

RUN apk del wget && \
	apk del unzip && \
	apk upgrade && \
	apk cache clean

COPY ./requirements/wordpress/conf/wp-config-create.sh .

RUN sh wp-config-create.sh && rm wp-config-create.sh && chmod -R 0777 wp-content/

WORKDIR /

CMD ["/usr/sbin/php-fpm82", "-F"]
