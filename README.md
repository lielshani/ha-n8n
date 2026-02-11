# Home Assistant Add-on: n8n

[![Add repository to my Home Assistant instance.][repo-badge]][repo]

Workflow automation for Home Assistant — powered by [n8n](https://n8n.io).

n8n lets you connect any app with an API to any other, automate workflows,
and build complex automations — all without writing code. This add-on runs
n8n on your Home Assistant server with zero configuration required.

## Installation

1. Click the button above to add this repository to your Home Assistant.
2. Find **n8n** in the Add-on Store and click **Install**.
3. Click **Start**, then **OPEN WEB UI**.
4. Create your admin account — you're done!

For detailed configuration, webhooks, troubleshooting, and more, see the
[full documentation][docs].

## About

- Runs the official n8n Docker image.
- Accessible through Home Assistant Ingress (authenticated, no extra ports).
- Timezone auto-detected from Home Assistant.
- Data persists across restarts and is included in backups.

## Support

- [Open an issue][issues]
- [Home Assistant Community Forum][ha-forum]

## License

Apache 2.0. The bundled n8n software is maintained by [n8n GmbH][n8n-io]
under the [Sustainable Use License][n8n-license].

[repo-badge]: https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg
[repo]: https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Flielshani%2Fha-n8n
[docs]: n8n/DOCS.md
[issues]: https://github.com/lielshani/ha-n8n/issues
[ha-forum]: https://community.home-assistant.io
[n8n-io]: https://n8n.io
[n8n-license]: https://docs.n8n.io/hosting/community-edition-features/
