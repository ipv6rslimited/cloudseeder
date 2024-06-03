#!/bin/bash
TARGET_MARKER="/root/.targetonce"
TARGET_VERSION=3

rocketchat_nginx_temp=$(cat <<EOF
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

rocketchat_nginx=$(cat <<EOF
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

rocketchat_systemd=$(cat <<EOF
[Unit]
Description=The Rocket.Chat server
After=network.target remote-fs.target nss-lookup.target nginx.service mongod.service

[Service]
WorkingDirectory=/opt/RocketChat/
ExecStart=/usr/bin/node /opt/RocketChat/main.js
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=rocketchat
User=rocketchat
Group=rocketchat
Environment=MONGO_URL=mongodb://127.0.0.1:27017/rocketchat?replicaSet=rs01 MONGO_OPLOG_URL=mongodb://127.0.0.1:27017/local?replicaSet=rs01 ROOT_URL=http://127.0.0.1:3000/ PORT=3000
Restart=on-failure

SyslogIdentifier=rocketchat
StandardOutput=append:/var/log/rocketchat/rocketchat.log
StandardError=append:/var/log/rocketchat/rocketchat.log

[Install]
WantedBy=multi-user.target
EOF
)

(cd /opt/RocketChat/programs/server && npm install)
(cd /opt/RocketChat/programs/server && node npm-rebuild.js && npm rebuild bcrypt --build-from-source)

mkdir -p /var/log/rocketchat
chown -R rocketchat:rocketchat /var/log/rocketchat

systemctl enable --now mongod
sleep 2
mongosh --host 127.0.0.1:27017 --eval "rs.initiate({_id: 'rs01', members: [{_id: 0, host: '127.0.0.1:27017'}]})"

echo "$rocketchat_systemd" > /etc/systemd/system/rocketchat.service

echo "$rocketchat_nginx_temp" > /etc/nginx/sites-available/rocketchat.conf
ln -s /etc/nginx/sites-available/rocketchat.conf /etc/nginx/sites-enabled/rocketchat.conf

curl --max-time 2 http://$SERVERNAME
certbot --nginx --agree-tos --email $EMAIL --redirect --expand --non-interactive --nginx-server-root /etc/nginx/ --domain $SERVERNAME
rm /etc/nginx/sites-enabled/rocketchat.conf
echo "$rocketchat_nginx" > /etc/nginx/sites-available/rocketchat.conf
ln -s /etc/nginx/sites-available/rocketchat.conf /etc/nginx/sites-enabled/rocketchat.conf
  
systemctl reload nginx
systemctl daemon-reload
systemctl enable --now rocketchat

echo "$TARGET_VERSION" > "${TARGET_MARKER}"
chattr +i "${TARGET_MARKER}"

echo "rocketchat" > "${TARGET_MARKER}.name"

exec "$@"
