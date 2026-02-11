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

RUN apk add --no-cache bash jq curl \
    && curl -sL -o /tmp/bashio.tar.gz \
        "https://github.com/hassio-addons/bashio/archive/refs/tags/v0.16.2.tar.gz" \
    && mkdir -p /tmp/bashio \
    && tar xzf /tmp/bashio.tar.gz --strip-components=1 -C /tmp/bashio \
    # --- collect binaries + shared libs into /export ---
    && mkdir -p /export/usr/bin /export/usr/lib /export/lib \
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

ARG BUILD_VERSION=1.0.0
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
COPY run.sh /
RUN chmod a+x /run.sh

# Health check — polls n8n's HTTP endpoint every 30s
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD wget --quiet --spider http://localhost:5678/ || exit 1

# Override the n8n image's ENTRYPOINT (tini -- /docker-entrypoint.sh)
# so our run.sh controls the full startup. We keep tini as PID 1 for
# proper signal forwarding.
ENTRYPOINT [ "tini", "--" ]
CMD [ "/usr/bin/bash", "/run.sh" ]
