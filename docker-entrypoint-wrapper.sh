#!/bin/bash
set -e
# New top-level ENTRYPOINT, wrapping the base image's own /entrypoint.sh.
#
# Railway only supports one volume per service, confirmed via Railway's
# own community help station. The mautic_web role needs two real
# directories to persist across restarts: config (so a completed
# install's real local.php, with its real site_url and secret_key,
# survives instead of being regenerated from the fresh-install template
# on every single restart, which would otherwise leave the running app
# serving requests with no site_url configured between deploys) and
# docroot/media (user-uploaded files). Both are symlinked into
# subdirectories of the one real Railway Volume mounted at
# /mnt/mautic-persist instead.
#
# mautic_worker and mautic_cron don't get this treatment: their own
# config is intentionally regenerated fresh from the template (with
# secret_key from the shared env var, no site_url) on every boot, and
# they don't handle uploads, see local.php and wait_for_mautic_install.sh
# in this repo for why that's correct rather than an oversight.
echo "[wrapper]: DOCKER_MAUTIC_ROLE=${DOCKER_MAUTIC_ROLE}"
echo "[wrapper]: /mnt/mautic-persist exists? $([ -d /mnt/mautic-persist ] && echo yes || echo no)"
ls -la /mnt/ 2>&1 || echo "[wrapper]: /mnt does not exist at all"

if [ "$DOCKER_MAUTIC_ROLE" = "mautic_web" ]; then
  echo "[wrapper]: setting up persistent config/media symlinks"
  mkdir -p /mnt/mautic-persist/config /mnt/mautic-persist/media
  rm -rf /var/www/html/config /var/www/html/docroot/media
  ln -s /mnt/mautic-persist/config /var/www/html/config
  ln -s /mnt/mautic-persist/media /var/www/html/docroot/media
  echo "[wrapper]: config symlink: $(readlink -f /var/www/html/config)"
  echo "[wrapper]: config contents: $(ls -la /mnt/mautic-persist/config 2>&1)"
fi

exec /entrypoint.sh "$@"
