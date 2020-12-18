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

RUN git clone https://github.com/nginx/nginx.git /src/nginx -b release-${NGINX_VERSION} --depth 1
RUN git clone https://github.com/mruby/mruby.git /src/mruby -b ${MRUBY_VERSION} --depth 1
RUN git clone https://github.com/matsumotory/ngx_mruby.git /src/ngx_mruby -b ${NGX_MRUBY_VERSION} --depth 1

COPY build_config.rb /etc/build_config.rb
RUN ln -s /src/ngx_mruby/mrbgems/ngx_mruby_mrblib /src/mruby/mrbgems/ngx_mruby && \
    sed -i -E '$ i conf.gem :core => "ngx_mruby"' /src/mruby/mrbgems/default.gembox && \
    sed -i -E '$ i conf.gem :core => "ngx_mruby"' /src/mruby/mrbgems/full-core.gembox && \
    cp /src/ngx_mruby/config.in /src/ngx_mruby/config && \
    sed -i -E 's#@MRUBY_ROOT@#/src/mruby#' /src/ngx_mruby/config && \
    sed -i -E 's#@MRUBY_INCDIR@#/src/mruby/src /src/mruby/include#' /src/ngx_mruby/config && \
    sed -i -E 's#@MRUBY_LIBDIR@#/build/mruby/host/lib#' /src/ngx_mruby/config

WORKDIR /src/mruby
ENV MRUBY_ROOT /src/mruby
ENV MRUBY_CONFIG /etc/build_config.rb
ENV MRUBY_BUILD_DIR /build/mruby
ENV INSTALL_DIR /build/mruby/bin
RUN rake -j $(nproc)

WORKDIR /src/nginx
ENV STREAM YES
ENV ngx_module_link DYNAMIC
RUN CONFARGS=$(nginx -V 2>&1 | sed -n -e 's/^.*arguments: //p') \
             ./auto/configure --with-compat $CONFARGS \
             --add-dynamic-module=/src/ngx_mruby \
             --add-dynamic-module=/src/ngx_mruby/dependence/ngx_devel_kit && \
             make -j $(nproc) && make install

#
# Service Container
#

FROM nginx:${NGINX_BRANCH:-alpine} as service

COPY --from=builder /usr/local/nginx/modules/ndk_http_module.so /usr/local/nginx/modules/ndk_http_module.so
COPY --from=builder /usr/local/nginx/modules/ngx_http_mruby_module.so /usr/local/nginx/modules/ngx_http_mruby_module.so
RUN sed -i -E '1i load_module /usr/local/nginx/modules/ndk_http_module.so;' /etc/nginx/nginx.conf && \
    sed -i -E '2i load_module /usr/local/nginx/modules/ngx_http_mruby_module.so;' /etc/nginx/nginx.conf
