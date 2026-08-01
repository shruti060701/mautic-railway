# Railway Template Composer Checklist: Mautic

Apply these settings in the Railway template composer when generating the template from the project.

**Expected services this template deploys:** `mautic-web`, `mautic-worker`, `mautic-cron` (all three GitHub-connected to the same repo/Dockerfile, differentiated only by `DOCKER_MAUTIC_ROLE`), `MySQL` (Railway native plugin). **This is a pre-deploy draft using expected variable names. Verify every value against the actual live service via `railway variables --json` once deployed, and update this file before using it in the composer, don't fill in the composer from this draft alone.**

---

## 0. Real Architecture Problem This Template Solves (read before touching variables)

Mautic's official Docker image normally expects web, worker, and cron to share one config file (`local.php`) that records install state and a shared encryption key (`secret_key`). **Railway does not support attaching one volume to multiple services**, confirmed via Railway's own community help station, so a naive 3-service split would leave worker and cron waiting forever for an install signal they can never receive, or generate a mismatched encryption key if they installed independently.

This template's fix: a custom `/templates/local.php` (baked into the image) that populates `site_url` and `secret_key` from shared environment variables identically on every service's own local volume, and a custom `entrypoint_mautic_web.sh` that always runs `mautic:install` (safe, it's idempotent, confirmed via Mautic's real `InstallCommand.php` source) and then re-syncs `secret_key` back to the shared env var value after install, since a genuine first install generates its own random one that would otherwise only exist on web. **`MAUTIC_SECRET_KEY` must be the exact same value on all three services** for this to work, it's the one true cross-service consistency requirement in this whole template.

---

## 1. Healthcheck Settings

### `mautic-web` (app service)
- **Healthcheck Path:** `/` or a real Mautic health/login-page path, verify the exact real behavior against the live deploy, not assumed. **Post-deploy:** confirm the actual path once live.

### `mautic-worker` / `mautic-cron` (app services)
- **No HTTP healthcheck.** Neither exposes a public port. Rely on `restartPolicyType = "on_failure"` instead.

### `MySQL` (native plugin)
- No healthcheck configuration needed, Railway's native database plugin handles its own health monitoring.

---

## 2. Variable Descriptions (Add to EVERY variable, on all three Mautic services)

### `mautic-web`, `mautic-worker`, `mautic-cron` (shared variable set, values must match across all three except where noted)

