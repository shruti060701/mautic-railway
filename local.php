<?php
// Custom replacement for the base image's own /templates/local.php.
// Adds secret_key on top of the stock db_* fields, sourced from a shared
// env var every service (web/worker/cron) receives, so all three
// services can decrypt the same data without a shared volume (Railway
// doesn't support attaching one volume to multiple services, confirmed
// via Railway's own community help station).
//
// Deliberately does NOT set site_url here, unlike an earlier version of
// this file. Mautic's own mautic:install command checks local.php's
// site_url field directly (Install/InstallService.php's
// checkIfInstalled()) to decide whether to skip installing - pre-setting
// it here made every service look "already installed" from the moment
// its own local.php is created, even on a genuinely fresh database,
// confirmed via a real deploy where migrations then failed against
// tables that were never created. Real install state is checked against
// the database directly instead (see wait_for_mautic_install.sh and
// entrypoint_mautic_web.sh), decoupled entirely from this file.
$parameters = array(
	'db_driver' => 'pdo_mysql',
	'db_host' => getenv('MAUTIC_DB_HOST'),
	'db_port' => getenv('MAUTIC_DB_PORT'),
	'db_name' => getenv('MAUTIC_DB_DATABASE'),
	'db_user' => getenv('MAUTIC_DB_USER'),
	'db_password' => getenv('MAUTIC_DB_PASSWORD'),
	'db_table_prefix' => null,
	'db_backup_tables' => 1,
	'db_backup_prefix' => 'bak_',
	'secret_key' => getenv('MAUTIC_SECRET_KEY'),
);
