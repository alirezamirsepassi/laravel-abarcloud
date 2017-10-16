FROM alpine:3.6

ENV TIMEZONE=Asia/Tehran
# You can find the php7 packages here: http://dl-cdn.alpinelinux.org/alpine/v3.6/community/x86_64/
ENV ADDITIONAL_PACKAGES="php7-bcmath php7-dom php7-tokenizer php7-pdo php7-pdo_mysql"
ENV PHP_MEMORY_LIMIT=128M
ENV PHP_UPLOAD_MAX_SILE_SIZE=50M
ENV PHP_POST_MAX_SIZE=50M

RUN apk update && \
    # Install required packages
    apk add tzdata curl bash ca-certificates supervisor nginx \
            php7 php7-fpm php7-common php7-openssl php7-json php7-phar php7-mbstring php7-iconv php7-zlib ${ADDITIONAL_PACKAGES} && \
    # Install composer
    curl -sS https://getcomposer.org/installer | php && \
    mv composer.phar /usr/bin/composer && \
    # Set the timezone
    cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime && \
    echo "${TIMEZONE}" > /etc/timezone && \
    # Set the nginx config
    sed -i "/user nginx;/c #user nginx;" /etc/nginx/nginx.conf && \
    # Set php.ini config
    sed -i "/date.timezone =/c date.timezone = ${TIMEZONE}"                              /etc/php7/php.ini && \
    sed -i "/memory_limit = /c memory_limit = ${PHP_MEMORY_LIMIT}"                       /etc/php7/php.ini && \
    sed -i "/upload_max_filesize = /c upload_max_filesize = ${PHP_UPLOAD_MAX_SILE_SIZE}" /etc/php7/php.ini && \
    sed -i "/post_max_size = /c post_max_size = ${PHP_POST_MAX_SIZE}"                    /etc/php7/php.ini && \
    # Set www conf
    sed -i "/listen.owner = /c listen.owner = root" /etc/php7/php-fpm.d/www.conf && \
    sed -i "/listen = /c listen = 127.0.0.1:9000"   /etc/php7/php-fpm.d/www.conf && \
    # Setup permissions
    mkdir -p /.composer /.config /run/nginx /var/lib/nginx/logs && \
    chmod -R g+rws,a+rx /.composer /.config /var/log /var/run /var/tmp /run/nginx /var/lib/nginx && \
    chown -R 1001:0     /.composer /.config /var/log /var/run /var/tmp /run/nginx /var/lib/nginx && \
    # Log aggregation
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log && \
    # Clean up packagess
    apk del tzdata && \
    rm -rf /var/cache/apk/*

EXPOSE 8080
CMD ["/usr/bin/supervisord", "-c", "/supervisord.conf"]
WORKDIR /var/www

COPY supervisord.conf /
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY composer.json composer.lock ./
RUN composer install --no-scripts --no-autoloader --prefer-dist --no-dev --working-dir=/var/www

# Copy the app files
COPY . /tmp/app
RUN chmod -R g+w /tmp/app && \
    chown -R 1001:0 /tmp/app && \
    cp -a /tmp/app/. /var/www && \
    rm -rf /tmp/app && \
    composer dump-autoload --optimize

USER 1001
