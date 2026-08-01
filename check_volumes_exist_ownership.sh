#!/bin/bash
# Overrides the base image's own /startup/check_volumes_exist_ownership.sh.
#
# The stock script only checks that MAUTIC_VOLUMES directories already
# exist and exits 1 if not - it never creates them. That's fine in a real
# docker-compose deployment, where each of the six expected paths
# (config, var, var/logs, docroot/media, docroot/media/files,
# docroot/media/images) gets its own named volume, and Docker
# auto-creates the mount point directory the first time a volume attaches.
#
# Railway only supports one volume per service. Only docroot/media is a
# real Railway Volume here (user-uploaded files genuinely need to
# persist); the other five paths just need to exist as directories, they
# don't need to survive a redeploy, config is regenerated deterministically
# from env vars on every boot anyway (see local.php in this repo). So this
# creates them instead of failing when they're missing.

source /startup/logger.sh

log_debug "Ensuring all required Mautic directories exist..."
mkdir -p ${MAUTIC_VOLUMES}
chown -R "${MAUTIC_WWW_USER}:${MAUTIC_WWW_GROUP}" ${MAUTIC_VOLUMES}
log_debug "All required Mautic directories exist with correct ownership."
