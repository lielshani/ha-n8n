# Home Assistant Add-on: n8n

Workflow automation for Home Assistant — powered by [n8n](https://n8n.io).

n8n (pronounced n-eight-n) lets you connect any app with an API to any other,
automate workflows, and build complex automations — all without writing code.
It runs entirely on your Home Assistant server, keeping your data private and
under your control.

## Installation

The installation of this add-on is straightforward and no different from
installing any other Home Assistant add-on.

1. Add this repository to your Home Assistant add-on store:

   [![Add repository to my Home Assistant instance.][repo-badge]][repo]

   Or manually: go to **Settings** > **Add-ons** > **Add-on Store** >
   three-dot menu (top right) > **Repositories** and paste:

   ```
   https://github.com/lielshani/ha-n8n
   ```

2. Find **n8n** in the add-on store and click **Install**.
3. Click **Start**.
4. Click **OPEN WEB UI** to access n8n through Home Assistant.
5. Create your admin account on the n8n setup screen — you're done!

> **No configuration is required.** The add-on works out of the box with
> sensible defaults. Your timezone is automatically detected from Home
> Assistant, data persists across restarts, and the UI is securely accessed
> through Home Assistant's built-in Ingress.

## How it works

This add-on runs n8n inside your Home Assistant instance using
[Ingress](https://www.home-assistant.io/blog/2019/04/15/hassio-ingress/),
meaning:

- The n8n editor is accessible directly from the Home Assistant sidebar.
- All traffic is authenticated through Home Assistant — no extra passwords
  needed to reach the UI.
- Your workflows, credentials, and execution history are stored locally in
  `/data`, which is persisted and included in Home Assistant backups.

## Configuration

Most users do not need to change any configuration. The defaults work for
the vast majority of setups.

**Remember to restart the add-on when the configuration is changed.**

### Option: `timezone` (optional)

Override the timezone used by n8n for scheduled triggers and date/time
operations. When not set, the add-on automatically uses Home Assistant's
configured timezone.

```yaml
timezone: America/New_York
```

See the [list of valid timezones][tz-list].

### Option: `env_vars_list` (optional)

A list of n8n environment variables. Each entry must follow the format
`KEY: value`. You can add as many variables as you need.

```yaml
env_vars_list:
  - "WEBHOOK_URL: https://my-tunnel.example.com"
  - "N8N_ENCRYPTION_KEY: my-secret-key"
```

For all available environment variables, see the
[n8n environment variables documentation][n8n-env-vars].

**Note:** _This is an example. Do not copy and paste it — create your own
based on your needs._

### Option: `cmd_line_args` (optional)

Pass additional command-line arguments to the n8n process. This is an
advanced option. Most users should leave this empty.

```yaml
cmd_line_args: "start --tunnel"
```

## Webhooks & external access

The n8n UI is served through Home Assistant Ingress, which means it is
protected by Home Assistant authentication. This is great for security but
means **webhooks cannot go through Ingress** — they need to be publicly
accessible without authentication.

### Setting up webhooks

To use webhook-based triggers and the n8n API:

1. Expose port `5678` through a tunnel to the internet. The recommended
   approach is the [Cloudflared add-on][cloudflared] or a similar reverse
   proxy / tunnel solution.
2. Set the `WEBHOOK_URL` environment variable to the public URL of the
   tunnel:

   ```yaml
   env_vars_list:
     - "WEBHOOK_URL: https://n8n.your-domain.com"
   ```

3. Restart the add-on.

### Nabu Casa

If you use [Nabu Casa](https://www.nabucasa.com/) remote access, set the
`EXTERNAL_URL` environment variable to your Nabu Casa URL for OAuth2
redirect URLs to work properly:

```yaml
env_vars_list:
  - "EXTERNAL_URL: https://xxxxxxxx.ui.nabu.casa"
```

### Direct access (not recommended)

You can expose port `5678` directly by enabling it under the **Network**
section of the add-on configuration tab. This bypasses Home Assistant
authentication and is not recommended.

## Installing external npm packages

n8n supports external npm packages in the Code node. To allow specific
packages, add the `NODE_FUNCTION_ALLOW_EXTERNAL` environment variable:

```yaml
env_vars_list:
  - "NODE_FUNCTION_ALLOW_EXTERNAL: lodash,moment"
```

## Troubleshooting

### `401: Unauthorized` when setting up OAuth credentials

Some browsers block the OAuth popup window when accessed through Ingress.
**Workaround:** Copy the URL from the popup window and paste it into a new
tab in the same browser window. The authorization will then complete.

### Resetting your admin password

If you forget your admin password, you can reset n8n's user management:

1. In the add-on **Configuration** tab, set `cmd_line_args` to:

   ```
   user-management:reset
   ```

2. **Save** and **Restart** the add-on.
3. Wait for the log to show:
   `Successfully reset the database to default user state.`
4. Clear the `cmd_line_args` field, **Save**, and **Restart** again.
5. You will be prompted to create a new admin account.

> **Warning:** This removes all existing user accounts.

### The add-on won't start

Check the add-on logs (**Log** tab). Common causes:

- A malformed entry in `env_vars_list` (must match `KEY: value` format).
- Port conflicts if you exposed port `5678` and another service uses it.

If the issue persists, [open an issue][issues] with the log output.

## Useful resources

- [n8n Documentation][n8n-docs]
- [n8n Community Workflows][n8n-workflows]
- [n8n Available Integrations][n8n-integrations]
- [n8n Environment Variables][n8n-env-vars]

## Support

Got questions or found a bug?

- [Open an issue on GitHub][issues]
- [Home Assistant Community Forum][ha-forum]

## License

This add-on is published under the Apache 2.0 license.
The bundled n8n software is maintained by [n8n GmbH][n8n-io] under the
[Sustainable Use License][n8n-license].

[repo-badge]: https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg
[repo]: https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Flielshani%2Fha-n8n
[cloudflared]: https://github.com/brenner-tobias/addon-cloudflared
[n8n-docs]: https://docs.n8n.io
[n8n-workflows]: https://n8n.io/workflows
[n8n-integrations]: https://n8n.io/integrations
[n8n-env-vars]: https://docs.n8n.io/hosting/configuration/environment-variables/
[n8n-io]: https://n8n.io
[n8n-license]: https://docs.n8n.io/hosting/community-edition-features/
[tz-list]: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones#List
[issues]: https://github.com/lielshani/ha-n8n/issues
[ha-forum]: https://community.home-assistant.io
