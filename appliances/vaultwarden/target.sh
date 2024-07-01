#!/bin/bash
TARGET_MARKER="/root/.targetonce"
TARGET_VERSION=2

vaultwarden_nginx_temp=$(cat <<EOF
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

vaultwarden_nginx=$(cat <<EOF
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
  proxy_pass http://127.0.0.1:8000/;
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

get_token=$(cat <<EOF
#!/usr/bin/expect

set password "$ADMINPASSWORD"

spawn /opt/vaultwarden/vaultwarden hash --preset bitwarden

expect "Password:"
send "\$password\r"
expect "Confirm Password:"
send "\$password\r"
expect eof

set output \$expect_out(buffer)
set tmpfile "/tmp/hash_output.txt"
set fileId [open \$tmpfile "w"]
puts \$fileId \$output
close \$fileId

spawn grep "^ADMIN_TOKEN" \$tmpfile
expect eof

set adminTokenLine \$expect_out(buffer)

set passfile "/root/password"
set fileId [open \$passfile "w"]
puts \$fileId "\$adminTokenLine"
close \$fileId
EOF
)

echo "$get_token" > /root/temp.exp
chmod u+x /root/temp.exp
/root/temp.exp
VAULTHASH=$(cat /root/password)
rm /root/password
rm /root/temp.exp

vaultwarden_env=$(cat <<EOF
DOMAIN=https://$SERVERNAME/
ORG_CREATION_USERS=$ADMINEMAIL
$VAULTHASH
SIGNUPS_ALLOWED=true
USE_SMTP=false
#USE_SENDMAIL=true
#SMTP_HOST=
#SMTP_FROM=
#SMTP_FROM_NAME=Vaultwarden
#SMTP_PORT=587
#SMTP_SSL=true
#SMTP_EXPLICIT_TLS=false
#SMTP_USERNAME=
#SMTP_PASSWORD=
#SMTP_TIMEOUT=15
EOF
)

vaultwarden_systemd=$(cat <<EOF
[Unit]
Description=Bitwarden Server (Rust Edition)
Documentation=https://github.com/dani-garcia/vaultwarden
After=network.target

[Service]
User=vaultwarden
Group=vaultwarden
EnvironmentFile=/var/lib/vaultwarden/.env
ExecStart=/opt/vaultwarden/vaultwarden
LimitNOFILE=1048576
LimitNPROC=64
PrivateTmp=true
PrivateDevices=true
ProtectHome=true
ProtectSystem=strict
WorkingDirectory=/var/lib/vaultwarden
ReadWriteDirectories=/var/lib/vaultwarden
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF
)

echo "$vaultwarden_env" > /var/lib/vaultwarden/.env
echo "$vaultwarden_systemd" > /etc/systemd/system/vaultwarden.service
systemctl daemon-reload
systemctl enable --now vaultwarden

echo "$vaultwarden_nginx_temp" > /etc/nginx/sites-available/vaultwarden.conf
ln -s /etc/nginx/sites-available/vaultwarden.conf /etc/nginx/sites-enabled/vaultwarden.conf

curl --max-time 2 http://$SERVERNAME
certbot --nginx --agree-tos --email $EMAIL --redirect --expand --non-interactive --nginx-server-root /etc/nginx/ --domain $SERVERNAME
rm /etc/nginx/sites-enabled/vaultwarden.conf
echo "$vaultwarden_nginx" > /etc/nginx/sites-available/vaultwarden.conf
ln -s /etc/nginx/sites-available/vaultwarden.conf /etc/nginx/sites-enabled/vaultwarden.conf
  
systemctl reload nginx


echo "$TARGET_VERSION" > "${TARGET_MARKER}"
chattr +i "${TARGET_MARKER}"

echo "vaultwarden" > "${TARGET_MARKER}.name"

exec "$@"
