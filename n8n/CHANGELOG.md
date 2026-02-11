# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/).

## [1.0.4] - 2026-02-11

### Added

- **Ingress proxy (nginx)**: n8n's editor serves assets with absolute paths
  based on `N8N_PATH`. HA's ingress proxy strips the path prefix before
  forwarding. An nginx reverse proxy inside the container re-adds the prefix,
  allowing n8n assets, API calls, and WebSockets to work through HA ingress.
- `N8N_PATH` auto-detected from the Supervisor API (`ingress_entry`).
- nginx added to the multi-stage Docker build.
- Graceful multi-process shutdown (SIGTERM forwarded to both n8n and nginx).

### Changed

- n8n now listens on port 5679 (internal); nginx proxies port 5678 (ingress).
- HEALTHCHECK probes nginx on 5678 with fallback to n8n on 5679.

## [1.0.3] - 2026-02-11

### Fixed

- **Health check crash loop**: HEALTHCHECK used `wget` which does not exist in
  the hardened n8n image. Switched to `curl` (which we inject). This caused the
  Supervisor to never mark the add-on as "started", triggering watchdog restarts
  every 120 seconds.
- Increased HEALTHCHECK `start-period` from 60s to 90s for aarch64 cold starts.

## [1.0.2] - 2026-02-11

### Fixed

- **CHANGELOG 500 error**: Moved `CHANGELOG.md` into the add-on directory
  (`n8n/`) where HA Supervisor expects it (symlink kept at repo root).
- **Deprecated env var**: Removed `N8N_RUNNERS_ENABLED` — deprecated since
  n8n 2.7+, runners are enabled by default.

## [1.0.1] - 2026-02-11

### Fixed

- **Entrypoint chain**: Overwrite the n8n image's `/docker-entrypoint.sh` with
  our `run.sh` instead of relying on `ENTRYPOINT` override, which Docker was
  silently ignoring. This eliminates the `"Error: Command /run.sh not found"`
  loop caused by the original entrypoint passing CMD as arguments to the n8n
  CLI (`exec n8n "$@"`).
- Preserved the original n8n custom-certificate handling (`/opt/custom-certificates`)
  inside our entrypoint script.

### Added

- **Startup banner** logged on every boot — shows add-on version, n8n version,
  Node.js version, architecture, timestamp, bash version, and PID.
- 8 new test assertions (docker-entrypoint.sh ownership, startup banner content);
  test suite now has 53 assertions across 6 suites.

## [1.0.0] - 2026-02-11

### Added

- **config.yaml**: Full HA 2026 schema — ingress, `panel_icon`, `watchdog`,
  `homeassistant_api`, `hassio_api`, lifecycle settings (`init: false`,
  `startup: application`, `boot: auto`), `backup_exclude`, and
  `ports_description`.
- **build.yaml**: Multi-arch base images (`aarch64`, `amd64`) pointing to the
  official `docker.n8n.io/n8nio/n8n:latest`.
- **Dockerfile**: Multi-stage build — Stage 1 (Alpine 3.22) installs `bash`,
  `jq`, `curl`, and `bashio`; Stage 2 copies binaries + shared libraries into
  the hardened n8n image. Docker `HEALTHCHECK` included.
- **run.sh**: SSOT entrypoint — reads `/data/options.json` via `jq`, exports
  `N8N_*` environment variables, handles timezone priority
  (user option > HA `TZ` > UTC), `SUPERVISOR_TOKEN` awareness, user-defined
  `env_vars_list`, and optional `cmd_line_args`. Uses `exec n8n` for proper
  signal propagation.
- **repository.yaml**: Repository metadata for HA add-on store discovery.
- **README.md**: Quick-start installation guide with My Home Assistant badge.
- **DOCS.md**: Comprehensive add-on documentation (configuration, webhooks,
  external access, troubleshooting).
- **Test suite** (`n8n/tests/run_tests.sh`): Shell-based tests covering repo
  structure, config.yaml, Docker image filesystem, run.sh export logic, startup
  banner, and health checks.

### Fixed

- **Repository structure**: Moved add-on files into `n8n/` subdirectory as
  required by HA Supervisor for add-on discovery.
- **Hardened image compatibility**: Worked around the official n8n Docker
  Hardened Image stripping `apk`, by using a multi-stage build to inject
  required binaries.
- **Zero-config defaults**: Removed `timezone` and `cmd_line_args` from the
  `options` block so the add-on installs with no configuration required.