| Variable | Value | Mark Optional? | Description |
|----------|-------|-----------------|-------------|
| `DOCKER_MAUTIC_ROLE` | `mautic_web` / `mautic_worker` / `mautic_cron` (different per service) | No | Which Mautic process this service runs. |
| `MAUTIC_DB_HOST` | `${{MySQL.MYSQLHOST}}` (verify real variable name post-deploy) | No | MySQL private hostname. |
| `MAUTIC_DB_PORT` | `${{MySQL.MYSQLPORT}}` (verify real variable name post-deploy) | No | MySQL port. |
| `MAUTIC_DB_DATABASE` | `${{MySQL.MYSQLDATABASE}}` (verify real variable name post-deploy) | No | Database name. Note the real image expects `MAUTIC_DB_DATABASE`, not `MAUTIC_DB_NAME` (confirmed directly in Mautic's own `docker-mautic` source), the reference Railway template uses the wrong variable name here. |
| `MAUTIC_DB_USER` | `${{MySQL.MYSQLUSER}}` (verify real variable name post-deploy) | No | MySQL username. |
| `MAUTIC_DB_PASSWORD` | `${{MySQL.MYSQLPASSWORD}}` (verify real variable name post-deploy) | No | MySQL password. |
| `MAUTIC_URL` | `https://${{mauticWeb.RAILWAY_PUBLIC_DOMAIN}}` | No | Must be identical on all three services, cross-referenced from the web service's own domain, not each service's own (worker/cron have no public domain). |
| `MAUTIC_SECRET_KEY` | `${{secret(32)}}` set once, referenced as `${{mauticWeb.MAUTIC_SECRET_KEY}}` on worker/cron | No | Must be byte-identical across all three services, see section 0. This is the one variable where a naive independent `${{secret(32)}}` on each service would silently break cross-service decryption, matching the lesson already learned on Firecrawl's Postgres password. |

### `mautic-web` only (worker/cron don't need these)

| Variable | Value | Mark Optional? | Description |
|----------|-------|-----------------|-------------|
| `MAUTIC_ADMIN_EMAIL` | User-provided | No | Admin account email created on first install. |
| `MAUTIC_ADMIN_PASSWORD` | `${{secret(32)}}` | No | Admin account password created on first install. |

---

## 3. Secrets That Must Use `${{secret()}}`

| Variable | Template Syntax |
|----------|-----------------|
| `MAUTIC_ADMIN_PASSWORD` | `${{secret(32)}}` (web only) |
| `MAUTIC_SECRET_KEY` | `${{secret(32)}}` on `mautic-web`, then `${{mauticWeb.MAUTIC_SECRET_KEY}}` (a cross-reference, NOT another independent `${{secret(32)}}`) on `mautic-worker` and `mautic-cron` |

---

## 4. Volumes

**Required on `mautic-web` only.** Mount a Railway Volume covering config, logs, and media (e.g. at `/var/www/html/config` for config, or a broader parent path, verify the real minimum viable mount point against the live deploy). User-uploaded media specifically needs to persist across redeploys.

**Not required on `mautic-worker` or `mautic-cron`.** Their own config is regenerated deterministically from shared env vars on every boot (see section 0), so there's no real state to lose by leaving them without a volume. Document this deliberate asymmetry so it doesn't look like an oversight later.

---

## 5. Known Troubleshooting

- **Reference template bakes secrets into build-time ARGs.** `Shinyduo/mautic-railway`'s Dockerfile passes `MAUTIC_DB_PASSWORD` and `MAUTIC_ADMIN_PASSWORD` as Docker `ARG`s, which get embedded in image layers and require a full rebuild to rotate. This template uses genuine runtime environment variables instead.
- **Reference template uses `mautic/mautic:latest`, unpinned.** This template pins `mautic/mautic:7.1.3-apache`, verified against Docker Hub's tags API as matching the current `latest` digest at authoring time. Re-verify before publishing if time has passed.
- **`MAUTIC_DB_DATABASE`, not `MAUTIC_DB_NAME`.** Confirmed directly in the real image's entrypoint/template source. Using the wrong name silently leaves the database name unset.
- **No shared volumes across services, this is the core architectural constraint this whole template is built around.** See section 0. Don't "simplify" this template later by removing the custom `local.php`/`entrypoint_mautic_web.sh` files, thinking they're unnecessary complexity, they're the actual fix for a real platform limitation, not incidental cruft.
- **`mautic:install` is safe to run on every boot.** Confirmed via Mautic's own `InstallCommand.php`: it calls `checkIfInstalled()` first and no-ops with "Mautic already installed" if the schema exists. This is why the custom `entrypoint_mautic_web.sh` calls it unconditionally instead of trying to detect install state itself.
- **Worker/cron may show early transient restarts on a brand new deploy.** Their own config is ready (from shared env vars) slightly before web's actual database schema exists. Railway's restart policy self-heals this. Confirmed as expected during testing, distinguish this from a genuine bug via `instance status: RUNNING` after a few retries, same diagnostic standard used on Firecrawl's transient ECONNREFUSED case.
- **SMTP is not configured by this template.** Mautic needs a real transactional email provider configured through its own UI after deploying to actually send campaign emails. Document this clearly so a deployer doesn't think campaigns are broken when it's actually an unconfigured mailer.

---

## 6. Post-Deploy Steps

After the template is published, test-deploy from a fresh Railway account (incognito window) and verify:

1. No "needs configuration" prompts appear for any variable.
2. Pull real `railway variables --json` from the MySQL plugin and confirm the exact variable names (`MYSQLHOST` etc. are placeholders in this draft, not confirmed).
3. The `mautic-web` service comes online and reaches a real healthy state, confirm the actual healthcheck path against live behavior.
4. Real deploy logs confirm `mautic:install` completed successfully on first boot (not just that the container started).
5. Log in with the real admin credentials and confirm the dashboard loads.
6. Build a real test campaign, add a test contact, trigger it, and confirm the email actually arrives (after configuring a real SMTP provider), proving the worker genuinely processes jobs, not just that the web UI loads.
7. Confirm a scheduled task (segment rebuild or time-based trigger) actually fires on schedule, proving the cron service is genuinely running, not just present.
8. Redeploy all three services together and confirm the admin login and any previously created campaign/contact data still work afterward, proving the deterministic-config approach from section 0 genuinely survives a real redeploy cycle, not just a first boot.
