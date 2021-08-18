FROM php:7.4.20-fpm-alpine3.13

# Docker Build Arguments
ARG RESTY_VERSION="1.19.3.2"
ARG RESTY_OPENSSL_VERSION="1.1.1k"
ARG RESTY_PCRE_VERSION="8.45"
ARG REDIS_VERSION="5.1.1"
ARG MEMCACHED_VERSION="3.1.5"
ARG XDEBUG_VERSION="2.8.1"
ARG RESTY_J="1"
ARG RESTY_CONFIG_OPTIONS="\
    --user=www-data \
    --group=www-data \
    --with-file-aio \
    --with-http_addition_module \
    --with-http_auth_request_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_geoip_module=dynamic \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_image_filter_module=dynamic \
    --with-http_mp4_module \
    --with-http_random_index_module \
    --with-http_realip_module \
    --with-http_secure_link_module \
    --with-http_slice_module \
    --with-http_ssl_module \
    --with-http_stub_status_module \
    --with-http_sub_module \
    --with-http_v2_module \
    --with-http_xslt_module=dynamic \
    --with-ipv6 \
    --with-mail \
    --with-mail_ssl_module \
    --with-md5-asm \
    --with-pcre-jit \
    --with-sha1-asm \
    --with-stream \
    --with-stream_ssl_module \
    --with-threads \
    "
ARG RESTY_CONFIG_OPTIONS_MORE=""

LABEL resty_version="${RESTY_VERSION}"
LABEL resty_openssl_version="${RESTY_OPENSSL_VERSION}"
LABEL resty_pcre_version="${RESTY_PCRE_VERSION}"
LABEL resty_config_options="${RESTY_CONFIG_OPTIONS}"
LABEL resty_config_options_more="${RESTY_CONFIG_OPTIONS_MORE}"

# These are not intended to be user-specified
ARG _RESTY_CONFIG_DEPS="--with-openssl=/tmp/openssl-${RESTY_OPENSSL_VERSION} --with-pcre=/tmp/pcre-${RESTY_PCRE_VERSION}"

# Add additional binaries into PATH for convenience
ENV PATH=$PATH:/usr/local/openresty/luajit/bin:/usr/local/openresty/nginx/sbin:/usr/local/openresty/bin

# Add persistent dependencies
RUN set -ex \
    && apk update \
    && apk add --virtual .persistent-deps \
          bash \
          bzip2 \
          curl \
          gd \
          geoip \
          libbz2 \
          libcurl \
          libgcc \
          libmemcached-dev \
          libressl \
          libxslt \
          nginx \
          mysql-client \
          ruby \
          tar \
          xz \
          xz-libs \
          zlib

#Build openresty
RUN apk add --no-cache --virtual .or-build-deps \
        build-base \
        gd-dev \
        geoip-dev \
        libxslt-dev \
        linux-headers \
        make \
        perl-dev \
        readline-dev \
        zlib-dev \
        gnupg \
    && cd /tmp \
    && curl -fSL https://www.openssl.org/source/openssl-${RESTY_OPENSSL_VERSION}.tar.gz -o openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
    && curl -fSL https://www.openssl.org/source/openssl-${RESTY_OPENSSL_VERSION}.tar.gz.sha256 -o openssl-${RESTY_OPENSSL_VERSION}.tar.gz.sha256 \
    && sha256sum openssl-${RESTY_OPENSSL_VERSION}.tar.gz | cut -f1 -d" " | grep - -qf openssl-${RESTY_OPENSSL_VERSION}.tar.gz.sha256 \
    && tar xzf openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
    && curl -fSL https://ftp.pcre.org/pub/pcre/pcre-${RESTY_PCRE_VERSION}.tar.gz -o pcre-${RESTY_PCRE_VERSION}.tar.gz \
    && curl -fSL https://ftp.pcre.org/pub/pcre/pcre-${RESTY_PCRE_VERSION}.tar.gz.sig -o pcre-${RESTY_PCRE_VERSION}.tar.gz.sig \ 
    && for key in \
      B550E09EA0E98066 \
      9766E084FB0F43D8 \
    ; do \
      gpg --batch --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || \
      gpg --batch --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
      gpg --batch --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys "$key" || \
      gpg --batch --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" ; \
    done \
    && gpg --verify pcre-${RESTY_PCRE_VERSION}.tar.gz.sig pcre-${RESTY_PCRE_VERSION}.tar.gz \
    && tar xzf pcre-${RESTY_PCRE_VERSION}.tar.gz \
    && curl -fSL https://openresty.org/download/openresty-${RESTY_VERSION}.tar.gz -o openresty-${RESTY_VERSION}.tar.gz \
    && curl -fSL https://openresty.org/download/openresty-${RESTY_VERSION}.tar.gz.asc -o openresty-${RESTY_VERSION}.tar.gz.asc \
    && gpg --verify openresty-${RESTY_VERSION}.tar.gz.asc \
    && tar xzf openresty-${RESTY_VERSION}.tar.gz \
    && cd /tmp/openresty-${RESTY_VERSION} \
    && ./configure -j${RESTY_J} ${_RESTY_CONFIG_DEPS} ${RESTY_CONFIG_OPTIONS} ${RESTY_CONFIG_OPTIONS_MORE} \
    && make -j${RESTY_J} \
    && make -j${RESTY_J} install \
    && cd /tmp \
    && rm -rf \
        openssl-${RESTY_OPENSSL_VERSION} \
        openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
        openresty-${RESTY_VERSION}.tar.gz openresty-${RESTY_VERSION} \
        pcre-${RESTY_PCRE_VERSION}.tar.gz pcre-${RESTY_PCRE_VERSION} \
    && apk del .or-build-deps \
    && ln -sf /dev/stdout /usr/local/openresty/nginx/logs/access.log \
    && ln -sf /dev/stderr /usr/local/openresty/nginx/logs/error.log


# Add build-deps and then remove them at the end.
RUN set -ex \
    && apk add --no-cache --virtual .php-build-deps \
          $PHPIZE_DEPS \
          autoconf \
          bzip2-dev \
          c-client \
          coreutils \
          curl-dev \
          fcgi-dev \
          freetype-dev \
          git \
          grep \
          krb5-dev \
          libc-dev \
          libjpeg-turbo-dev \
          libmcrypt-dev \
          libpng-dev \
          libxml2-dev \
          libxslt-dev \
          libzip-dev \
          postgresql-dev \
          oniguruma-dev \
    && docker-php-ext-configure gd \
                --with-freetype \
                --with-jpeg \
    && docker-php-ext-install -j "$(nproc)" \
          bcmath \
          bz2 \
          curl \
          gd \
          mbstring \
          opcache \
          pdo \
          fileinfo \          
          exif \
          mongodb \
          pdo_mysql \
          pdo_pgsql \
          xml \
          zip \
    && runDeps="$( \
                scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
                        | tr ',' '\n' \
                        | sort -u \
                        | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
    )" \
    && pecl install redis-${REDIS_VERSION} \
    && pecl install memcached-${MEMCACHED_VERSION} \
    && pecl install xdebug-${XDEBUG_VERSION} \
    && apk add --virtual .drupal-phpexts-rundeps $runDeps \
    && apk del .php-build-deps

RUN rm -rf /var/cache/apk/*

RUN mkdir -p /var/tmp/templates /var/tmp/nginx
ADD templates/* /var/tmp/templates/
ADD contrib/start.sh /var/tmp/start.sh
RUN chmod 755 /var/tmp/start.sh 

# process default templates.
RUN set -ex \
    && gem install --no-document erubis

CMD [ "/var/tmp/start.sh" ]
