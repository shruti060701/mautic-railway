# Pinned to a specific numbered version rather than a floating `latest`
# tag - confirmed via Docker Hub's tags API that 7.1.3-apache matches
# latest's digest exactly at authoring time. The Railway reference
# template (Shinyduo/mautic-railway) uses `mautic/mautic:latest`
# unpinned, and separately bakes DB credentials and the admin password in
# as build-time ARGs, which get embedded in image layers and require a
# full rebuild to rotate - both avoided here.
FROM mautic/mautic:7.1.3-apache

# Overrides the base image's own /templates/local.php: adds site_url and
# secret_key (sourced from shared env vars) on top of the stock db_*
# fields, so every service (web/worker/cron) generates identical config
# on its own isolated volume - Railway doesn't support sharing one volume
# across services, confirmed via Railway's own community help station.
COPY local.php /templates/local.php

# Overrides the base image's own /entrypoint_mautic_web.sh: always calls
# mautic:install (safe due to its own built-in idempotency check) instead
# of skipping it, since our local.php template above makes the stock
# script's "already installed" check pass immediately regardless of real
# install state. Worker and cron keep the base image's own unmodified
# entrypoint scripts, which work correctly once local.php is populated.
COPY entrypoint_mautic_web.sh /entrypoint_mautic_web.sh
RUN chmod +x /entrypoint_mautic_web.sh

# Overrides /startup/check_volumes_exist_ownership.sh: the stock version
# only checks that six specific directories already exist and hard-fails
# if not, assuming a real docker-compose deploy gave each its own
# auto-created volume. Railway only supports one volume per service, so
# this creates the missing ones instead of failing, confirmed necessary
# via a real crash-loop during testing (config/var/logs/media subdirs
# don't exist in the base image and nothing else creates them).
COPY check_volumes_exist_ownership.sh /startup/check_volumes_exist_ownership.sh
RUN chmod +x /startup/check_volumes_exist_ownership.sh

EXPOSE 80
