#
# Build Container
#

FROM nginx:${NGINX_BRANCH:-alpine} as builder

RUN apk add \
      gcc \
      libc-dev \
      make \
      openssl-dev \
      pcre-dev \
      zlib-dev \
      linux-headers \
      libxslt-dev \
      gd-dev \
      geoip-dev \
      perl-dev \
      libedit-dev \
      curl \
      gnupg \
      ruby \
      ruby-rake \
      bison \
      flex \
      git

ARG MRUBY_VERSION
ARG NGX_MRUBY_VERSION
ENV MRUBY_VERSION=${MRUBY_VERSION:-2.1.2}
ENV NGX_MRUBY_VERSION=${NGX_MRUBY_VERSION:-v2.2.3}

RUN git clone https://github.com/mruby/mruby.git /src/mruby -b ${MRUBY_VERSION} --depth 1
RUN git clone https://github.com/nginx/nginx.git /src/nginx -b release-${NGINX_VERSION} --depth 1
RUN git clone https://github.com/matsumotory/ngx_mruby.git /src/ngx_mruby -b ${NGX_MRUBY_VERSION} --depth 1

WORKDIR /src/mruby
ENV MRUBY_ROOT /src/mruby
ENV MRUBY_CONFIG /etc/build_config.rb
ENV MRUBY_BUILD_DIR /build/mruby
ENV INSTALL_DIR /build/mruby/bin
COPY build_config.rb $MRUBY_CONFIG
RUN ln -s /src/ngx_mruby/mrbgems/ngx_mruby_mrblib /src/mruby/mrbgems/ngx_mruby && \
    sed -i -E '$ i conf.gem :core => "ngx_mruby"' /src/mruby/mrbgems/default.gembox && \
    sed -i -E '$ i conf.gem :core => "ngx_mruby"' /src/mruby/mrbgems/full-core.gembox && \
    rake -j $(nproc) 2>&1 | tee /var/log/mruby.log

WORKDIR /src/ngx_mruby
RUN NGINX_CONFIG_OPT="$(nginx -V 2>&1 | sed -n -E 's/^.*arguments: //p')" && \
    ./configure \
    --enable-dynamic-module \
    --with-build-dir=/build/ngx_mruby \
    --with-mruby-root=/src/mruby \
    --with-ngx-src-root=/src/nginx \
    --with-ngx-config-opt="$CONFARGS" && \
    { \
      echo 'include /build/mruby/host/lib/libmruby.flags.mak'; \
      echo '.PHONY: all'; \
      echo 'all: mrbgems_config_dynamic'; \
      echo 'mrbgems_config_dynamic:'; \
      echo '	@echo ngx_module_libs="\"$(MRUBY_LDFLAGS) $(MRUBY_LIBS) $(MRUBY_LDFLAGS_BEFORE_LIBS)\"" > mrbgems_config_dynamic'; \
      echo '	@echo CORE_LIBS="\"\$$CORE_LIBS $(MRUBY_LDFLAGS) $(MRUBY_LIBS) $(MRUBY_LDFLAGS_BEFORE_LIBS)\"" >> mrbgems_config_dynamic'; \
    } > Makefile.mrbgems_config_dynamic && make -f Makefile.mrbgems_config_dynamic

WORKDIR /src/nginx
RUN ARGS="$(nginx -V 2>&1 | sed -n -E 's/^.*arguments: //p' | sed -E 's/ --with-cc-opt='\''.*'\''//; s/ --with-ld-opt=[^ ]+//;')" && \
    CC_OPTS="$(nginx -V 2>&1 | sed -n -E 's/^.*arguments: //p' | sed -E 's/.*--with-cc-opt='\''(.*)'\''.*/\1/')" && \
    LD_OPTS="$(nginx -V 2>&1 | sed -n -E 's/^.*arguments: //p' | sed -E 's/.*--with-ld-opt=([^ ]+).*/\1/')" && \
    ./auto/configure \
    $ARGS \
    --with-cc-opt="$CC_OPTS" \
    --with-ld-opt="$LD_OPTS" \
    --add-dynamic-module=/src/ngx_mruby/dependence/ngx_devel_kit \
    --add-dynamic-module=/src/ngx_mruby 2>&1 | tee /var/log/nginx-configure.log && \
    make -j $(nproc) install 2>&1 | tee /var/log/nginx-make-install.log

#
# Service Container
#

FROM nginx:${NGINX_BRANCH:-alpine} as service

COPY --from=builder /usr/lib/nginx/modules/ndk_http_module.so /usr/lib/nginx/modules/ndk_http_module.so
COPY --from=builder /usr/lib/nginx/modules/ngx_http_mruby_module.so /usr/lib/nginx/modules/ngx_http_mruby_module.so
RUN sed -i -E '1i load_module /usr/lib/nginx/modules/ndk_http_module.so;' /etc/nginx/nginx.conf && \
    sed -i -E '2i load_module /usr/lib/nginx/modules/ngx_http_mruby_module.so;' /etc/nginx/nginx.conf
