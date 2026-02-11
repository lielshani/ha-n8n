#!/usr/bin/env bash
# ===========================================================================
# ha-n8n — Test Suite
#
# Validates repo structure, config, Docker image, and run.sh logic.
# Usage:  ./n8n/tests/run_tests.sh   (from repo root)
#     or: ./tests/run_tests.sh       (from n8n/ directory)
# Requires: docker, grep, jq
# ===========================================================================

set -euo pipefail

# Resolve the add-on directory (n8n/) regardless of where the script is invoked
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADDON_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_DIR="$(cd "${ADDON_DIR}/.." && pwd)"

cd "${ADDON_DIR}"

IMAGE="ha-n8n-test:local"
PASS=0
FAIL=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
green()  { printf "\033[32m%s\033[0m\n" "$*"; }
red()    { printf "\033[31m%s\033[0m\n" "$*"; }
bold()   { printf "\033[1m%s\033[0m\n" "$*"; }

assert() {
    local description="$1"
    shift
    if "$@" > /dev/null 2>&1; then
        green "  PASS: ${description}"
        PASS=$(( PASS + 1 ))
    else
        red "  FAIL: ${description}"
        FAIL=$(( FAIL + 1 ))
    fi
}

assert_output() {
    local description="$1"
    local expected="$2"
    shift 2
    local actual
    actual="$("$@" 2>/dev/null)" || true
    if [[ "${actual}" == *"${expected}"* ]]; then
        green "  PASS: ${description}"
        PASS=$(( PASS + 1 ))
    else
        red "  FAIL: ${description} (expected '${expected}', got '${actual}')"
        FAIL=$(( FAIL + 1 ))
    fi
}

# Config grep helper — checks that a YAML key has a specific value
config_has() {
    local key="$1"
    local value="$2"
    grep -qE "^${key}:\s*${value}" config.yaml
}

config_exists() {
    local key="$1"
    grep -qE "^${key}:" config.yaml
}

# ---------------------------------------------------------------------------
# Test 0: Repository structure (required by HA Supervisor)
# ---------------------------------------------------------------------------
bold "=== Test Suite 0: Repository Structure ==="

assert "repository.yaml at repo root"      test -f "${REPO_DIR}/repository.yaml"
assert "add-on in subdirectory (n8n/)"      test -d "${REPO_DIR}/n8n"
assert "config.yaml inside add-on dir"      test -f "${REPO_DIR}/n8n/config.yaml"
assert "Dockerfile inside add-on dir"       test -f "${REPO_DIR}/n8n/Dockerfile"
assert "run.sh inside add-on dir"           test -f "${REPO_DIR}/n8n/run.sh"
assert "config.yaml NOT at repo root"       test ! -f "${REPO_DIR}/config.yaml"

echo ""

# ---------------------------------------------------------------------------
# Test 1: config.yaml validation
# ---------------------------------------------------------------------------
bold "=== Test Suite 1: config.yaml ==="

assert "config.yaml exists"       test -f config.yaml
assert "build.yaml exists"        test -f build.yaml

# Required keys
assert "has name"                  config_exists "name"
assert "has version"               config_exists "version"
assert "has slug"                  config_exists "slug"
assert "has description"           config_exists "description"
assert "has arch"                  config_exists "arch"

# Critical settings
assert "init is false"             config_has "init" "false"
assert "ingress is true"           config_has "ingress" "true"
assert "ingress_port is 5678"      config_has "ingress_port" "5678"
assert "ingress_stream is true"    config_has "ingress_stream" "true"
assert "homeassistant_api true"    config_has "homeassistant_api" "true"
assert "hassio_api true"           config_has "hassio_api" "true"
assert "watchdog present"          config_exists "watchdog"
assert "startup is application"    config_has "startup" "application"
assert "boot is auto"              config_has "boot" "auto"
assert "panel_icon set"            config_exists "panel_icon"

# Schema
assert "schema has timezone"       grep -q 'timezone:.*str' config.yaml
assert "schema has env_vars_list"  grep -q "env_vars_list" config.yaml
assert "schema has cmd_line_args"  grep -q "cmd_line_args" config.yaml

echo ""

# ---------------------------------------------------------------------------
# Test 2: Docker image filesystem
# ---------------------------------------------------------------------------
bold "=== Test Suite 2: Docker Image Filesystem ==="

assert "Image exists" docker image inspect "${IMAGE}"

assert_output "bash is available" "GNU bash" \
    docker run --rm --entrypoint /usr/bin/bash "${IMAGE}" --version

assert_output "jq is available" "jq-" \
    docker run --rm --entrypoint /bin/sh "${IMAGE}" -c "/usr/bin/jq --version"

