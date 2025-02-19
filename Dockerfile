FROM alpine:3.14
LABEL maintainer="wangkun_king@live.com"

ENV TENGINE_VERSION 2.3.3
ENV CONFIG "\
        --user=nginx \
        --group=nginx \
        --prefix=/etc/nginx \
        --sbin-path=/usr/sbin/nginx \
        --modules-path=/usr/lib/nginx/modules \
        --conf-path=/etc/nginx/nginx.conf \
        --lock-path=/var/lock/nginx.lock \
        --pid-path=/var/run/nginx.pid \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/nginx/access.log \
        --http-client-body-temp-path=/var/cache/nginx/client_temp \
        --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
        --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
        --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
        --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
        --with-http_ssl_module \
        --with-http_gzip_static_module \
        --with-http_gunzip_module \
        --with-http_addition_module \
        --with-http_dav_module \
        --with-http_realip_module \
        --with-http_v2_module \
        --with-http_stub_status_module \
        --with-http_sub_module \
        --with-http_xslt_module=dynamic \
        --with-http_flv_module \
        --with-http_mp4_module \
        --with-http_degradation_module \
        --with-http_random_index_module \
        --with-http_secure_link_module \
        --with-http_auth_request_module \
        --with-file-aio \
        --with-mail \
        --with-mail_ssl_module \
        --with-compat \
        --with-pcre \
        --with-pcre-jit \
        --with-threads \
        --with-stream \
        --with-stream_ssl_module \
        --with-stream_ssl_preread_module \
        --with-stream_geoip_module=dynamic \
        --with-http_slice_module \
        --with-http_image_filter_module=dynamic \
        --with-http_geoip_module=dynamic \
        --add-module=modules/ngx_http_upstream_check_module \
        --add-module=modules/ngx_http_upstream_session_sticky_module \
        --add-module=modules/ngx_http_upstream_consistent_hash_module \
        --add-module=modules/headers-more-nginx-module-0.33 \
        "
ENV TZ=Asia/Shanghai

RUN \
    addgroup -S nginx \
    && adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx \
    && adduser -u 82 -D -S -G www-data www-data \
    && apk add --no-cache --virtual .build-deps \
        gcc \
        geoip \
        geoip-dev \
        libxslt-dev \
        libxml2-dev \
        gd-dev \
        libc-dev \
        make \
        openssl-dev \
        pcre-dev \
        zlib-dev \
        linux-headers \
        curl \
    && curl "http://tengine.taobao.org/download/tengine-$TENGINE_VERSION.tar.gz" -o tengine.tar.gz \
    && mkdir -p /usr/src \
    && tar -zxC /usr/src -f tengine.tar.gz \
    && rm tengine.tar.gz \
    && cd ../../../ \
    && cd /usr/src/tengine-$TENGINE_VERSION \
    && curl -L "https://github.com/openresty/headers-more-nginx-module/archive/v0.33.tar.gz" -o more.tar.gz \
    && tar -zxC /usr/src/tengine-$TENGINE_VERSION/modules -f more.tar.gz \
	&& rm  more.tar.gz \
	&& ls -l /usr/src/tengine-$TENGINE_VERSION/modules \
    && ./configure $CONFIG --with-debug \
    && make -j$(getconf _NPROCESSORS_ONLN) \
    && mv objs/nginx objs/nginx-debug \
    && mv objs/ngx_http_xslt_filter_module.so objs/ngx_http_xslt_filter_module-debug.so \
    && mv objs/ngx_http_image_filter_module.so objs/ngx_http_image_filter_module-debug.so \
    && mv objs/ngx_http_geoip_module.so objs/ngx_http_geoip_module-debug.so \
    && mv objs/ngx_stream_geoip_module.so objs/ngx_stream_geoip_module-debug.so \
    && ./configure $CONFIG \
    && make -j$(getconf _NPROCESSORS_ONLN) \
    && make install \
    && rm -rf /etc/nginx/html/ \
    && mkdir /etc/nginx/conf.d/ \
    && mkdir -p /usr/share/nginx/html/ \
    && install -m644 html/index.html /usr/share/nginx/html/ \
    && install -m644 html/50x.html /usr/share/nginx/html/ \
    && install -m755 objs/nginx-debug /usr/sbin/nginx-debug \
    && install -m755 objs/ngx_http_xslt_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_xslt_filter_module-debug.so \
    && install -m755 objs/ngx_http_image_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_image_filter_module-debug.so \
    && install -m755 objs/ngx_http_geoip_module-debug.so /usr/lib/nginx/modules/ngx_http_geoip_module-debug.so \
    && install -m755 objs/ngx_stream_geoip_module-debug.so /usr/lib/nginx/modules/ngx_stream_geoip_module-debug.so \
    && ln -s ../../usr/lib/nginx/modules /etc/nginx/modules \
    && strip /usr/sbin/nginx* \
    && strip /usr/lib/nginx/modules/*.so \
    && rm -rf /usr/src/tengine-$NGINX_VERSION \
    && apk add --no-cache --virtual .gettext gettext \
    && mv /usr/bin/envsubst /tmp/ \
    && runDeps="$( \
                scanelf --needed --nobanner --format '%n#p' /usr/sbin/nginx /usr/lib/nginx/modules/*.so /tmp/envsubst \
                        | tr ',' '\n' \
                        | sort -u \
                        | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
    )" \
    && apk add --no-cache --virtual .nginx-rundeps $runDeps \
    && apk del .build-deps \
    && apk del .gettext \
    && mv /tmp/envsubst /usr/local/bin/ \
    && rm -rf /usr/src/nginx-$NGINX_VERSION \
    && apk add --no-cache tzdata \
    && echo "${TZ}" > /etc/timezone \
    && ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime \
    # forward request and error logs to docker log collector
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log


CMD ["nginx", "-g", "daemon off;"]