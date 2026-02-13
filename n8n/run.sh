#!/usr/bin/bash
# ===========================================================================
# Home Assistant Add-on: n8n — Entrypoint
#
# Single Responsibility: Read HA options, export as N8N env vars, exec n8n.
# SSOT flow:  /data/options.json  ->  env vars  ->  n8n
# ===========================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# 0. Startup banner — versions & diagnostics (logged before anything else)
# ---------------------------------------------------------------------------
ADDON_VERSION="1.0.14"

echo "==========================================================="
echo " Home Assistant Add-on: n8n"
echo "==========================================================="
echo " Add-on version : ${ADDON_VERSION}"
echo " n8n version    : $(n8n --version 2>/dev/null || echo 'unknown')"
echo " Node.js version: $(node --version 2>/dev/null || echo 'unknown')"
echo " Architecture   : $(uname -m 2>/dev/null || echo 'unknown')"
echo " Startup time   : $(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date)"
echo " Bash           : ${BASH_VERSION:-unknown}"
echo " PID            : $$"
echo "==========================================================="

# ---------------------------------------------------------------------------
# 1. Source bashio (used for logging only; config read via jq for testability)
# ---------------------------------------------------------------------------
# shellcheck source=/dev/null
if [[ -f /usr/lib/bashio/bashio.sh ]]; then
    source /usr/lib/bashio/bashio.sh 2>/dev/null || true
fi

# Logging helper — uses bashio if available, falls back to echo
log_info()    { bashio::log.info    "$@" 2>/dev/null || echo "[INFO]  $*"; }
log_warning() { bashio::log.warning "$@" 2>/dev/null || echo "[WARN]  $*"; }
log_error()   { bashio::log.error   "$@" 2>/dev/null || echo "[ERROR] $*"; }

# ---------------------------------------------------------------------------
# 1b. Custom certificates (preserved from original n8n entrypoint)
# ---------------------------------------------------------------------------
if [[ -d /opt/custom-certificates ]]; then
    log_info "Trusting custom certificates from /opt/custom-certificates"
    export NODE_OPTIONS="--use-openssl-ca ${NODE_OPTIONS:-}"
    export SSL_CERT_DIR=/opt/custom-certificates
    c_rehash /opt/custom-certificates 2>/dev/null || true
fi

OPTIONS_FILE="/data/options.json"

if [[ ! -f "${OPTIONS_FILE}" ]]; then
    log_error "Options file not found: ${OPTIONS_FILE}"
    exit 1
fi

log_info "Starting n8n add-on..."

# ---------------------------------------------------------------------------
# 2. Timezone
#    Priority: user option > HA Supervisor TZ env var > UTC
#    The Supervisor injects TZ based on HA's configured timezone, so most
#    users never need to set this manually.
# ---------------------------------------------------------------------------
USER_TZ="$(jq -r '.timezone // empty' "${OPTIONS_FILE}")"
if [[ -n "${USER_TZ}" ]]; then
    TIMEZONE="${USER_TZ}"
    log_info "Timezone from add-on config: ${TIMEZONE}"
else
    TIMEZONE="${TZ:-UTC}"
    log_info "Timezone auto-detected from HA: ${TIMEZONE}"
fi
export GENERIC_TIMEZONE="${TIMEZONE}"
export TZ="${TIMEZONE}"

# ---------------------------------------------------------------------------
# 3. n8n defaults for HA environment
# ---------------------------------------------------------------------------
# Persist data inside HA's /data volume (survives add-on rebuilds)
export N8N_USER_FOLDER="/data"

# n8n listens on 5680 on all interfaces:
#   - Direct LAN access: host:5678 -> container:5680 (no proxy)
#   - HA Ingress:        ingress -> container:5678 (nginx) -> 5680
# Port 5679 is reserved for n8n's internal Task Broker.
export N8N_PORT="5680"
export N8N_LISTEN_ADDRESS="0.0.0.0"

# Recommended n8n settings for self-hosted
export N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS="true"

# Disable diagnostics/telemetry in HA context
export N8N_DIAGNOSTICS_ENABLED="false"

# Disable version notifications (HA manages updates)
export N8N_VERSION_NOTIFICATIONS_ENABLED="false"

# Allow cookies over plain HTTP (required for LAN access without TLS).
# Ingress is already secured by HA auth; direct LAN access uses n8n's
# own login. Users who add TLS can override via env_vars_list.
export N8N_SECURE_COOKIE="false"

# ---------------------------------------------------------------------------
# 4. SUPERVISOR_TOKEN & Ingress
#    Query the Supervisor API for the ingress entry path so we can tell n8n
#    its real base path and configure nginx to re-add the prefix that the
#    ingress proxy strips before forwarding to us.
# ---------------------------------------------------------------------------
INGRESS_ENTRY=""
if [[ -n "${SUPERVISOR_TOKEN:-}" ]]; then
    log_info "SUPERVISOR_TOKEN is available for HA API access"

    INGRESS_ENTRY="$(curl -sS \
        -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
        http://supervisor/addons/self/info 2>/dev/null \
        | jq -r '.data.ingress_entry // empty')" || true

    if [[ -n "${INGRESS_ENTRY}" ]]; then
        log_info "Ingress entry: ${INGRESS_ENTRY}"
        # Ensure it ends with /
        [[ "${INGRESS_ENTRY}" == */ ]] || INGRESS_ENTRY="${INGRESS_ENTRY}/"
        # N8N_PATH is NOT set — n8n serves at / as normal.
        # nginx sub_filter rewrites response bodies so the browser
        # resolves paths through the ingress proxy.
        log_info "Ingress path: ${INGRESS_ENTRY}"
    else
        log_warning "Could not detect ingress entry — assets may 404 via ingress"
    fi
