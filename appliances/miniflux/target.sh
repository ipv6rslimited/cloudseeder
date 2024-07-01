#!/bin/bash
TARGET_MARKER="/root/.targetonce"
TARGET_VERSION=2

mkadmin=$(cat <<EOF
#!/bin/bash
env \$(grep '^DATABASE_URL=' /etc/miniflux.conf) miniflux -create-admin
EOF
)

miniflux_nginx_temp=$(cat <<EOF
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
  
miniflux_nginx=$(cat <<EOF
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
  proxy_pass http://127.0.0.1:8080/;
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
echo "$DBPASSWORD" > /root/.miniflux_db_password

sudo -i -u postgres bash << EOF
psql -c "CREATE USER miniflux WITH PASSWORD '$DBPASSWORD';"
createdb -O miniflux miniflux
psql -c "GRANT ALL PRIVILEGES ON DATABASE miniflux TO miniflux;"
EOF

sudo -i -u postgres bash << EOF
psql -d miniflux -c 'CREATE EXTENSION hstore;'
EOF

echo "DATABASE_URL=postgres://miniflux:$DBPASSWORD@127.0.0.1/miniflux?sslmode=disable" >> /etc/miniflux.conf

systemctl start miniflux

echo "$miniflux_nginx_temp" > /etc/nginx/sites-available/miniflux.conf
ln -s /etc/nginx/sites-available/miniflux.conf /etc/nginx/sites-enabled/miniflux.conf

curl --max-time 2 http://$SERVERNAME
certbot --nginx --agree-tos --email $EMAIL --redirect --expand --non-interactive --nginx-server-root /etc/nginx/ --domain $SERVERNAME
rm /etc/nginx/sites-enabled/miniflux.conf
echo "$miniflux_nginx" > /etc/nginx/sites-available/miniflux.conf
ln -s /etc/nginx/sites-available/miniflux.conf /etc/nginx/sites-enabled/miniflux.conf

systemctl reload nginx

echo "$mkadmin" > /root/mkadmin.sh
chmod u+x /root/mkadmin.sh

echo "$TARGET_VERSION" > "${TARGET_MARKER}"
chattr +i "${TARGET_MARKER}"

echo "miniflux" > "${TARGET_MARKER}.name"

exec "$@"
