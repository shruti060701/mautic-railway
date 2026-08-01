# Railway Template Composer Checklist: Mautic

Apply these settings in the Railway template composer when generating the template from the project.

**Real live service names:** `mautic-railway` (web, GitHub-connected), `harmonious-light` (worker, same repo), `focused-encouragement` (cron, same repo), `MySQL` (Railway native plugin, `mysql:9.4`). **Fully verified end to end on 2026-08-01/02**: real `mautic:install` completed, real login page returns `200` with genuine username/password fields, worker consumes the message queue cleanly, cron passes its database-based install-wait check and registers its crontab, all three survive a real redeploy cycle. This took **7 distinct real bugs**, each found via real logs/source, not guessed, documented in section 5. Don't skip reading section 0 before touching this template again.

---

## 0. Real Architecture Problem This Template Solves (read before touching variables)

Mautic's official Docker image normally expects web, worker, and cron to share one config file (`local.php`) that records install state and a shared encryption key (`secret_key`). **Railway does not support attaching one volume to multiple services**, confirmed via Railway's own community help station, so a naive 3-service split leaves worker/cron waiting forever for an install signal they can never receive, or generates a mismatched encryption key if they installed independently.

**The real, verified fix, five cooperating pieces:**
1. `local.php` (custom template): populates `secret_key` from a shared env var on every service's own local volume. Deliberately does **NOT** set `site_url` here, Mautic's own `mautic:install` checks that exact field to decide whether to skip installing, and a pre-populated value defeats it on every boot, confirmed via a real crash where migrations failed against tables that were never created.
2. `entrypoint_mautic_web.sh` (custom): checks the **real database** (`SHOW TABLES LIKE 'users'`) instead of trusting Mautic's own local.php-based check, decides whether to run `mautic:install`, then unconditionally patches `local.php` with the real `site_url` and the shared `secret_key` regardless of which branch ran (a genuine install writes site_url but a fresh random secret_key; a skipped install writes neither).
3. `docker-entrypoint-wrapper.sh` (new top-level `ENTRYPOINT`): symlinks web's `config` and `docroot/media` into subdirectories of **one** real Railway Volume (`/mnt/mautic-persist`), since both need to survive restarts but Railway only allows one volume per service. Also `chown`s the real target directories directly, not the symlinks (chown on a symlink argument chowns the symlink itself, not what it points to).
4. `check_volumes_exist_ownership.sh` (overridden): creates the six directories the base image assumes docker-compose would auto-create via separate volumes, instead of hard-failing when they're missing.
5. `wait_for_mautic_install.sh` (overridden): worker/cron use this same real-database check instead of the local.php-based stock one, since their own local.php always looks "complete" from boot (by design, see point 1) regardless of real DB state.

**`MAUTIC_SECRET_KEY` must be the exact same value on all three services** for this to work, it's the one true cross-service consistency requirement in this whole template.

---

## 1. Healthcheck Settings

### `mautic-railway` (web app service)
- **Healthcheck Path:** `/s/login`, confirmed live returning `200` with a real login form. **Target port must be explicitly set to `80`** in the dashboard's Networking settings, confirmed this does NOT auto-populate from `PORT` env var or `EXPOSE 80` in the Dockerfile, real deploy showed `targetPort: null` and 502s until manually set. No CLI command found to set this on an existing domain (`railway domain -p <port>` only applies when creating a new domain).

### `harmonious-light` (worker) / `focused-encouragement` (cron)
- **No HTTP healthcheck.** Neither exposes a public port. Rely on `restartPolicyType = "on_failure"` instead.

### `MySQL` (native plugin)
- No healthcheck configuration needed, Railway's native database plugin handles its own health monitoring.

---

## 2. Variable Descriptions (Add to EVERY variable, on all three Mautic services)

### `mautic-railway`, `harmonious-light`, `focused-encouragement` (shared set, values must match across all three except role)

