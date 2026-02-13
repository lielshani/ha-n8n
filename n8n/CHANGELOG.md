# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/).

## [1.0.13] - 2026-02-13

### Security

- **cmd_line_args validation**: Added schema regex and runtime guard to reject
  shell metacharacters, preventing potential command injection.
- **Protected env vars denylist**: `PATH`, `LD_PRELOAD`, `LD_LIBRARY_PATH`,
  `NODE_OPTIONS`, `HOME`, `USER`, `SHELL`, and `SUPERVISOR_TOKEN` can no
  longer be overridden via `env_vars_list`.
- **nginx runs as non-root**: Dedicated `nginx` user created in the Docker
  image; nginx drops privileges from root to this user.
- **Rate limiting**: nginx ingress proxy now enforces 30 req/s per IP with
  burst of 50 and a 50 MB request body size limit.
- **Access logging**: nginx access log enabled (stdout) for audit trail.
- **Security headers**: `X-Content-Type-Options`, `X-Frame-Options`, and
  `Referrer-Policy` headers added to all nginx responses.
- **Safe template substitution**: Replaced `sed` with `envsubst` for nginx
  config generation, avoiding potential delimiter injection.
- **Pinned base image**: n8n base image pinned to `2.6.4` instead of `latest`.
- **Pinned CI actions**: GitHub Actions pinned by commit SHA.
- **Secure cookie docs**: Added security notes section to DOCS.md documenting
  `N8N_SECURE_COOKIE` default and how to enable TLS cookies.

## [1.0.12] - 2026-02-12

### Fixed

- **Blank page after sign-in via ingress**: After logging in, n8n's SPA router
  navigates to `/home/workflows`, changing the browser URL. Lazy-loaded JS/CSS
  chunks were using relative paths (e.g. `./assets/foo.js`) which the browser
  resolved against the current page URL — producing wrong paths like
  `.../TOKEN/home/assets/foo.js` instead of `.../TOKEN/assets/foo.js`. n8n
  returned `index.html` for these unknown paths, causing MIME type errors.
  Fixed by rewriting asset paths to absolute ingress-prefixed paths
  (`/api/hassio_ingress/TOKEN/assets/...`) instead of relative paths. Absolute
  paths resolve correctly regardless of the current page sub-path.

## [1.0.8] - 2026-02-11

### Added

- **Direct LAN access**: n8n is now accessible from any device on the local
  network at `http://<ha-ip>:5678/`. Container port 5680 is mapped to host
  port 5678 by default. No HA Ingress or authentication proxy needed —
  n8n uses its own built-in auth.

### Changed

- `N8N_LISTEN_ADDRESS` changed from `127.0.0.1` to `0.0.0.0` so n8n accepts
  connections from outside the container.
- Watchdog and HEALTHCHECK now probe n8n directly on port 5680 (always
  available, even if nginx isn't running).
- Updated DOCS.md with direct access and webhook instructions.

## [1.0.7] - 2026-02-11

### Fixed

- **MIME type errors on ingress**: Setting `N8N_PATH` broke n8n's internal
  static file serving — it returned `index.html` instead of JS assets, causing
  `"Strict MIME type checking"` errors. Replaced `N8N_PATH` + nginx rewrite
  with nginx `sub_filter`:
  - n8n serves at `/` as normal (no subpath).
  - nginx rewrites `window.BASE_PATH` in responses to the ingress entry.
  - Absolute asset paths (`/assets/...`) converted to relative (`assets/...`)
    so the browser resolves them through the ingress proxy.
  - Upstream compression disabled so `sub_filter` can process response bodies.

## [1.0.6] - 2026-02-11

### Fixed

- **Port conflict**: n8n's internal Task Broker defaults to port 5679. Moving
  n8n's main server to 5679 caused a conflict. Switched n8n's main server to
  port 5680, freeing 5679 for the Task Broker.

## [1.0.5] - 2026-02-11

### Fixed

- **nginx missing user directive**: Added `user root;` to nginx config as the
  hardened image does not contain an `nginx` user.
- **nginx log directories**: Created `/var/lib/nginx/logs` directory in the
  builder stage to prevent nginx startup errors.

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
