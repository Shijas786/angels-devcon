#!/usr/bin/env sh
set -e

# If first arg starts with a `-` or is empty
if [[ "${1#-}" != "${1}" ]] || [[ -z "${1}" ]]; then
  set -- php-fpm "$@"
fi

# Configure app url
url=$(echo "$APP_URL" | sed -n 's~https*://[^/]\+/\(.*\)~\1~p')
url=${url%/}
if [[ -n "${url}" ]]; then
  echo "Url prefix: '${url}'"
  sed -i "s~location /~rewrite ^/${url}(/.*)?$ /\$1;\n    location /~" /etc/nginx/nginx.conf
fi

# If DATABASE_URL or MYSQL_URL is provided, parse it
DB_URL=${MYSQL_URL:-${DATABASE_URL:-}}
if [[ -n "$DB_URL" ]]; then
  # Format: mysql://user:pass@host:port/dbname?options
  URL_NO_SCHEMA=${DB_URL#*://}
  URL_CREDS=${URL_NO_SCHEMA%%@*}
  URL_HOST_PORT_DB=${URL_NO_SCHEMA#*@}
  
  export MYSQL_USER=${URL_CREDS%%:*}
  export MYSQL_PASSWORD=${URL_CREDS#*:}
  
  URL_HOST_PORT=${URL_HOST_PORT_DB%%/*}
  DB_AND_QUERY=${URL_HOST_PORT_DB#*/}
  export MYSQL_DATABASE=${DB_AND_QUERY%%\?*}
  
  export MYSQL_HOST=${URL_HOST_PORT%%:*}
  if [[ "$URL_HOST_PORT" == *":"* ]]; then
    export MYSQL_PORT=${URL_HOST_PORT#*:}
  fi
fi

# Database mapping for Railway with comprehensive fallbacks
export MYSQL_HOST=${MYSQL_HOST:-${MYSQLHOST:-${DB_HOST:-localhost}}}
export MYSQL_DATABASE=${MYSQL_DATABASE:-${MYSQLDATABASE:-${DB_DATABASE:-engelsystem}}}
export MYSQL_USER=${MYSQL_USER:-${MYSQLUSER:-${DB_USERNAME:-${DB_USER:-root}}}}
export MYSQL_PASSWORD=${MYSQL_PASSWORD:-${MYSQLPASSWORD:-${DB_PASSWORD:-}}}
export MYSQL_PORT=${MYSQL_PORT:-${MYSQLPORT:-${DB_PORT:-3306}}}

 

# Generate config.php to guarantee database credentials and port are correctly mapped
echo "Generating config/config.php with database credentials..."
php -r "
\$config = [
    'database' => [
        'driver'   => 'mysql',
        'host'     => getenv('MYSQL_HOST'),
        'port'     => getenv('MYSQL_PORT'),
        'database' => getenv('MYSQL_DATABASE'),
        'username' => getenv('MYSQL_USER'),
        'password' => getenv('MYSQL_PASSWORD'),
    ]
];
file_put_contents('/var/www/config/config.php', '<?php return ' . var_export(\$config, true) . ';');
"

function get_name() {
    echo "$1" | cut -d: -f1
}

# Create users for user mapping from RUN_USER=[uid]:[gid]
if [[ -n "${RUN_USER}" ]]; then
  echo "Setting user to $RUN_USER"

  gid=${RUN_USER#*:}
  grp=$(getent group $gid || true)
  if [[ -z "$grp" ]]; then # Group not present
    addgroup -g $gid php
    grp=$(getent group $gid)
  fi
  group=$(get_name "$grp")

  uid=${RUN_USER%:*}
  usr=$(getent passwd $uid || true)
  if [[ -z "$usr" ]]; then # User not present
    adduser -D -h "$PWD" -u $uid -G "$group" php
    usr=$(getent passwd $uid)
  fi
  user=$(get_name "$usr")

  echo -e "user = $user\ngroup = $group" >> /usr/local/etc/php-fpm.d/zz-docker.conf

  echo "Running as $user:$group"
fi

echo "Running database migrations..."
php bin/migrate

# Ensure admin user exists with a known password
ADMIN_PASS=${SETUP_ADMIN_PASSWORD:-asdfasdf}
echo "Ensuring admin user exists..."
php -r "
require_once '/var/www/includes/application.php';
\$db = app()->get('db')->connection();
\$admin = \$db->table('users')->where('name', 'admin')->first();
\$hash = password_hash('${ADMIN_PASS}', PASSWORD_DEFAULT);
if (!\$admin) {
    \$uid = \$db->table('users')->insertGetId([
        'name'       => 'admin',
        'email'      => 'admin@localhost',
        'password'   => \$hash,
        'api_key'    => bin2hex(random_bytes(16)),
        'created_at' => date('Y-m-d H:i:s'),
    ]);
    foreach (['users_contact', 'users_personal_data', 'users_state'] as \$t) {
        \$db->table(\$t)->insertOrIgnore(['user_id' => \$uid]);
    }
    \$db->table('users_settings')->insertOrIgnore(['user_id' => \$uid, 'language' => 'en_US', 'theme' => 22]);
    // Give admin all privileges (group_id = 2 = Admin)
    \$db->table('users_groups')->insertOrIgnore(['user_id' => \$uid, 'group_id' => 2]);
    echo 'Admin user created with password.' . PHP_EOL;
} else {
    \$db->table('users')->where('name', 'admin')->update(['password' => \$hash]);
    // Ensure admin group
    \$db->table('users_groups')->insertOrIgnore(['user_id' => \$admin->id, 'group_id' => 2]);
    echo 'Admin password reset.' . PHP_EOL;
}
" 2>&1 || echo "Admin setup script encountered an error, continuing..."


# Set ETH DevCon Mumbai branding and Engelsystem Pro theme
echo "Setting ETH DevCon Mumbai branding..."
php -r "
require_once '/var/www/includes/application.php';
\$db = app()->get('db')->connection();
\$db->table('event_config')->updateOrInsert(
    ['name' => 'app_name'],
    ['name' => 'app_name', 'value' => json_encode('ETH DevCon Mumbai')]
);
\$db->table('event_config')->updateOrInsert(
    ['name' => 'name'],
    ['name' => 'name', 'value' => json_encode('ETH DevCon Mumbai 2026')]
);
\$db->table('event_config')->updateOrInsert(
    ['name' => 'theme'],
    ['name' => 'theme', 'value' => json_encode(22)]
);
// Add a welcome news post if none exist
if (\$db->table('news')->count() <= 2) {
    \$db->table('news')->insertOrIgnore([
        'title' => 'Welcome to ETH DevCon Mumbai 2026!',
        'text' => 'We are excited to host you in Mumbai! Check out the shifts and join us as an angel.',
        'user_id' => 1,
        'created_at' => date('Y-m-d H:i:s'),
        'updated_at' => date('Y-m-d H:i:s')
    ]);
}
echo 'ETH DevCon Mumbai branding set.' . PHP_EOL;
" 2>&1 || echo "Branding setup encountered an error, continuing..."

# Seed shift types + shifts for testing
echo "Creating sample shifts for DevCon..."
php -r "
require_once '/var/www/includes/application.php';
\$db = app()->get('db')->connection();

// Only seed if no shifts exist yet
if (\$db->table('shifts')->count() == 0) {
    // Get admin user ID
    \$admin = \$db->table('users')->where('name', 'admin')->first();
    \$adminId = \$admin ? \$admin->id : 1;

    // Create shift types if not existing
    \$stGeneral = \$db->table('shift_types')->where('name', 'General')->first();
    if (!\$stGeneral) {
        \$stGeneralId = \$db->table('shift_types')->insertGetId(['name' => 'General', 'description' => 'General volunteer shift']);
    } else { \$stGeneralId = \$stGeneral->id; }

    \$stTech = \$db->table('shift_types')->where('name', 'Technical')->first();
    if (!\$stTech) {
        \$stTechId = \$db->table('shift_types')->insertGetId(['name' => 'Technical', 'description' => 'Technical and AV support shift']);
    } else { \$stTechId = \$stTech->id; }

    // Get location IDs
    \$locReg = \$db->table('locations')->where('name', 'Registration Area')->first();
    \$locStage = \$db->table('locations')->where('name', 'Main Stage')->first();
    \$locWorkshop = \$db->table('locations')->where('name', 'Workshop Hall A')->first();
    \$locLounge = \$db->table('locations')->where('name', 'Community Lounge')->first();

    \$locRegId = \$locReg ? \$locReg->id : null;
    \$locStageId = \$locStage ? \$locStage->id : null;
    \$locWorkshopId = \$locWorkshop ? \$locWorkshop->id : null;
    \$locLoungeId = \$locLounge ? \$locLounge->id : null;

    // Get angel type IDs
    \$atReg = \$db->table('angel_types')->where('name', 'Registration Desk')->first();
    \$atStage = \$db->table('angel_types')->where('name', 'Stage Tech')->first();
    \$atWorkshop = \$db->table('angel_types')->where('name', 'Workshop Support')->first();
    \$atInfo = \$db->table('angel_types')->where('name', 'Info Desk')->first();

    \$now = date('Y-m-d H:i:s');

    // Day 1 shifts (Nov 3)
    \$shifts = [
        ['title'=>'Morning Registration','start'=>'2026-11-03 08:00:00','end'=>'2026-11-03 12:00:00','shift_type_id'=>\$stGeneralId,'location_id'=>\$locRegId,'created_by'=>\$adminId,'created_at'=>\$now,'updated_at'=>\$now,'description'=>'','url'=>''],
        ['title'=>'Keynote Stage Setup','start'=>'2026-11-03 07:00:00','end'=>'2026-11-03 09:00:00','shift_type_id'=>\$stTechId,'location_id'=>\$locStageId,'created_by'=>\$adminId,'created_at'=>\$now,'updated_at'=>\$now,'description'=>'','url'=>''],
        ['title'=>'Opening Keynote Support','start'=>'2026-11-03 09:00:00','end'=>'2026-11-03 11:00:00','shift_type_id'=>\$stTechId,'location_id'=>\$locStageId,'created_by'=>\$adminId,'created_at'=>\$now,'updated_at'=>\$now,'description'=>'','url'=>''],
        ['title'=>'Afternoon Workshop A','start'=>'2026-11-03 14:00:00','end'=>'2026-11-03 17:00:00','shift_type_id'=>\$stGeneralId,'location_id'=>\$locWorkshopId,'created_by'=>\$adminId,'created_at'=>\$now,'updated_at'=>\$now,'description'=>'','url'=>''],
        ['title'=>'Info Desk Afternoon','start'=>'2026-11-03 12:00:00','end'=>'2026-11-03 18:00:00','shift_type_id'=>\$stGeneralId,'location_id'=>\$locLoungeId,'created_by'=>\$adminId,'created_at'=>\$now,'updated_at'=>\$now,'description'=>'','url'=>''],
        // Day 2 shifts (Nov 4)
        ['title'=>'Day 2 Registration','start'=>'2026-11-04 08:00:00','end'=>'2026-11-04 11:00:00','shift_type_id'=>\$stGeneralId,'location_id'=>\$locRegId,'created_by'=>\$adminId,'created_at'=>\$now,'updated_at'=>\$now,'description'=>'','url'=>''],
        ['title'=>'Talk Track Support','start'=>'2026-11-04 10:00:00','end'=>'2026-11-04 13:00:00','shift_type_id'=>\$stTechId,'location_id'=>\$locStageId,'created_by'=>\$adminId,'created_at'=>\$now,'updated_at'=>\$now,'description'=>'','url'=>''],
        ['title'=>'Afternoon Workshop B','start'=>'2026-11-04 14:00:00','end'=>'2026-11-04 17:00:00','shift_type_id'=>\$stGeneralId,'location_id'=>\$locWorkshopId,'created_by'=>\$adminId,'created_at'=>\$now,'updated_at'=>\$now,'description'=>'','url'=>''],
    ];

    foreach (\$shifts as \$s) {
        if (\$s['location_id']) {
            \$shiftId = \$db->table('shifts')->insertGetId(\$s);
            // Add needed angel types
            if (\$atReg && strpos(\$s['title'],'Registration') !== false) {
                \$db->table('needed_angel_types')->insert(['shift_id'=>\$shiftId,'angel_type_id'=>\$atReg->id,'count'=>3]);
            }
            if (\$atStage && (strpos(\$s['title'],'Stage') !== false || strpos(\$s['title'],'Keynote') !== false || strpos(\$s['title'],'Talk') !== false)) {
                \$db->table('needed_angel_types')->insert(['shift_id'=>\$shiftId,'angel_type_id'=>\$atStage->id,'count'=>2]);
            }
            if (\$atWorkshop && strpos(\$s['title'],'Workshop') !== false) {
                \$db->table('needed_angel_types')->insert(['shift_id'=>\$shiftId,'angel_type_id'=>\$atWorkshop->id,'count'=>4]);
            }
            if (\$atInfo && strpos(\$s['title'],'Info') !== false) {
                \$db->table('needed_angel_types')->insert(['shift_id'=>\$shiftId,'angel_type_id'=>\$atInfo->id,'count'=>2]);
            }
        }
    }
    echo 'Created ' . count(\$shifts) . ' sample shifts.' . PHP_EOL;
} else {
    echo 'Shifts already exist, skipping seed.' . PHP_EOL;
}
" 2>&1 || echo "Shift seeding encountered an error, continuing..."

# Configure port
PORT=${PORT:-80}
echo "Configuring Nginx to listen on port: ${PORT}"
# Use a more compatible sed for BusyBox/Alpine to replace the port
# We look for 'listen' followed by whitespace and '80;'
sed -i "s/listen[[:space:]]\+80;/listen ${PORT};/" /etc/nginx/nginx.conf

echo "Validating Nginx configuration..."
nginx -t

echo "Starting PHP-FPM in background..."
php-fpm -D || php-fpm &

echo "Starting Nginx in foreground..."
exec nginx -g 'daemon off;'
