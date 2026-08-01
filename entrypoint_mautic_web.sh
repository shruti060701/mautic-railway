#!/bin/bash
# Custom replacement for the base image's own /entrypoint_mautic_web.sh.
#
# The stock script only runs `doctrine:migrations:migrate` if local.php
# already looks "installed" (db_driver + site_url both set), and otherwise
# silently skips migrations forever - it never actually calls mautic:install
# itself. That worked when local.php was hand-written once; it doesn't work
# here since our own local.php template (see local.php in this repo) always
# has site_url pre-populated from a shared env var on every boot, on every
# service, precisely so worker/cron never block waiting on a file they can
# never receive (no shared volumes on Railway). So this script always calls
# mautic:install directly instead of relying on that check.

source /startup/logger.sh

# mautic:install has its own built-in idempotency check (checkIfInstalled(),
# confirmed via Mautic's real InstallCommand.php source), but it only
# checks local.php's own db_driver/site_url fields, not the real database.
# Our local.php template pre-populates site_url from a shared env var on
# every boot (needed so worker/cron never wait forever on a file they can
# never receive, see wait_for_mautic_install.sh in this repo), which
# defeats that check completely - Mautic would always think it's already
# installed and skip the real install, confirmed via a real deploy crash
# during testing (migrations failing against tables that were never
# created). So this uses its own real database check instead, exactly the
# same PDO query wait_for_mautic_install.sh uses for worker/cron.
function is_mautic_schema_installed {
  php -r "
    try {
        \$pdo = new PDO(
            'mysql:host=' . getenv('MAUTIC_DB_HOST') . ';port=' . getenv('MAUTIC_DB_PORT') . ';dbname=' . getenv('MAUTIC_DB_DATABASE'),
            getenv('MAUTIC_DB_USER'),
            getenv('MAUTIC_DB_PASSWORD')
        );
        \$stmt = \$pdo->query(\"SHOW TABLES LIKE 'users'\");
        exit(\$stmt->rowCount() > 0 ? 0 : 1);
    } catch (Exception \$e) {
        exit(1);
    }
  "
}

if is_mautic_schema_installed; then
  log "[mautic_web]: Mautic schema already exists in the database, skipping install."
else
  log "[mautic_web]: Running mautic:install for the first time."
  su -s /bin/bash "$MAUTIC_WWW_USER" -c "php $MAUTIC_CONSOLE mautic:install --force --admin_email=\"$MAUTIC_ADMIN_EMAIL\" --admin_password=\"$MAUTIC_ADMIN_PASSWORD\" \"$MAUTIC_URL\""
fi

# Whichever branch above ran, local.php needs both site_url and
# secret_key set to our known values before Apache starts serving real
# requests:
# - A genuine first-time install writes a real site_url (good) but also
#   generates a fresh random secret_key (EncryptionHelper::generateKey(),
#   confirmed via Mautic's real InstallService.php source), overwriting
#   the deterministic MAUTIC_SECRET_KEY our template pre-populated.
# - The "already installed, skip" branch writes neither - local.php was
#   only just freshly created from our template this boot (config isn't
#   guaranteed to have survived from install time on every deploy path),
#   which deliberately omits site_url (see local.php for why), so without
#   this the web app would redirect every request to the installer even
#   though the database is genuinely fully installed.
# This patch makes both branches converge on the same correct state:
# real site_url, and secret_key identical to worker/cron's (which
# generate their own local.php from the same shared env var and never
# run install themselves - without a matching key they couldn't decrypt
# anything web encrypts, OAuth tokens, some integration credentials).
log "[mautic_web]: Ensuring local.php has the correct site_url and secret_key."
php -r "
\$configFile = getenv('MAUTIC_VOLUME_CONFIG') . '/local.php';
include \$configFile;
\$parameters['site_url'] = getenv('MAUTIC_URL');
\$parameters['secret_key'] = getenv('MAUTIC_SECRET_KEY');
file_put_contents(\$configFile, '<?php' . PHP_EOL . '\$parameters = ' . var_export(\$parameters, true) . ';' . PHP_EOL);
"

log "[mautic_web]: Running migrations..."
su -s /bin/bash "$MAUTIC_WWW_USER" -c "php $MAUTIC_CONSOLE doctrine:migrations:migrate -n"

# Mautic logs its own caught exceptions (via ExceptionListener's Monolog
# logger, confirmed via real source) to a file under var/logs, not
# stdout/stderr, so real errors (e.g. the "Site is offline" generic page)
# never show up in `railway logs`. Tail whatever gets written there into
# this container's own stdout so real errors are actually visible.
mkdir -p "${MAUTIC_VOLUME_LOGS}"
touch "${MAUTIC_VOLUME_LOGS}/.tail-placeholder"
tail -F "${MAUTIC_VOLUME_LOGS}"/*.log "${MAUTIC_VOLUME_LOGS}"/*.php 2>/dev/null &

# A real matching case on Mautic's own forum ("Site is offline after
# update to 6.0") traced the identical generic error page to var/cache
# and var/tmp/twig not being writable by the web server user - those
# subdirectories don't exist yet at container-check time (Symfony creates
# them on first real request), so the earlier check_volumes_exist_ownership
# chown, which only touches paths that already exist, never reaches them.
# Force ownership of the whole var tree right before Apache starts.
chown -R "${MAUTIC_WWW_USER}:${MAUTIC_WWW_GROUP}" "${MAUTIC_VAR}"

if [ "${FLAVOUR}" = "fpm" ]; then
  php-fpm
elif [ "${FLAVOUR}" = "apache" ]; then
  # Same "AH00534: More than one MPM loaded" fix already proven on this
  # project's WordPress template: mpm_event/mpm_worker end up loaded
  # alongside mpm_prefork in Railway's container runtime, and a build-time
  # -only a2dismod/a2enmod doesn't stick, something re-enables the
  # conflicting module after build. Redoing the toggle immediately before
  # apache actually launches is the part that works.
  a2dismod mpm_event mpm_worker || true
  a2enmod mpm_prefork
  apache2-foreground
else
  log "[mautic_web]: FLAVOUR variable is not set correctly, exiting."
  exit 1
fi
