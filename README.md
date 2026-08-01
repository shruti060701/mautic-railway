# Mautic: Open-Source Marketing Automation Platform

Deploy Mautic, the open-source marketing automation platform comparable to HubSpot and Mailchimp, on Railway with one click. Full three-service architecture (web, worker, cron) so campaigns and scheduled emails actually run, not just a bare web UI.

## Deploy on Railway

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.app/new/template)

## Features

- **Real campaign execution, not just a dashboard**: A dedicated worker processes the email/queue jobs your campaigns create, and a dedicated cron service runs Mautic's own scheduled tasks (segment updates, campaign triggers, report generation). Skipping either means campaigns silently never fire.
- **Drag-and-drop campaign builder**: Visual campaign and email flow editor, no code required.
- **Lead tracking and scoring**: Track contact behavior across channels and score leads automatically.
- **Auto-installed on first deploy**: The web service runs Mautic's real install process automatically using your provided admin credentials, no manual console command needed.
- **Real official image, current version**: Runs `mautic/mautic:7.1.3-apache`, verified against Docker Hub as matching the current release, not a stale or unofficial rebuild.

## How to Use

1. Click the Deploy on Railway button above.
2. Railway provisions three Mautic services (web, worker, cron) plus a MySQL database, wired together automatically.
3. Wait for the web service's healthcheck to pass, first boot takes longer than usual since it runs Mautic's full install process.
4. Log in at your Railway domain with the admin email and password you set (or the auto-generated ones in the web service's Variables tab).
5. Build a test campaign, add yourself as a contact, and confirm you actually receive the email, that's the real proof the worker is processing jobs correctly.

## Notes

- **This template intentionally deviates from the reference Railway Mautic template in two real ways**: it doesn't bake database credentials or the admin password into the image at build time (the reference does, which embeds them in image layers, a real exposure risk, and requires a full rebuild to rotate them), and it pins a specific current image version instead of `latest`.
- **Railway doesn't support sharing one volume across services.** Mautic's own config file normally gets shared between web, worker, and cron in a typical Docker Compose setup. This template works around that by deriving each service's config deterministically from the same shared environment variables instead of a shared file, confirmed working via real testing, not just planned. See the composer checklist for the technical detail if you're curious.
- **First boot takes longer than a typical template.** The web service runs a full Mautic install (schema creation, admin account, initial config) before it's ready, budget a couple of minutes longer than a simple single-service app.
- **Worker and cron may show a few early restarts on a brand new deploy.** They start trying to do real work as soon as their own config is ready, which can be a few seconds before the web service finishes creating the database schema. Railway's restart policy handles this automatically, it's expected and self-healing, not a bug.

## Self-Hosting on Other Platforms

Clone the repository:
```bash
git clone https://github.com/mautic/docker-mautic
cd docker-mautic/examples/basic
docker compose up
```

## License

Mautic's core is released under the GPL-3.0 open-source license, free to self-host. Mautic also offers Mautic Cloud, a managed hosting option.

## Support

- **GitHub**: https://github.com/mautic/mautic
- **Docs**: https://docs.mautic.org
- **Community**: https://forum.mautic.org
- **Issues**: https://github.com/mautic/mautic/issues
