#!/bin/bash
TARGET_MARKER="/root/.targetonce"
TARGET_VERSION=2

cat <<EOF | sudo tee /etc/apache2/sites-available/wordpress.conf
<VirtualHost *:80>
 ServerName $SERVERNAME
 ServerAlias $SERVERALIAS
 DocumentRoot /srv/www/wordpress
 <Directory /srv/www/wordpress>
  Options FollowSymLinks
  AllowOverride Limit Options FileInfo
  DirectoryIndex index.php
  Require all granted
 </Directory>
 <Directory /srv/www/wordpress/wp-content>
  Options FollowSymLinks
  Require all granted
 </Directory>
</VirtualHost>
EOF
DBPASSWORD=$(< /dev/urandom tr -dc 'A-Za-z0-9' | head -c20)
echo "$DBPASSWORD" > /root/.wp_db_password
chmod 600 /root/.wp_db_password
a2ensite wordpress
a2enmod rewrite
a2dissite 000-default
service apache2 reload
mysql -u root -e " \
 CREATE DATABASE wordpress; \
 CREATE USER wordpress@localhost IDENTIFIED BY '${DBPASSWORD}'; \
 GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, ALTER ON wordpress.* TO wordpress@localhost; \
 FLUSH PRIVILEGES;"
sudo -u www-data cp /srv/www/wordpress/wp-config-sample.php /srv/www/wordpress/wp-config.php
sudo -u www-data sed -i 's/database_name_here/wordpress/' /srv/www/wordpress/wp-config.php
sudo -u www-data sed -i 's/username_here/wordpress/' /srv/www/wordpress/wp-config.php
sudo -u www-data sed -i 's/localhost/127.0.0.1/' /srv/www/wordpress/wp-config.php
sudo -u www-data sed -i "s/password_here/${DBPASSWORD}/" /srv/www/wordpress/wp-config.php
WP_KEYS=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
sed -i '/AUTH_KEY/d' /srv/www/wordpress/wp-config.php
sed -i '/SECURE_AUTH_KEY/d' /srv/www/wordpress/wp-config.php
sed -i '/LOGGED_IN_KEY/d' /srv/www/wordpress/wp-config.php
sed -i '/NONCE_KEY/d' /srv/www/wordpress/wp-config.php
sed -i '/AUTH_SALT/d' /srv/www/wordpress/wp-config.php
sed -i '/SECURE_AUTH_SALT/d' /srv/www/wordpress/wp-config.php
sed -i '/LOGGED_IN_SALT/d' /srv/www/wordpress/wp-config.php
sed -i '/NONCE_SALT/d' /srv/www/wordpress/wp-config.php
printf '%s\n' "/<?php/a" "$WP_KEYS" "." w | ed -s /srv/www/wordpress/wp-config.php
curl -4 --max-time 2 http://$SERVERNAME
curl -4 --max-time 2 http://$SERVERALIAS
certbot --apache --agree-tos --email $EMAIL --redirect --expand --non-interactive --apache-server-root /etc/apache2/ --domain $SERVERNAME --domain $SERVERALIAS

echo "$TARGET_VERSION" > "${TARGET_MARKER}"
chattr +i "${TARGET_MARKER}"

echo "wordpress" > "${TARGET_MARKER}.name"

exec "$@"
