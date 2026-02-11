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
ADDON_VERSION="1.0.3"

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

# Listen on the ingress port defined in config.yaml
export N8N_PORT="5678"
export N8N_LISTEN_ADDRESS="0.0.0.0"

# Recommended n8n settings for self-hosted
export N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS="true"

# N8N_RUNNERS_ENABLED removed — deprecated since n8n 2.7+, runners are
# enabled by default and the env var is no longer needed.

# Disable diagnostics/telemetry in HA context
export N8N_DIAGNOSTICS_ENABLED="false"

# Disable version notifications (HA manages updates)
export N8N_VERSION_NOTIFICATIONS_ENABLED="false"

# ---------------------------------------------------------------------------
# 4. SUPERVISOR_TOKEN (injected by HA Supervisor automatically)
# ---------------------------------------------------------------------------
if [[ -n "${SUPERVISOR_TOKEN:-}" ]]; then
    log_info "SUPERVISOR_TOKEN is available for HA API access"
else
    log_warning "SUPERVISOR_TOKEN not found — HA API calls will fail"
fi

# ---------------------------------------------------------------------------
# 5. User-defined environment variables (env_vars_list from options.json)
#    Format per entry: "KEY: value"
# ---------------------------------------------------------------------------
ENV_COUNT="$(jq -r '.env_vars_list | length' "${OPTIONS_FILE}")"

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

        export "${key}=${value}"
        log_info "Exported env var: ${key}"
    done
fi

# ---------------------------------------------------------------------------
# 6. Optional command-line arguments
# ---------------------------------------------------------------------------
CMD_ARGS="$(jq -r '.cmd_line_args // empty' "${OPTIONS_FILE}")"

if [[ -n "${CMD_ARGS}" ]]; then
    log_info "Command-line args: ${CMD_ARGS}"
fi

# ---------------------------------------------------------------------------
# 7. Launch n8n (exec replaces shell — signals propagate to n8n directly)
# ---------------------------------------------------------------------------
log_info "Environment ready. Launching n8n..."

if [[ -n "${CMD_ARGS}" ]]; then
    # shellcheck disable=SC2086
    exec n8n ${CMD_ARGS}
else
    exec n8n
fi
