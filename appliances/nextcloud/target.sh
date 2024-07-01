#!/bin/bash
TARGET_MARKER="/root/.targetonce"
TARGET_VERSION=2

php_ini=$(cat <<EOF
upload_max_filesize = 64M 
post_max_size = 96M 
memory_limit = 512M 
max_execution_time = 600
max_input_vars = 3000 
max_input_time = 1000

opcache.enable=1
opcache.enable_cli=1
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=10000
opcache.memory_consumption=128
opcache.save_comments=1
opcache.revalidate_freq=60

redis.session.locking_enabled=1
redis.session.lock_retries=-1
redis.session.lock_wait_time=10000

EOF
)

www_conf=$(cat <<EOF
pm.max_children = 64
pm.start_servers = 16
pm.min_spare_servers = 16
pm.max_spare_servers = 32
EOF
)

php_apache_config=$(cat <<EOF
<Directory /var/www/nextcloud>
  Options Indexes FollowSymLinks
  AllowOverride All
  Require all granted
</Directory>

<FilesMatch ".php$"> 
  SetHandler "proxy:unix:/var/run/php/php8.1-fpm.sock|fcgi://localhost/"          
</FilesMatch>
EOF
)

php_code=$(cat <<EOF
  'filelocking.enabled' => 'true',
  'memcache.locking' => '\OC\Memcache\Redis',
  'redis' => [
       'host'     => '/var/run/redis/redis.sock',
       'port'     => 0,
       'dbindex'  => 0,
       'password' => '',
       'timeout'  => 1.5,
  ],
  'htaccess.RewriteBase' => '/',
EOF
)

redis_vars=$(cat <<EOF
redis.session.locking_enabled=1
redis.session.lock_retries=-1
redis.session.lock_wait_time=10000
EOF
)


DBPASSWORD=$(< /dev/urandom tr -dc 'A-Za-z0-9' | head -c20)
echo "$DBPASSWORD" > /root/.nextcloud_db_password
chmod 600 /root/.nextcloud_db_password

mysql -u root -e "
  CREATE USER 'nextcloud'@'localhost' IDENTIFIED BY '$DBPASSWORD';
  CREATE DATABASE IF NOT EXISTS nextcloud CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
  GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'localhost';
  FLUSH PRIVILEGES;"

(cd /var/www/nextcloud &&
  sudo -u www-data php occ maintenance:install --database "mysql" --database-name "nextcloud"  --database-user "nextcloud" --database-pass "$DBPASSWORD" --admin-user "$USERNAME" --admin-pass "$UPASSWORD")

sed -i "/\ \ \ \ 0 => 'localhost',/a \ \ \ \ 1 => '$SERVERNAME'," /var/www/nextcloud/config/config.php
sed -i "/\ \ ),/a \ \ 'memcache.local' => '\\\OC\\\Memcache\\\APCu'," /var/www/nextcloud/config/config.php
sed -i -e '/^[[:space:]]*#/d' -e 's|/var/www/html|/var/www/nextcloud|g' /etc/apache2/sites-enabled/000-default.conf
a2dismod php8.1
a2dismod mpm_prefork
a2enmod mpm_event proxy_fcgi setenvif
a2enconf php8.1-fpm
echo "$php_ini" >> /etc/php/8.1/fpm/php.ini
echo "$www_conf" >> /etc/php/8.1/fpm/pool.d/www.conf
awk -v var="$php_apache_config" '/\/var\/www\/nextcloud/ { print; print var; next }1' /etc/apache2/sites-enabled/000-default.conf > /root/temp.temp && mv /root/temp.temp /etc/apache2/sites-enabled/000-default.conf
mkdir -p /var/run/redis
systemctl start redis-server
systemctl enable redis-server
sed -i "/port 6379/c\port 0\nunixsocket /var/run/redis/redis.sock\nunixsocketperm 770" /etc/redis/redis.conf
systemctl restart redis-server

usermod -a -G redis www-data

awk -v phpcode="$php_code" '/\),/ { print; print phpcode; next }1' /var/www/nextcloud/config/config.php > /root/temp.temp && mv /root/temp.temp /var/www/nextcloud/config/config.php

sed -i "s/'dbhost' => 'localhost',/'dbhost' => '127.0.0.1',/" /var/www/nextcloud/config/config.php
chown www-data:www-data /var/www/nextcloud/config/config.php

sudo -u www-data php --define apc.enable_cli=1 /var/www/nextcloud/occ maintenance:update:htaccess
mkdir -p /var/run/php

systemctl restart php8.1-fpm
systemctl restart apache2

certbot --apache --agree-tos --email $EMAIL --redirect --expand --non-interactive --apache-server-root /etc/apache2/ --domain $SERVERNAME

echo "$TARGET_VERSION" > "${TARGET_MARKER}"
chattr +i "${TARGET_MARKER}"

echo "nextcloud" > "${TARGET_MARKER}.name"

exec "$@"
