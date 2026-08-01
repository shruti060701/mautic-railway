<?php
// Custom replacement for the base image's own /templates/local.php.
// Adds site_url and secret_key on top of the stock db_* fields, sourced
// from the same shared env vars every service (web/worker/cron) receives,
// so all three services generate byte-identical config on their own
// isolated Railway volume, with no shared-volume dependency.
//
// Without this, only the web service (the one that runs mautic:install)
// would ever get site_url/secret_key populated - worker and cron have no
// way to see that file since Railway volumes are not shared across
// services, confirmed via Railway's own community help station.
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
	'site_url' => getenv('MAUTIC_URL'),
	'secret_key' => getenv('MAUTIC_SECRET_KEY'),
);
