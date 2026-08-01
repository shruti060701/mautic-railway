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

log "[mautic_web]: Running mautic:install (safe to run on every boot)."
# mautic:install has its own built-in idempotency check (checkIfInstalled(),
# confirmed via Mautic's real InstallCommand.php source) - it queries the
# actual database and no-ops with "Mautic already installed" if the schema
# already exists, rather than re-running or erroring. That's what makes it
# safe to call unconditionally on every deploy/restart, not just first boot.
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

log "[mautic_web]: Running migrations..."
su -s /bin/bash "$MAUTIC_WWW_USER" -c "php $MAUTIC_CONSOLE doctrine:migrations:migrate -n"

if [ "${FLAVOUR}" = "fpm" ]; then
  php-fpm
elif [ "${FLAVOUR}" = "apache" ]; then
  apache2-foreground
else
  log "[mautic_web]: FLAVOUR variable is not set correctly, exiting."
  exit 1
fi
