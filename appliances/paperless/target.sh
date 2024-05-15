#!/bin/bash
TARGET_MARKER="/root/.targetonce"
TARGET_VERSION=3

paperless_consumption_link=$(cat <<'EOF'
#!/bin/bash

SOURCE_DIR="/mnt/consume"
DESTINATION_DIR="/opt/paperless/consume"

mkdir -p "$DESTINATION_DIR"

/bin/mv "$SOURCE_DIR"/* "$DESTINATION_DIR/"

EOF
)

paperless_nginx_temp=$(cat <<EOF
server {
  server_name $SERVERNAME;
  listen 80;
  listen [::]:80;
  root /var/www/html;
  index index.html index.htm index.nginx-debian.html;
  location / {
    try_files $uri $uri/ =404;
  }
}
EOF
)

paperless_nginx=$(cat <<EOF
server {
  if (\$host = $SERVERNAME) {
    return 301 https://\$host\$request_uri;
  }
  listen 80;
  listen [::]:80;
  server_name $SERVERNAME;
  return 301 https://\$host\$request_uri;
}
server {
  listen 443 ssl http2;
  listen [::]:443 ssl ipv6only=on;
  server_name $SERVERNAME;
  ssl_certificate /etc/letsencrypt/live/$SERVERNAME/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/$SERVERNAME/privkey.pem;
  include /etc/letsencrypt/options-ssl-nginx.conf;
  ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
  add_header Strict-Transport-Security "max-age=31536000" always;
  ssl_trusted_certificate /etc/letsencrypt/live/$SERVERNAME/chain.pem;
  ssl_stapling on;
  ssl_stapling_verify on;

  client_max_body_size 20M;
  location / {
  proxy_http_version 1.1;
  proxy_pass http://127.0.0.1:8000/;
  proxy_set_header Host \$host;
  proxy_set_header X-Real-IP \$remote_addr;
  proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto \$scheme;
  proxy_set_header X-Forwarded-Protocol \$scheme;
  proxy_set_header X-Forwarded-Host \$http_host;
  proxy_set_header Upgrade \$http_upgrade;
  proxy_set_header Connection upgrade;
  proxy_set_header Accept-Encoding gzip;
  proxy_buffering off;
  }
}
EOF
)


DBPASSWORD=$(< /dev/urandom tr -dc 'A-Za-z0-9' | head -c20)
SECRETKEY=$(< /dev/urandom tr -dc 'A-Za-z0-9' | head -c32)

paperless_conf=$(cat <<EOF
PAPERLESS_REDIS=redis://127.0.0.1:6379
PAPERLESS_DBENGINE=postgresql
PAPERLESS_DBHOST=127.0.0.1
PAPERLESS_DBPORT=5432
PAPERLESS_DBNAME=paperless
PAPERLESS_DBUSER=paperless
PAPERLESS_DBPASS=$DBPASSWORD

PAPERLESS_CONSUMPTION_DIR=../consume
PAPERLESS_DATA_DIR=../data
PAPERLESS_TRASH_DIR=../trash
PAPERLESS_MEDIA_ROOT=../media
PAPERLESS_STATICDIR=../static

PAPERLESS_SECRET_KEY=$SECRETKEY
PAPERLESS_URL=https://$SERVERNAME
PAPERLESS_CSRF_TRUSTED_ORIGINS=https://$SERVERNAME
PAPERLESS_ALLOWED_HOSTS=https://$SERVERNAME
PAPERLESS_CORS_ALLOWED_HOSTS=https://$SERVERNAME

PAPERLESS_OCR_LANGUAGE=eng

PAPERLESS_TIME_ZONE=UTC
PAPERLESS_CONSUMER_POLLING=10
PAPERLESS_CONSUMER_IGNORE_PATTERNS=[".DS_STORE/*", "._*", ".stfolder/*", ".stversions/*", ".localized/*", "desktop.ini"]
EOF
)

make_admin=$(cat <<EOF
#!/bin/bash
cd /opt/paperless/src && sudo -Hu paperless python3 manage.py createsuperuser
EOF
)

systemctl enable --now redis-server

sudo -u postgres psql -c "CREATE USER paperless WITH PASSWORD '$DBPASSWORD';"
sudo -u postgres psql -c "CREATE DATABASE paperless;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE paperless TO paperless;"
sudo -u postgres psql -d paperless -c "GRANT ALL ON SCHEMA public TO paperless;"

echo "$paperless_conf" > /opt/paperless/paperless.conf
chown paperless:paperless /opt/paperless/paperless.conf

su - paperless -c "PATH=\"/opt/paperless/.local/bin:$PATH\" && cd /opt/paperless && pip3 install --upgrade pip && pip3 install -r requirements.txt && cd src && python3 manage.py migrate"

sed -i 's\<policy domain="coder" rights="none" pattern="PDF" />\<policy domain="coder" rights="read|write" pattern="PDF" />\' /etc/ImageMagick-6/policy.xml

cp /opt/paperless/scripts/*.service /etc/systemd/system/
sed -i 's/\bcelery\b/\/opt\/paperless\/.local\/bin\/celery/g' /etc/systemd/system/paperless-task-queue.service
sed -i 's/\bcelery\b/\/opt\/paperless\/.local\/bin\/celery/g' /etc/systemd/system/paperless-scheduler.service
systemctl daemon-reload
systemctl enable --now paperless-consumer
systemctl enable --now paperless-scheduler
systemctl enable --now paperless-task-queue
systemctl enable --now paperless-webserver

echo "$make_admin" > /root/make_admin.sh
chmod u+x /root/make_admin.sh

echo "$paperless_consumption_link" > /usr/sbin/paperless_consumption_link.sh
chmod u+x /usr/sbin/paperless_consumption_link.sh
(crontab -l 2>/dev/null; echo "* * * * * /usr/sbin/paperless_consumption_link.sh >/var/log/paperless_consumption_link.log 2>&1") | crontab -
systemctl enable --now cron

echo "$paperless_nginx_temp" > /etc/nginx/sites-available/paperless.conf
ln -s /etc/nginx/sites-available/paperless.conf /etc/nginx/sites-enabled/paperless.conf

curl --max-time 2 http://$SERVERNAME
certbot --nginx --agree-tos --email $EMAIL --redirect --expand --non-interactive --nginx-server-root /etc/nginx/ --domain $SERVERNAME
rm /etc/nginx/sites-enabled/paperless.conf
echo "$paperless_nginx" > /etc/nginx/sites-available/paperless.conf
ln -s /etc/nginx/sites-available/paperless.conf /etc/nginx/sites-enabled/paperless.conf
  
systemctl reload nginx



echo "$TARGET_VERSION" > "${TARGET_MARKER}"
chattr +i "${TARGET_MARKER}"

echo "paperless" > "${TARGET_MARKER}.name"

exec "$@"