assert_output "curl is available" "curl" \
    docker run --rm --entrypoint /bin/sh "${IMAGE}" -c "/usr/bin/curl --version"

assert "bashio symlink exists" \
    docker run --rm --entrypoint /bin/sh "${IMAGE}" -c "test -L /usr/bin/bashio"

assert "bashio library dir exists" \
    docker run --rm --entrypoint /bin/sh "${IMAGE}" -c "test -d /usr/lib/bashio"

assert "/data directory exists" \
    docker run --rm --entrypoint /bin/sh "${IMAGE}" -c "test -d /data"

assert "run.sh is executable" \
    docker run --rm --entrypoint /bin/sh "${IMAGE}" -c "test -x /run.sh"

assert_output "n8n binary works" "2." \
    docker run --rm --entrypoint /bin/sh "${IMAGE}" -c "n8n --version"

echo ""

# ---------------------------------------------------------------------------
# Test 3: run.sh export logic (mocked options.json)
# ---------------------------------------------------------------------------
bold "=== Test Suite 3: run.sh Export Logic ==="

EXPORT_OUTPUT="$(docker run --rm --entrypoint /usr/bin/bash \
    -e TZ="Asia/Tokyo" \
    "${IMAGE}" -c '
cat > /data/options.json <<OPTS
{
  "env_vars_list": [
    "WEBHOOK_URL: https://test.example.com",
    "N8N_ENCRYPTION_KEY: super-secret"
  ]
}
OPTS

export SUPERVISOR_TOKEN="test-token"
OPTIONS_FILE="/data/options.json"

USER_TZ="$(jq -r ".timezone // empty" "${OPTIONS_FILE}")"
if [[ -n "${USER_TZ}" ]]; then
    TIMEZONE="${USER_TZ}"
else
    TIMEZONE="${TZ:-UTC}"
fi
export GENERIC_TIMEZONE="${TIMEZONE}"
export TZ="${TIMEZONE}"

export N8N_USER_FOLDER="/data"
export N8N_PORT="5678"
export N8N_LISTEN_ADDRESS="0.0.0.0"

ENV_COUNT="$(jq -r ".env_vars_list | length" "${OPTIONS_FILE}")"
for i in $(seq 0 $(( ENV_COUNT - 1 ))); do
    entry="$(jq -r ".env_vars_list[${i}]" "${OPTIONS_FILE}")"
    key="${entry%%: *}"
    value="${entry#*: }"
    export "${key}=${value}"
done

echo "GENERIC_TIMEZONE=${GENERIC_TIMEZONE}"
echo "TZ=${TZ}"
echo "N8N_USER_FOLDER=${N8N_USER_FOLDER}"
echo "N8N_PORT=${N8N_PORT}"
echo "WEBHOOK_URL=${WEBHOOK_URL}"
echo "N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}"
echo "SUPERVISOR_TOKEN=${SUPERVISOR_TOKEN}"
' 2>/dev/null)"

check_env() {
    local key="$1"
    local expected="$2"
    if echo "${EXPORT_OUTPUT}" | grep -q "^${key}=${expected}$"; then
        green "  PASS: ${key}=${expected}"
        PASS=$(( PASS + 1 ))
    else
        red "  FAIL: ${key} expected '${expected}'"
        FAIL=$(( FAIL + 1 ))
    fi
}

check_env "GENERIC_TIMEZONE"   "Asia/Tokyo"
check_env "TZ"                 "Asia/Tokyo"
check_env "N8N_USER_FOLDER"    "/data"
check_env "N8N_PORT"           "5678"
check_env "WEBHOOK_URL"        "https://test.example.com"
check_env "N8N_ENCRYPTION_KEY" "super-secret"
check_env "SUPERVISOR_TOKEN"   "test-token"

echo ""

# ---------------------------------------------------------------------------
# Test 4: Health check configuration
# ---------------------------------------------------------------------------
bold "=== Test Suite 4: Health Check ==="

assert "Dockerfile HEALTHCHECK present"    grep -q "HEALTHCHECK" Dockerfile
assert "HEALTHCHECK uses wget"             grep -q "wget.*spider.*localhost:5678" Dockerfile
assert "config.yaml watchdog present"      grep -q "watchdog:" config.yaml

echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
bold "==========================================="
TOTAL=$(( PASS + FAIL ))
bold "  Results: ${PASS}/${TOTAL} passed"
if [[ "${FAIL}" -gt 0 ]]; then
    red "  ${FAIL} test(s) FAILED"
    exit 1
else
    green "  All tests PASSED"
    exit 0
fi
