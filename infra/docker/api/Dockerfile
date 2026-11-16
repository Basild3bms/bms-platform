FROM php:8.3-cli-alpine
RUN apk add --no-cache git unzip libpq-dev oniguruma-dev $PHPIZE_DEPS \
    && docker-php-ext-install pdo_pgsql \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apk del $PHPIZE_DEPS
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
WORKDIR /srv/api
