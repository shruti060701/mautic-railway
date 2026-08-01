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

  # A genuine first-time install generates a fresh random secret_key
  # (EncryptionHelper::generateKey(), confirmed via Mautic's real
  # InstallService.php source) and writes it into THIS service's own
  # local.php, overwriting the deterministic MAUTIC_SECRET_KEY value our
  # template pre-populated. Patch it back to the shared env var value so
  # worker and cron, which independently generate their own local.php from
  # the exact same env var and never run install themselves, end up with an
  # identical key. Without this, worker/cron couldn't decrypt anything web
  # encrypts (OAuth tokens, some integration credentials).
  log "[mautic_web]: Syncing secret_key to the shared MAUTIC_SECRET_KEY value."
  php -r "
  \$configFile = getenv('MAUTIC_VOLUME_CONFIG') . '/local.php';
  include \$configFile;
  \$parameters['secret_key'] = getenv('MAUTIC_SECRET_KEY');
  file_put_contents(\$configFile, '<?php' . PHP_EOL . '\$parameters = ' . var_export(\$parameters, true) . ';' . PHP_EOL);
  "
fi

log "[mautic_web]: Running migrations..."
su -s /bin/bash "$MAUTIC_WWW_USER" -c "php $MAUTIC_CONSOLE doctrine:migrations:migrate -n"

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