else
    log_warning "SUPERVISOR_TOKEN not found — running without ingress proxy"
fi

# ---------------------------------------------------------------------------
# 5. nginx ingress proxy
#    Generate nginx config from template, replacing ${INGRESS_ENTRY}.
#    nginx on port 5678 re-adds the ingress prefix that HA strips, then
#    proxies to n8n on 5679.
# ---------------------------------------------------------------------------
NGINX_CONF="/etc/nginx/nginx.conf"
NGINX_TEMPLATE="/etc/nginx/nginx.conf.template"

if [[ -n "${INGRESS_ENTRY}" && -f "${NGINX_TEMPLATE}" ]]; then
    export INGRESS_ENTRY
    envsubst '${INGRESS_ENTRY}' < "${NGINX_TEMPLATE}" > "${NGINX_CONF}"
    log_info "nginx config generated for ingress proxy"
    USE_NGINX=true
else
    USE_NGINX=false
    log_info "No ingress proxy — n8n accessible on port 5680 directly"
fi

# ---------------------------------------------------------------------------
# 6. User-defined environment variables (env_vars_list from options.json)
#    Format per entry: "KEY: value"
# ---------------------------------------------------------------------------
ENV_COUNT="$(jq -r '.env_vars_list | length' "${OPTIONS_FILE}")"

# Vars that must not be overridden by user config (security-sensitive)
PROTECTED_VARS="PATH LD_PRELOAD LD_LIBRARY_PATH NODE_OPTIONS HOME USER SHELL SUPERVISOR_TOKEN"

if [[ "${ENV_COUNT}" -gt 0 ]]; then
    log_info "Processing ${ENV_COUNT} user-defined environment variable(s)..."

    for i in $(seq 0 $(( ENV_COUNT - 1 ))); do
        entry="$(jq -r ".env_vars_list[${i}]" "${OPTIONS_FILE}")"

        # Split on first ": " — key is everything before, value after
        key="${entry%%: *}"
        value="${entry#*: }"

        if [[ -z "${key}" ]]; then
            log_warning "Skipping malformed env_vars_list entry: ${entry}"
            continue
        fi

        # Block protected system/runtime variables
        for pvar in ${PROTECTED_VARS}; do
            if [[ "${key}" == "${pvar}" ]]; then
                log_warning "Skipping protected env var: ${key}"
                continue 2
            fi
        done

        export "${key}=${value}"
        log_info "Exported env var: ${key}"
    done
fi

# ---------------------------------------------------------------------------
# 7. Optional command-line arguments
# ---------------------------------------------------------------------------
CMD_ARGS="$(jq -r '.cmd_line_args // empty' "${OPTIONS_FILE}")"

if [[ -n "${CMD_ARGS}" ]]; then
    # Runtime guard: reject shell metacharacters in cmd_line_args
    if [[ "${CMD_ARGS}" =~ [^a-zA-Z0-9\ :._/-] ]]; then
        log_error "cmd_line_args contains invalid characters — aborting"
        exit 1
    fi
    log_info "Command-line args: ${CMD_ARGS}"
fi

# ---------------------------------------------------------------------------
# 8. Launch n8n (+ nginx when ingress is active)
# ---------------------------------------------------------------------------
log_info "Environment ready. Launching n8n..."

# Graceful shutdown — forward SIGTERM to both processes
cleanup() {
    log_info "Received shutdown signal..."
    [[ -n "${N8N_PID:-}" ]]   && kill "${N8N_PID}" 2>/dev/null
    [[ -n "${NGINX_PID:-}" ]] && kill "${NGINX_PID}" 2>/dev/null
    wait
    log_info "Shutdown complete."
}
trap cleanup SIGTERM SIGINT

if [[ -n "${CMD_ARGS}" ]]; then
    # shellcheck disable=SC2086
    n8n ${CMD_ARGS} &
else
    n8n &
fi
N8N_PID=$!

if [[ "${USE_NGINX}" == "true" ]]; then
    log_info "Starting nginx ingress proxy on port 5678..."
    /usr/sbin/nginx -c "${NGINX_CONF}" -g "daemon off;" &
    NGINX_PID=$!
    log_info "nginx PID: ${NGINX_PID}, n8n PID: ${N8N_PID}"
fi

# Wait for either process to exit
wait -n "${N8N_PID}" ${NGINX_PID:+"${NGINX_PID}"} 2>/dev/null || true
EXIT_CODE=$?

log_info "Process exited with code ${EXIT_CODE}, shutting down..."
cleanup
exit "${EXIT_CODE}"
