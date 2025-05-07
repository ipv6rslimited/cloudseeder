#!/bin/bash
TARGET_MARKER="/root/.targetonce"
TARGET_VERSION=4

misskey_nginx_temp=$(cat <<EOF
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

misskey_nginx=$(cat <<EOF
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

  location / {
  proxy_pass http://127.0.0.1:3000/;
  proxy_set_header Host \$host;
  proxy_set_header X-Real-IP \$remote_addr;
  proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto \$scheme;
  proxy_set_header X-Forwarded-Protocol \$scheme;
  proxy_set_header X-Forwarded-Host \$http_host;
  proxy_buffering off;
  }
}
EOF
)


DBPASSWORD=$(< /dev/urandom tr -dc 'A-Za-z0-9' | head -c20)
echo "$DBPASSWORD" > /root/.misskey_db_password
chmod 600 /root/.misskey_db_password

misskey_systemd=$(cat <<EOF
[Unit]
Description=Misskey daemon

[Service]
Type=simple
User=root
ExecStart=/usr/bin/npm start
WorkingDirectory=/opt/misskey
Environment="NODE_ENV=production"
TimeoutSec=60
StandardOutput=journal
StandardError=journal
SyslogIdentifier=misskey
Restart=always

[Install]
WantedBy=multi-user.target
EOF
)

misskey_config=$(cat <<EOF
url: https://$SERVERNAME
port: 3000
db:
  host: 127.0.0.1
  port: 5432
  db  : mk
  user: misskey
  pass: $DBPASSWORD
redis:
  host: 127.0.0.1
  port: 6379
id: 'aidx'
EOF
)

redis_systemd_service=$(cat <<EOF
[Unit]
Description=Advanced key-value store
After=network.target
Documentation=http://redis.io/documentation, man:redis-server(1)

[Service]
Type=notify
ExecStart=/usr/bin/redis-server /etc/redis/redis.conf
ExecStop=/bin/kill -s TERM \$MAINPID
PIDFile=/run/redis/redis-server.pid
TimeoutStopSec=0
Restart=always
User=redis
Group=redis
RuntimeDirectory=redis
RuntimeDirectoryMode=2755

UMask=007
PrivateTmp=yes
LimitNOFILE=65535
ProtectHome=yes
ReadOnlyDirectories=/
ReadWriteDirectories=-/var/lib/redis
ReadWriteDirectories=-/var/log/redis
ReadWriteDirectories=-/run/redis

[Install]
WantedBy=multi-user.target
Alias=redis.service
EOF
)


sudo -u postgres psql -c "CREATE DATABASE mk WITH ENCODING = 'UTF8';"
sudo -u postgres psql -c "CREATE USER misskey WITH ENCRYPTED PASSWORD '$DBPASSWORD';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE mk TO misskey;"
sudo -u postgres psql -d mk -c "GRANT ALL ON SCHEMA public TO misskey;"

echo "$misskey_config" > /opt/misskey/.config/default.yml
(cd /opt/misskey && pnpm run init)
echo "$misskey_systemd" > /etc/systemd/system/misskey.service
echo "$redis_systemd_service" > /etc/systemd/system/redis-server.service
systemctl daemon-reload
systemctl enable --now redis-server
systemctl enable --now misskey

echo "$misskey_nginx_temp" > /etc/nginx/sites-available/misskey.conf
ln -s /etc/nginx/sites-available/misskey.conf /etc/nginx/sites-enabled/misskey.conf

curl --max-time 2 http://$SERVERNAME
certbot --nginx --agree-tos --email $EMAIL --redirect --expand --non-interactive --nginx-server-root /etc/nginx/ --domain $SERVERNAME --deploy-hook "systemctl reload nginx"
rm /etc/nginx/sites-enabled/misskey.conf
echo "$misskey_nginx" > /etc/nginx/sites-available/misskey.conf
ln -s /etc/nginx/sites-available/misskey.conf /etc/nginx/sites-enabled/misskey.conf

systemctl reload nginx

echo "$TARGET_VERSION" > "${TARGET_MARKER}"
chattr +i "${TARGET_MARKER}"

echo "misskey" > "${TARGET_MARKER}.name"

exec "$@"
