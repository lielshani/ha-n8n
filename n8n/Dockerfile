# ===========================================================================
# Home Assistant Add-on: n8n
#
# The official n8n image is a Docker Hardened Image (Alpine-based, apk
# stripped).  We use a multi-stage build to pull in bash, jq, and bashio
# from a regular Alpine image, then copy the binaries + libraries into
# the final n8n image.
# ===========================================================================

# Global ARG -- must precede all FROM directives for multi-stage builds
ARG BUILD_FROM

# ---------- Stage 1: HA integration dependencies --------------------------
FROM alpine:3.22 AS ha-deps

RUN apk add --no-cache bash jq curl nginx \
    && curl -sL -o /tmp/bashio.tar.gz \
        "https://github.com/hassio-addons/bashio/archive/refs/tags/v0.16.2.tar.gz" \
    && mkdir -p /tmp/bashio \
    && tar xzf /tmp/bashio.tar.gz --strip-components=1 -C /tmp/bashio \
    # --- collect binaries + shared libs into /export ---
    && mkdir -p /export/usr/bin /export/usr/lib /export/lib \
        /export/usr/sbin /export/var/log/nginx /export/var/lib/nginx/tmp \
        /export/etc/nginx \
    # bash
    && BASH_BIN="$(which bash)" \
    && cp "$BASH_BIN" /export/usr/bin/bash \
    && ldd "$BASH_BIN" | awk '/=>/{print $3}' | while read -r lib; do \
           [ -f "$lib" ] && cp "$lib" /export/lib/; \
       done \
    # jq
    && JQ_BIN="$(which jq)" \
    && cp "$JQ_BIN" /export/usr/bin/jq \
    && ldd "$JQ_BIN" | awk '/=>/{print $3}' | while read -r lib; do \
           [ -f "$lib" ] && cp "$lib" /export/lib/; \
       done \
    # curl (required by bashio for Supervisor API calls)
    && CURL_BIN="$(which curl)" \
    && cp "$CURL_BIN" /export/usr/bin/curl \
    && ldd "$CURL_BIN" | awk '/=>/{print $3}' | while read -r lib; do \
           [ -f "$lib" ] && cp -n "$lib" /export/lib/ 2>/dev/null; \
           [ -f "$lib" ] && cp -n "$lib" /export/usr/lib/ 2>/dev/null; \
           true; \
       done \
    # nginx (reverse proxy for HA ingress path rewriting)
    && NGINX_BIN="$(which nginx)" \
    && cp "$NGINX_BIN" /export/usr/sbin/nginx \
    && ldd "$NGINX_BIN" | awk '/=>/{print $3}' | while read -r lib; do \
           [ -f "$lib" ] && cp -n "$lib" /export/lib/ 2>/dev/null; \
           [ -f "$lib" ] && cp -n "$lib" /export/usr/lib/ 2>/dev/null; \
           true; \
       done \
    && cp /etc/nginx/mime.types /export/etc/nginx/ 2>/dev/null || true \
    # also grab ca-certificates for HTTPS
    && mkdir -p /export/etc/ssl \
    && cp -r /etc/ssl/certs /export/etc/ssl/ \
    # bashio library
    && mkdir -p /export/usr/lib/bashio \
    && cp -r /tmp/bashio/lib/* /export/usr/lib/bashio/ \
    && ln -s /usr/lib/bashio/bashio /export/usr/bin/bashio \
    # cleanup
    && rm -rf /tmp/bashio.tar.gz /tmp/bashio

# ---------- Stage 2: Final image ------------------------------------------
FROM $BUILD_FROM

ARG BUILD_VERSION=1.0.4
ARG BUILD_ARCH
LABEL \
    io.hass.version="${BUILD_VERSION}" \
    io.hass.type="addon" \
    io.hass.arch="${BUILD_ARCH}"

USER root

# Copy bash + jq + bashio from builder
COPY --from=ha-deps /export/ /

# Persistent storage for HA
RUN mkdir -p /data

# Entrypoint
# Strategy: overwrite the n8n image's /docker-entrypoint.sh with our run.sh.
# The n8n base image ENTRYPOINT is ["tini", "--", "/docker-entrypoint.sh"],
# which passes CMD as arguments to that script. By replacing the script
# itself we guarantee our code runs regardless of ENTRYPOINT caching.
# We also keep run.sh at / as an alias.
COPY run.sh /docker-entrypoint.sh
COPY run.sh /run.sh
COPY nginx.conf.template /etc/nginx/nginx.conf.template
RUN chmod a+x /docker-entrypoint.sh /run.sh

# Health check — probes nginx on 5678, validating the full proxy chain.
# Falls back to n8n directly on 5679 if nginx isn't running.
HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
    CMD curl -sf -o /dev/null http://localhost:5678/ || \
        curl -sf -o /dev/null http://127.0.0.1:5679/ || exit 1

# Clear CMD so that docker-entrypoint.sh receives no arguments.
# The original script does `exec n8n "$@"` — with an empty CMD, $@ is empty
# and our run.sh (now at /docker-entrypoint.sh) controls everything.
CMD []