| Variable | Value | Mark Optional? | Description |
|----------|-------|-----------------|-------------|
| `DOCKER_MAUTIC_ROLE` | `mautic_web` / `mautic_worker` / `mautic_cron` (different per service) | No | Which Mautic process this service runs. |
| `MAUTIC_DB_HOST` | `${{MySQL.MYSQLHOST}}` | No | MySQL private hostname. Confirmed real variable name live. |
| `MAUTIC_DB_PORT` | `${{MySQL.MYSQLPORT}}` | No | MySQL port. Confirmed real variable name live. |
| `MAUTIC_DB_DATABASE` | `${{MySQL.MYSQLDATABASE}}` | No | Database name. The real image expects `MAUTIC_DB_DATABASE`, not `MAUTIC_DB_NAME` (confirmed directly in Mautic's own `docker-mautic` source), the reference Railway template uses the wrong variable name here. Confirmed real MySQL plugin variable name live. |
| `MAUTIC_DB_USER` | `${{MySQL.MYSQLUSER}}` | No | MySQL username. Confirmed real variable name live. |
| `MAUTIC_DB_PASSWORD` | `${{MySQL.MYSQLPASSWORD}}` | No | MySQL password. Confirmed real variable name live. |
| `MAUTIC_URL` | **`mautic-railway`**: `https://${{RAILWAY_PUBLIC_DOMAIN}}` (its own domain, no cross-reference). **`harmonious-light` / `focused-encouragement`**: `${{mautic-railway.MAUTIC_URL}}` (references web's already-built `MAUTIC_URL` directly, not `RAILWAY_PUBLIC_DOMAIN` again, and no `https://` prefix needed since the referenced value already has one). | No | Confirmed live as `https://mautic-railway-production.up.railway.app` on all three. An earlier draft of this checklist wrongly showed `https://${{mautic-railway.RAILWAY_PUBLIC_DOMAIN}}` on all three rows, including web referencing itself, caught directly by Shruti comparing the dashboard's real value against this file. |
| `MAUTIC_SECRET_KEY` | `${{secret(32)}}` set once on `mautic-railway`, then `${{mautic-railway.MAUTIC_SECRET_KEY}}` on the other two | No | Must be byte-identical across all three, confirmed live via SHA-256 hash comparison without printing the value. |

### `mautic-railway` only (worker/cron don't need these)

| Variable | Value | Mark Optional? | Description |
|----------|-------|-----------------|-------------|
| `MAUTIC_ADMIN_EMAIL` | User-provided | No | Admin account email created on first install. |
| `MAUTIC_ADMIN_PASSWORD` | `${{secret(32)}}` | No | Admin account password created on first install. |
| `PORT` | `80` | **Yes** | Set explicitly during testing; did not actually resolve the 502/targetPort issue on its own, the real fix was the dashboard target-port field (see section 1). Keep this set regardless since it's a reasonable Railway convention, but don't rely on it alone. |

### `MySQL` (Native Plugin) Variables

Real values pulled directly from the live `MySQL` service via `railway variables --json`, not placeholders. Every variable in the platform-injected "N variables added by Railway" collapsed section (`RAILWAY_ENVIRONMENT`, `RAILWAY_PROJECT_ID`, `RAILWAY_VOLUME_ID`, etc.) still needs a description in the actual composer even though it's not template-specific, confirmed live the composer's own validation requires it regardless of origin (see the equivalent note on Infisical's checklist for the full explanation, same platform behavior here).

**Reference direction, confirmed against the real composer UI, not assumed**: `MYSQL_DATABASE` and `MYSQL_ROOT_PASSWORD` (underscore between MYSQL and the word) are the real, literal-valued source variables, the names the underlying `mysql:9.4` image itself expects. `MYSQLDATABASE` and `MYSQLPASSWORD` (no underscore) are Railway's own convenience aliases that **reference** those, prefilled automatically by Railway's native plugin template. Shruti caught this backwards in an earlier version of this table (it showed the alias as the literal and the real variable referencing the alias), confirmed live: the composer's own prefilled `MYSQLDATABASE` field already shows `${{MYSQL_DATABASE}}`, not a literal. **Don't overwrite an already-prefilled alias field with a literal value, leave it as the reference it already is**, same lesson as `PGHOST` being prefilled with `${{RAILWAY_PRIVATE_DOMAIN}}` on this project's Postgres-based templates.

| Variable | Value | Mark Optional? | Description |
|----------|-------|-----------------|-------------|
| `MYSQLHOST` | `${{RAILWAY_PRIVATE_DOMAIN}}` | **Yes** | Private-network hostname for this service. Confirmed live as `mysql.railway.internal`. Already prefilled by Railway, don't overwrite. |
| `MYSQLPORT` | `3306` | **Yes** | Port MySQL listens on. |
| `MYSQLUSER` | `root` | **Yes** | Superuser username. |
| `MYSQL_DATABASE` | `railway` | **Yes** | Default database name, the real literal value. This is what `MAUTIC_DB_DATABASE` on the app services ultimately resolves to via `MYSQLDATABASE`. |
| `MYSQL_ROOT_PASSWORD` | `${{secret(32)}}` | No | Superuser password, auto-generated per deploy, the real literal value. |
| `MYSQLDATABASE` | `${{MYSQL_DATABASE}}` | **Yes** | Alias referencing `MYSQL_DATABASE`. Already prefilled by Railway, don't overwrite with a literal. |
| `MYSQLPASSWORD` | `${{MYSQL_ROOT_PASSWORD}}` | No | Alias referencing `MYSQL_ROOT_PASSWORD`. Already prefilled by Railway, don't overwrite with a literal. |
| `MYSQL_URL` | `mysql://${{MYSQLUSER}}:${{MYSQLPASSWORD}}@${{RAILWAY_PRIVATE_DOMAIN}}:3306/${{MYSQLDATABASE}}` | No | Full private-network connection string. Confirmed live, matches the real resolved shape (`mysql://root:[password]@mysql.railway.internal:3306/railway`). Not directly referenced by the app services, they build their own connection from the individual `MYSQL*` variables instead, but document it since the composer will show it. |
| `MYSQL_PUBLIC_URL` | `mysql://${{MYSQLUSER}}:${{MYSQLPASSWORD}}@${{RAILWAY_TCP_PROXY_DOMAIN}}:${{RAILWAY_TCP_PROXY_PORT}}/${{MYSQLDATABASE}}` | **Yes** | Public connection string. Only resolves to a real host/port once a TCP Proxy is enabled under this service's Settings → Networking, confirmed live it's an empty/unusable host:port until then. |

---

## 3. Secrets That Must Use `${{secret()}}`

| Variable | Template Syntax |
|----------|-----------------|
| `MAUTIC_ADMIN_PASSWORD` | `${{secret(32)}}` (web only) |
| `MAUTIC_SECRET_KEY` | `${{secret(32)}}` on `mautic-railway`, then `${{mautic-railway.MAUTIC_SECRET_KEY}}` (a cross-reference, NOT another independent `${{secret(32)}}`) on the worker and cron services |

---

## 4. Volumes

**Required on `mautic-railway` (web) only.** Mount at `/mnt/mautic-persist`. `docker-entrypoint-wrapper.sh` symlinks `config` and `docroot/media` subdirectories into it. **Confirmed live as the real fix for two real bugs**: (1) the mount point directory must already exist in the image at build time (`RUN mkdir -p /mnt/mautic-persist` in the Dockerfile) or Railway's volume silently doesn't attach at that path despite showing as attached in `railway volume list`, and (2) `chown -R` must target the real directories under the mount, not the symlink paths pointing to them.

**Not required on worker or cron.** Their own config is regenerated deterministically from shared env vars on every boot (see section 0), so there's no real state to lose by leaving them without a volume.

---

## 5. Known Troubleshooting (7 real bugs found and fixed this build)

1. **Reference template bakes secrets into build-time ARGs.** `Shinyduo/mautic-railway`'s Dockerfile passes `MAUTIC_DB_PASSWORD`/`MAUTIC_ADMIN_PASSWORD` as Docker `ARG`s, embedded in image layers, requiring a full rebuild to rotate. This template uses genuine runtime environment variables instead.
2. **Reference template uses `mautic/mautic:latest`, unpinned, and the current image generation doesn't auto-install from env vars at all** (that model changed upstream). This template pins `mautic/mautic:7.1.3-apache` and builds real install logic instead. Re-verify the pin is still current before publishing.
3. **Missing directories crash on boot.** The base image assumes docker-compose gives each of six paths (config, var, var/logs, media, media/files, media/images) its own auto-created volume. Railway only allows one volume per service, so `check_volumes_exist_ownership.sh` is overridden to `mkdir -p` them instead of hard-failing.
4. **`local.php` pre-populated with `site_url` defeats Mautic's own install-check.** `mautic:install`'s `checkIfInstalled()` only checks `local.php`'s `site_url`/`db_driver` fields, not the real database. Pre-populating `site_url` (needed so worker/cron don't wait forever with no shared volume) made every boot think it was "already installed" and skip the real install entirely. Fixed by checking the real database directly instead (`wait_for_mautic_install.sh`, `entrypoint_mautic_web.sh`).
5. **Volume mount point must pre-exist in the image.** `railway volume list` showed the volume correctly attached at `/mnt/mautic-persist`, but the path was genuinely empty inside the running container until `RUN mkdir -p /mnt/mautic-persist` was added to the Dockerfile.
6. **`chown -R` on a symlink argument chowns the symlink, not its target.** Caused real "Permission denied" errors writing uploaded media until the wrapper script was fixed to `chown` the real `/mnt/mautic-persist/*` paths directly.
7. **A genuine Mautic 7.1.3 core bug, not caused by this template**: `OverrideIncludeExtension::includeWithEvent()` declares a `string` return type, but Twig 3.28+ (bundled in this image) can return a `Twig\Markup` object from `CoreExtension::include()`, throwing a `TypeError` on every page using the `include()` Twig function, including login. Matches a real, currently-open Mautic forum thread. Already fixed on Mautic's own `main` branch (return type widened to `string|Markup`) but not yet in a released image tag. This template ships the real fixed file directly (`OverrideIncludeExtension.php`). **Re-verify this override is still needed and drop it once a `7.2.0+` image tag is published** (check Docker Hub before every republish).

**Other real, non-bug findings worth documenting:**
- **`mautic:install` is safe to run on every boot.** It calls `checkIfInstalled()` (querying local.php, per bug #4 above) first and no-ops with "Mautic already installed" if already set, rather than erroring.
- **Mautic logs caught exceptions to a file** (`var/logs/mautic_prod-YYYY-MM-DD.php`), never to stdout/stderr, so `railway logs` alone won't show real application errors, only crash-level ones. This is why bug #7 took so long to root-cause: the generic "Site is offline" page and a misleading PHP deprecation notice were the only stdout signal for several iterations, until a background polling loop (tailing recently-modified files under `var/`) was added to `entrypoint_mautic_web.sh` to surface the real exception. Keep that polling loop in the template, it's genuinely useful for a deployer debugging their own issues later, not just a one-off diagnostic hack.
- **`railway logs -n <N>` can lag behind real container state by 30-60+ seconds** immediately after a redeploy, confirmed repeatedly this build. `railway logs --since <duration>` was more reliable for getting a complete, current picture. Don't conclude a container is hung from a short/incomplete `-n` log fetch, retry with `--since` before assuming something's actually broken.
- **Worker/cron may show early transient restarts on a brand new deploy** (their own config is ready slightly before web's schema exists). Railway's restart policy self-heals this, same diagnostic standard as Firecrawl's transient ECONNREFUSED case.
- **SMTP is not configured by this template.** A real transactional email provider must be configured through Mautic's own UI after deploying for campaigns to actually send.

---

## 6. Post-Deploy Steps

**Verified once end to end on the real build project (`mautic`, 2026-08-01/02)**, status per step:

1. No "needs configuration" prompts appear for any variable. ✅
2. Real `railway variables --json` confirmed exact MySQL plugin variable names (`MYSQLHOST`/`MYSQLPORT`/`MYSQLDATABASE`/`MYSQLUSER`/`MYSQLPASSWORD`). ✅
3. `mautic-railway` comes online; `/s/login` returns `200` with a real login form (confirmed via `grep` for username/password fields in the response body, not just a title check). ✅ **Requires the dashboard target-port fix from section 1, doesn't work via CLI/env var alone.**
4. Real deploy logs confirm a genuine `mautic:install` run completed (`Mautic Install / Creating database / Creating schema / Loading fixtures / Creating admin user / Final steps / Install complete`), not just that the container started. ✅
5. Worker (`harmonious-light`) logs show a clean Symfony Messenger worker waiting for jobs, no errors. ✅
6. Cron (`focused-encouragement`) logs show it passing the database-based install-wait check and proceeding to register its crontab. ✅
7. **Still pending as of this checkpoint, do before considering this template fully done**: log in with real admin credentials through the actual browser UI (not just confirming the login page renders), configure a real SMTP provider, build a real test campaign, add a test contact, trigger it, and confirm the email actually arrives, proving the worker genuinely processes jobs end to end.
8. **Also still pending**: confirm a scheduled task (segment rebuild or time-based trigger) actually fires on schedule, proving cron is genuinely functional, not just running.
9. **Also still pending**: redeploy all three services together and confirm admin login and any created campaign/contact data still work afterward, the real proof the deterministic-config approach in section 0 survives a genuine redeploy cycle, not just first boot (partially confirmed already via several redeploys during debugging, but worth one clean, deliberate pass once SMTP/campaign testing above is done).

**When re-publishing this template later, repeat this pass on a fresh Railway account (incognito) once**, and specifically re-check whether bug #7's `OverrideIncludeExtension.php` override is still needed against whatever the then-current image tag is.
