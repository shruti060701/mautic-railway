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
if [ "$DOCKER_MAUTIC_ROLE" = "mautic_web" ]; then
  echo "[wrapper]: setting up persistent config/media symlinks"
  mkdir -p /mnt/mautic-persist/config /mnt/mautic-persist/media
  rm -rf /var/www/html/config /var/www/html/docroot/media
  ln -s /mnt/mautic-persist/config /var/www/html/config
  ln -s /mnt/mautic-persist/media /var/www/html/docroot/media

  # chown -R on a symlink argument chowns the symlink itself, not what it
  # points to - confirmed via a real deploy where Apache/PHP got
  # "Permission denied" writing to media even though the base image's own
  # check_volumes_exist_ownership.sh (which we override, see that file)
  # ran a chown against these now-symlinked paths. The real target
  # directories need chowning directly, before anything tries to write
  # through the symlinks.
  chown -R www-data:www-data /mnt/mautic-persist/config /mnt/mautic-persist/media
fi

exec /entrypoint.sh "$@"
