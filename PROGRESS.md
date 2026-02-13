# Project Progress

## Completed

- **Config & schema** — `config.yaml` validated against HA 2026 standards (ingress, watchdog, APIs, lifecycle)
- **Multi-stage Dockerfile** — works around hardened n8n image (no `apk`); injects bash, jq, curl, bashio
- **SSOT entrypoint** — `run.sh` reads options.json, exports N8N env vars, handles timezone + SUPERVISOR_TOKEN
- **Entrypoint fix** — overwrites `/docker-entrypoint.sh` in the n8n image to avoid CMD-as-argument trap
- **Health checks** — Docker HEALTHCHECK + HA watchdog configured
- **Repo structure** — add-on in `n8n/` subdirectory, `repository.yaml` at root (HA Supervisor requirement)
- **Documentation** — README (GitHub), DOCS.md (HA UI), CHANGELOG
- **Test suite** — 53 assertions across 6 suites (structure, config, image, env logic, banner, health)
- **Zero-config install** — works out of the box; timezone auto-detected from HA
- **Automated CI** — GitHub Actions for build/test on push

## In Progress

- **Ingress verification** — n8n starts and listens; verifying HA ingress proxy access

## Not Started

- **Ingress path rewriting** — n8n may need `N8N_EDITOR_BASE_URL` for HA ingress proxy
- **Webhook support** — document/configure external webhook URL passthrough
- **Add-on logo/icon** — `n8n/icon.png` and `n8n/logo.png` for the HA store
