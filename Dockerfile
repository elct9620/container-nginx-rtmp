FROM ubuntu:xenial

ENV DEBIAN_FRONTEND noninteractive
ENV PATH $PATH:/usr/local/nginx/sbin

EXPOSE 1935
EXPOSE 80 443

# Version
ENV NGINX_VERSION 1.10.1
ENV RTMP_MODULE_VERSION 1.1.9
ENV OPENSSL_VERSION 1.0.2h

# Setup Environment
ENV MODULE_DIR /usr/src/nginx-module
ENV DATA_DIR /data

# Prepare
RUN echo "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d
RUN apt-get update && \
    apt-get install -y build-essential software-properties-common && \
    apt-get install software-properties-common wget ffmpeg  -y

RUN mkdir ${MODULE_DIR} && \
    mkdir ${DATA_DIR}

# Nginx Dependencies
RUN apt-get install -y libpcre3-dev zlib1g-dev

# Prepare Source
RUN cd /usr/src && \
    wget -q http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && \
    tar xzf nginx-${NGINX_VERSION}.tar.gz && \
    rm -rf nginx-${NGINX_VERSION}.tar.gz


RUN cd /usr/src && \
    wget -q http://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz && \
    tar xzf openssl-${OPENSSL_VERSION}.tar.gz && \
    rm -rf openssl-${OPENSSL_VERSION}.tar.gz

RUN cd ${MODULE_DIR} && \
    wget -q https://github.com/arut/nginx-rtmp-module/archive/v${RTMP_MODULE_VERSION}.tar.gz && \
    tar zxf v${RTMP_MODULE_VERSION}.tar.gz && \
    rm v${RTMP_MODULE_VERSION}.tar.gz && \
    ls -al ${MODULE_DIR}

# Compile Nginx
RUN cd /usr/src/nginx-${NGINX_VERSION} && \
    ./configure \
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib/nginx/modules \
    --conf-path=/etc/nginx/nginx.conf \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --with-http_ssl_module \
    --with-http_realip_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_secure_link_module \
    --with-http_v2_module \
    --with-threads \
    --with-file-aio \
    --with-ipv6 \
    --with-openssl="../openssl-${OPENSSL_VERSION}" \
    --add-module=${MODULE_DIR}/nginx-rtmp-module-${RTMP_MODULE_VERSION} \

    # Install Nginx
    && cd /usr/src/nginx-${NGINX_VERSION} \
    && make && make install  \
    && mkdir -p /var/www/html  \
    && mkdir -p /etc/nginx/conf.d  \
    && mkdir -p /usr/share/nginx/html \
    && mkdir -p /var/cache/nginx \
    && mkdir -p /var/cache/ngx_pagespeed \
    && install -m644 html/index.html /var/www/html  \
    && install -m644 html/50x.html /usr/share/nginx/html \

    # Clean up
    && rm -rf /usr/src/*

# Forward requests and errors to docker logs
RUN ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

VOLUME ["/var/cache/nginx", "/var/cache/ngx_pagespeed", "/var/www/html", "/usr/certs"]

COPY nginx.conf /etc/nginx/nginx.conf

CMD ["nginx", "-g", "daemon off;"]
