#!/bin/bash
TARGET_MARKER="/root/.targetonce"
TARGET_VERSION=1

DBPASSWORD=$(< /dev/urandom tr -dc 'A-Za-z0-9' | head -c20)

pixelfed_nginx_temp=$(cat <<EOF
server {
  server_name $SERVERNAME;
  listen 80;
  listen [::]:80;
  root /var/www/html/public;
  index index.html index.htm index.nginx-debian.html;
  location / {
    try_files $uri $uri/ =404;
  }
}
EOF
)

pixelfed_nginx=$(cat <<EOF
server {
  add_header X-Frame-Options "SAMEORIGIN";
  add_header X-XSS-Protection "1; mode=block";
  add_header X-Content-Type-Options "nosniff";

  root /var/www/html/public;

  index index.html index.htm index.php;

  server_name $SERVERNAME;

  location / {
    try_files \$uri \$uri/ /index.php?\$query_string;
  }

  location = /favicon.ico { access_log off; log_not_found off; }
  location = /robots.txt  { access_log off; log_not_found off; }

  # pass PHP scripts to FastCGI server
  #
  location ~ \.php\$ {
    include snippets/fastcgi-php.conf;
    # With php-fpm (or other unix sockets):
    fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
  }
  listen [::]:443 ssl ipv6only=on; # managed by Certbot
  listen 443 ssl; # managed by Certbot
  ssl_certificate /etc/letsencrypt/live/$SERVERNAME/fullchain.pem; # managed by Certbot
  ssl_certificate_key /etc/letsencrypt/live/$SERVERNAME/privkey.pem; # managed by Certbot
  include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
  ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot
}


server {
  if (\$host = $SERVERNAME) {
    return 301 https://\$host\$request_uri;
  } # managed by Certbot


  listen 80;
  listen [::]:80;

  server_name $SERVERNAME;
  return 404; # managed by Certbot
}
EOF
)

env_file=$(cat <<EOF
APP_NAME="Pixelfed"
APP_ENV="production"
APP_KEY=
APP_DEBUG="false"
CUSTOM_EMOJI="true"

# Instance Configuration
OPEN_REGISTRATION="false"
ENFORCE_EMAIL_VERIFICATION="false"
PF_MAX_USERS="1000"
OAUTH_ENABLED="true"
ENABLE_CONFIG_CACHE=false

# Media Configuration
PF_OPTIMIZE_IMAGES="true"
IMAGE_QUALITY="80"
MAX_PHOTO_SIZE="15000"
MAX_CAPTION_LENGTH="500"
MAX_ALBUM_LENGTH="4"

# Instance URL Configuration
APP_URL="https://$SERVERNAME"
APP_DOMAIN="$SERVERNAME"
ADMIN_DOMAIN="$SERVERNAME"
SESSION_DOMAIN="$SERVERNAME"
TRUST_PROXIES="*"

# Database Configuration
DB_CONNECTION="mysql"
DB_HOST="127.0.0.1"
DB_PORT="3306"
DB_DATABASE="pixelfed"
DB_USERNAME="pixelfed"
DB_PASSWORD="$DBPASSWORD"

# Redis Configuration
REDIS_CLIENT="predis"
REDIS_SCHEME="tcp"
REDIS_HOST="127.0.0.1"
REDIS_PASSWORD="null"
REDIS_PORT="6379"

# Laravel Configuration
SESSION_DRIVER="database"
CACHE_DRIVER="redis"
QUEUE_DRIVER="redis"
BROADCAST_DRIVER="log"
LOG_CHANNEL="stack"
HORIZON_PREFIX="horizon-"

# ActivityPub Configuration
ACTIVITY_PUB="true"
AP_REMOTE_FOLLOW="true"
AP_INBOX="true"
AP_OUTBOX="true"
AP_SHAREDINBOX="true"

# Experimental Configuration
EXP_EMC="true"

## Mail Configuration (Post-Installer)
MAIL_DRIVER=log
MAIL_HOST=smtp.mailtrap.io
MAIL_PORT=2525
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null
MAIL_FROM_ADDRESS="pixelfed@example.com"
MAIL_FROM_NAME="Pixelfed"

## S3 Configuration (Post-Installer)
PF_ENABLE_CLOUD=false
FILESYSTEM_CLOUD=s3
#AWS_ACCESS_KEY_ID=
#AWS_SECRET_ACCESS_KEY=
#AWS_DEFAULT_REGION=
#AWS_BUCKET=<BucketName>
#AWS_URL=
#AWS_ENDPOINT=
#AWS_USE_PATH_STYLE_ENDPOINT=false
EOF
)

