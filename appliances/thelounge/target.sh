#!/bin/bash
TARGET_MARKER="/root/.targetonce"
TARGET_VERSION=2


make_account=$(cat <<'EOF'
#!/bin/bash

echo "What's the username?"
read username

sudo -u thelounge thelounge add "$username"

EOF
)

thelounge_systemd=$(cat <<EOF
[Unit]
Description=The Lounge (IRC client)
After=network-online.target
Wants=network-online.target


[Service]
User=thelounge
Group=thelounge
Type=simple
ExecStart=thelounge start
ProtectSystem=yes
ProtectHome=yes
NoNewPrivileges=yes
PrivateTmp=yes

[Install]
WantedBy=multi-user.target
EOF
)

thelounge_nginx_temp=$(cat <<EOF
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

thelounge_nginx=$(cat <<EOF
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
  proxy_pass http://127.0.0.1:9000/; 
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


echo "$thelounge_systemd" > /etc/systemd/system/thelounge.service
systemctl daemon-reload

systemctl enable --now thelounge
systemctl stop thelounge

sed -i 's/reverseProxy: false,/reverseProxy: true,/' /home/thelounge/.thelounge/config.js
sed -i '/fileUpload: {/,/}/ s/enable: false/enable: true/' /home/thelounge/.thelounge/config.js

systemctl start thelounge

echo "$thelounge_nginx_temp" > /etc/nginx/sites-available/thelounge.conf
ln -s /etc/nginx/sites-available/thelounge.conf /etc/nginx/sites-enabled/thelounge.conf

curl --max-time 2 http://$SERVERNAME
certbot --nginx --agree-tos --email $EMAIL --redirect --expand --non-interactive --nginx-server-root /etc/nginx/ --domain $SERVERNAME
rm /etc/nginx/sites-enabled/thelounge.conf
echo "$thelounge_nginx" > /etc/nginx/sites-available/thelounge.conf
ln -s /etc/nginx/sites-available/thelounge.conf /etc/nginx/sites-enabled/thelounge.conf

systemctl reload nginx

echo "$make_account" > /root/make_account.sh
chmod u+x /root/make_account.sh


echo "$TARGET_VERSION" > "${TARGET_MARKER}"
chattr +i "${TARGET_MARKER}"

echo "thelounge" > "${TARGET_MARKER}.name"

exec "$@"
