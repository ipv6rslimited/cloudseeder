#!/bin/bash
TARGET_MARKER="/root/.targetonce"
TARGET_VERSION=1

yacy_nginx_temp=$(cat <<EOF
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

yacy_nginx=$(cat <<EOF
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
  proxy_pass http://127.0.0.1:8090/;
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

yacy_service=$(cat <<'EOF'
[Unit]
Description=YaCy server
Documentation=https://yacy.net

[Service]
User=yacy
Group=yacy
Type=simple
Restart=on-failure

WorkingDirectory=/opt/yacy_search_server
ExecStart=/opt/yacy_search_server/startYACY.sh -f

SyslogIdentifier=yacy
StandardOutput=append:/var/log/yacy/yacy.log
StandardError=append:/var/log/yacy/yacy.log

[Install]
WantedBy=multi-user.target
EOF
)  

mkdir -p /var/log/yacy/
chown -R yacy:yacy /var/log/yacy/
echo "$yacy_service" > /etc/systemd/system/yacy.service
systemctl daemon-reload
systemctl enable --now yacy

echo "$yacy_nginx_temp" > /etc/nginx/sites-available/yacy.conf
ln -s /etc/nginx/sites-available/yacy.conf /etc/nginx/sites-enabled/yacy.conf

curl --max-time 2 http://$SERVERNAME
certbot --nginx --agree-tos --email $EMAIL --redirect --expand --non-interactive --nginx-server-root /etc/nginx/ --domain $SERVERNAME
rm /etc/nginx/sites-enabled/yacy.conf
echo "$yacy_nginx" > /etc/nginx/sites-available/yacy.conf
ln -s /etc/nginx/sites-available/yacy.conf /etc/nginx/sites-enabled/yacy.conf
  
systemctl reload nginx

echo "$TARGET_VERSION" > "${TARGET_MARKER}"
chattr +i "${TARGET_MARKER}"

echo "yacy" > "${TARGET_MARKER}.name"

exec "$@"
