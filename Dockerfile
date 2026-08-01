# Pinned to a specific numbered version rather than a floating `latest`
# tag - confirmed via Docker Hub's tags API that 7.1.3-apache matches
# latest's digest exactly at authoring time. The Railway reference
# template (Shinyduo/mautic-railway) uses `mautic/mautic:latest`
# unpinned, and separately bakes DB credentials and the admin password in
# as build-time ARGs, which get embedded in image layers and require a
# full rebuild to rotate - both avoided here.
FROM mautic/mautic:7.1.3-apache

# Overrides the base image's own /templates/local.php: adds secret_key
# (sourced from a shared env var) on top of the stock db_* fields, so
# every service (web/worker/cron) can decrypt the same data without a
# shared volume (Railway doesn't support sharing one volume across
# services, confirmed via Railway's own community help station).
# Deliberately does NOT set site_url, see local.php for why.
COPY local.php /templates/local.php

# Overrides the base image's own /entrypoint_mautic_web.sh: checks the
# real database directly to decide whether to run mautic:install, instead
# of relying on Mautic's own local.php-based check, which our regenerate
# -on-every-boot local.php would otherwise defeat every time. Worker and
# cron keep the base image's own unmodified entrypoint scripts.
COPY entrypoint_mautic_web.sh /entrypoint_mautic_web.sh
RUN chmod +x /entrypoint_mautic_web.sh

# New top-level ENTRYPOINT (replacing the base image's own /entrypoint.sh
# directly): symlinks web's config and media directories into one real
# Railway Volume before handing off to the original entrypoint chain, see
# docker-entrypoint-wrapper.sh for why both need to persist.
COPY docker-entrypoint-wrapper.sh /docker-entrypoint-wrapper.sh
RUN chmod +x /docker-entrypoint-wrapper.sh

# Overrides /startup/check_volumes_exist_ownership.sh: the stock version
# only checks that six specific directories already exist and hard-fails
# if not, assuming a real docker-compose deploy gave each its own
# auto-created volume. Railway only supports one volume per service, so
# this creates the missing ones instead of failing, confirmed necessary
# via a real crash-loop during testing (config/var/logs/media subdirs
# don't exist in the base image and nothing else creates them).
COPY check_volumes_exist_ownership.sh /startup/check_volumes_exist_ownership.sh
RUN chmod +x /startup/check_volumes_exist_ownership.sh

# Overrides /startup/wait_for_mautic_install.sh: the stock version checks
# local.php's own site_url field, which our template pre-populates on
# every service from boot regardless of real install state (see local.php
# in this repo). This checks the real database instead, used by worker
# and cron (via their own unmodified stock entrypoint scripts, which call
# this same path) and by entrypoint_mautic_web.sh above.
COPY wait_for_mautic_install.sh /startup/wait_for_mautic_install.sh
RUN chmod +x /startup/wait_for_mautic_install.sh

ENTRYPOINT ["/docker-entrypoint-wrapper.sh"]

EXPOSE 80