pixelfed_systemd=$(cat <<EOF
[Unit]
Description=Pixelfed task queueing via Laravel Horizon
After=network.target
Requires=mysql
Requires=php-fpm
Requires=redis
Requires=nginx

[Service]
Type=simple
ExecStart=/usr/bin/php /var/www/html/artisan horizon
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
)

pixelfed_useradd=$(cat <<EOF
#!/usr/bin/expect

set timeout 20
spawn sudo php artisan user:create

expect "Name:"
send "$ADMINNAME\r"

expect "Username:"
send "$ADMINUSERNAME\r"

expect "Email:"
send "$ADMINEMAIL\r"

expect "Password:"
send "$ADMINPASSWORD\r"

expect "Confirm Password:"
send "$ADMINPASSWORD\r"

expect "Make this user an admin? (yes/no)"
send "yes\r"

expect "Manually verify email address? (yes/no)"
send "no\r"

expect "Are you sure you want to create this user? (yes/no)"
send "yes\r"

# Wait for the process to complete
expect eof

# Print output
puts "User creation script completed."

EOF
)


echo "$DBPASSWORD" > /root/.pixelfed_db_password
chmod 600 /root/.pixelfed_db_password
mysql -u root -e "
 create database pixelfed;
 CREATE USER 'pixelfed'@'localhost' IDENTIFIED BY '$DBPASSWORD';
 GRANT ALL PRIVILEGES ON pixelfed.* TO 'pixelfed'@'localhost';
 FLUSH PRIVILEGES;"
systemctl restart mysql

PHP_INI_FILE=/etc/php/8.2/fpm/php.ini 
sed -i '/^max_execution_time/c\max_execution_time = 600' $PHP_INI_FILE || echo 'max_execution_time = 600' >> $PHP_INI_FILE
sed -i '/^post_max_size/c\post_max_size = 8M' $PHP_INI_FILE || echo 'post_max_size = 8M' >> $PHP_INI_FILE
sed -i '/^file_uploads/c\file_uploads = On' $PHP_INI_FILE || echo 'file_uploads = On' >> $PHP_INI_FILE
sed -i '/^upload_max_filesize/c\upload_max_filesize = 6M' $PHP_INI_FILE || echo 'upload_max_filesize = 6M' >> $PHP_INI_FILE
sed -i '/^max_file_uploads/c\max_file_uploads = 20' $PHP_INI_FILE || echo 'max_file_uploads = 20' >> $PHP_INI_FILE


su - pixel -c "cd /var/www/html/ && sudo composer install --no-ansi --no-interaction --optimize-autoloader"

echo "$env_file" > /var/www/html/.env
chown pixel:pixel /var/www/html/.env

su - pixel -c "cd /var/www/html && sudo php artisan key:generate && sudo php artisan storage:link && sudo php artisan migrate --force &&  sudo php artisan import:cities && sudo php artisan horizon:install && sudo php artisan passport:install && sudo php artisan instance:actor && sudo php artisan horizon:publish && sudo php artisan route:cache && sudo php artisan view:cache && sudo php artisan config:cache"

echo "$pixelfed_systemd" > /etc/systemd/system/pixelfed.service
(crontab -l 2>/dev/null; echo "* * * * * /usr/bin/php /usr/share/webapps/pixelfed/artisan schedule:run >> /dev/null 2>&1") | crontab -
systemctl daemon-reload
systemctl enable --now pixelfed
systemctl restart pixelfed.service

echo "$pixelfed_useradd" > /var/www/html/add.exp
chown pixel:pixel /var/www/html/add.exp
chmod u+x /var/www/html/add.exp
cd /var/www/html/ && ./add.exp
#rm /var/www/html/add.exp

echo "$pixelfed_nginx_temp" > /etc/nginx/sites-available/pixelfed.conf
ln -s /etc/nginx/sites-available/pixelfed.conf /etc/nginx/sites-enabled/pixelfed.conf

curl --max-time 2 http://$SERVERNAME
certbot --nginx --agree-tos --email $EMAIL --redirect --expand --non-interactive --nginx-server-root /etc/nginx/ --domain $SERVERNAME
rm /etc/nginx/sites-enabled/pixelfed.conf
echo "$pixelfed_nginx" > /etc/nginx/sites-available/pixelfed.conf
ln -s /etc/nginx/sites-available/pixelfed.conf /etc/nginx/sites-enabled/pixelfed.conf

systemctl reload nginx

curl --max-time 1 "https://$SERVERNAME/i/actor"
chown www-data:www-data /var/www/html/storage/logs/laravel.log

echo "$TARGET_VERSION" > "${TARGET_MARKER}"
chattr +i "${TARGET_MARKER}"

echo "pixelfed" > "${TARGET_MARKER}.name"

exec "$@"
