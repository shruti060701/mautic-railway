#!/bin/bash
# Overrides the base image's own /startup/wait_for_mautic_install.sh.
#
# The stock script waits until LOCAL.PHP has both db_driver and site_url
# set. That works when local.php is shared across services (a real
# docker-compose deployment), but our own local.php template (see
# local.php in this repo) pre-populates site_url from a shared env var
# identically on every service's own isolated volume, from the very first
# boot, regardless of whether the database schema actually exists yet.
# Railway doesn't support shared volumes, confirmed via Railway's own
# community help station, so the stock check would pass immediately here
# even on a genuinely fresh, uninstalled database - worker/cron would
# start doing real work before web has actually created the schema, not
# just before local.php "looks" ready.
#
# This checks the real database directly instead: whether the `users`
# table exists, a core Mautic table only created by a real install.

source /startup/logger.sh

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

function wait_for_mautic_install {
  local COUNTER=0
  until is_mautic_schema_installed; do
    log_debug "[${DOCKER_MAUTIC_ROLE}]: Waiting for Mautic's database schema to be installed, current attempt: ${COUNTER}."
    if (( COUNTER % 6 == 0 )); then
      log "[${DOCKER_MAUTIC_ROLE}]: Waiting for Mautic's database schema to be installed, current attempt: ${COUNTER}."
    fi
    COUNTER=$((COUNTER + 1))
    sleep 5
  done
}

log_debug "[${DOCKER_MAUTIC_ROLE}]: Running wait for mautic install (database-based check)..."
wait_for_mautic_install
