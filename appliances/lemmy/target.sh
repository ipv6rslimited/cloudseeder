#!/bin/bash
TARGET_MARKER="/root/.targetonce"
TARGET_VERSION=3


lemmy_nginx_temp=$(cat <<EOF
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

lemmy_nginx=$(cat <<'EOF'
limit_req_zone $binary_remote_addr zone={{domain}}_ratelimit:10m rate=1r/s;

server {
    listen 80;
    listen [::]:80;
    server_name {{domain}};
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name {{domain}};

    ssl_certificate /etc/letsencrypt/live/{{domain}}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/{{domain}}/privkey.pem;

    # Various TLS hardening settings
    # https://raymii.org/s/tutorials/Strong_SSL_Security_On_nginx.html
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256';
    ssl_session_timeout  10m;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets on;
    ssl_stapling on;
    ssl_stapling_verify on;

    # Hide nginx version
    server_tokens off;

    # Enable compression for JS/CSS/HTML bundle, for improved client load times.
    # It might be nice to compress JSON, but leaving that out to protect against potential
    # compression+encryption information leak attacks like BREACH.
    gzip on;
    gzip_types text/css application/javascript image/svg+xml;
    gzip_vary on;

    # Only connect to this site via HTTPS for the two years
    add_header Strict-Transport-Security "max-age=63072000";

    # Various content security headers
    add_header Referrer-Policy "same-origin";
    add_header X-Content-Type-Options "nosniff";
    add_header X-Frame-Options "DENY";
    add_header X-XSS-Protection "1; mode=block";

    # Upload limit for pictrs
    client_max_body_size 20M;

    # frontend
    location / {
      # The default ports:

      set $proxpass "http://0.0.0.0:1234";
      if ($http_accept ~ "^application/.*$") {
        set $proxpass "http://0.0.0.0:8536";
      }
      if ($request_method = POST) {
        set $proxpass "http://0.0.0.0:8536";
      }
      proxy_pass $proxpass;

      rewrite ^(.+)/+$ $1 permanent;

      # Send actual client IP upstream
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header Host $host;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # backend
    location ~ ^/(api|pictrs|feeds|nodeinfo|.well-known) {
      proxy_pass http://0.0.0.0:8536;
      proxy_http_version 1.1;
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection "upgrade";

      # Rate limit
      limit_req zone={{domain}}_ratelimit burst=30 nodelay;

      # Add IP forwarding headers
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header Host $host;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}

access_log /var/log/nginx/access.log combined;
EOF
)


DBPASSWORD=$(< /dev/urandom tr -dc 'A-Za-z0-9' | head -c20)
lemmy_configuration=$(cat <<EOF
{
  database: {
    # put your db-passwd from above
    password: "$DBPASSWORD"
  }
  # replace with your domain
  hostname: $SERVERNAME
  bind: "127.0.0.1"
  federation: {
    enabled: true
  }
  # remove this block if you don't require image hosting
  pictrs: {
    url: "http://127.0.0.1:8080/"
  }
}
EOF
)

lemmyui_systemd=$(cat <<EOF
[Unit]
Description=Lemmy UI
After=lemmy.service
Before=nginx.service

[Service]
User=lemmy
WorkingDirectory=/opt/lemmy/lemmy-ui
ExecStart=/usr/bin/node dist/js/server.js
Environment=LEMMY_UI_LEMMY_INTERNAL_HOST=127.0.0.1:8536
Environment=LEMMY_UI_LEMMY_EXTERNAL_HOST=$SERVERNAME
Environment=LEMMY_UI_HTTPS=true
Restart=on-failure

# Hardening
ProtectSystem=full
PrivateTmp=true
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF
)

lemmy_systemd=$(cat <<EOF
[Unit]
Description=Lemmy Server
After=network.target

[Service]
User=lemmy
ExecStart=/opt/lemmy/lemmy-server/lemmy_server
Environment=LEMMY_CONFIG_LOCATION=/opt/lemmy/lemmy-server/lemmy.hjson
Environment=PICTRS_ADDR=127.0.0.1:8080
Environment=RUST_LOG="info"
Restart=on-failure
WorkingDirectory=/opt/lemmy

# Hardening
ProtectSystem=yes
PrivateTmp=true
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF
)

echo "$DBPASSWORD" > /root/.lemmy_db_password
chmod 600 /root/.lemmy_db_password
sudo -iu postgres psql -c "CREATE USER lemmy WITH PASSWORD '$DBPASSWORD';"
sudo -iu postgres psql -c "CREATE DATABASE lemmy WITH OWNER lemmy;"
echo "$lemmy_configuration" > /opt/lemmy/lemmy-server/lemmy.hjson
chown -R lemmy:lemmy /opt/lemmy/
echo "$lemmy_systemd" > /etc/systemd/system/lemmy.service
echo "$lemmyui_systemd" > /etc/systemd/system/lemmy-ui.service
systemctl daemon-reload
systemctl enable --now lemmy
systemctl enable --now lemmy-ui


echo "$lemmy_nginx_temp" > /etc/nginx/sites-available/lemmy.conf
ln -s /etc/nginx/sites-available/lemmy.conf /etc/nginx/sites-enabled/lemmy.conf
systemctl reload nginx

curl --max-time 2 http://$SERVERNAME
certbot --nginx --agree-tos --email $EMAIL --redirect --expand --non-interactive --nginx-server-root /etc/nginx/ --domain $SERVERNAME --deploy-hook "systemctl reload nginx"
rm /etc/nginx/sites-enabled/lemmy.conf
echo "$lemmy_nginx" > /etc/nginx/sites-available/lemmy.conf
ln -s /etc/nginx/sites-available/lemmy.conf /etc/nginx/sites-enabled/lemmy.conf
sed -i -e "s/{{domain}}/$SERVERNAME/g" /etc/nginx/sites-available/lemmy.conf

systemctl reload nginx


echo "$TARGET_VERSION" > "${TARGET_MARKER}"
chattr +i "${TARGET_MARKER}"

echo "lemmy" > "${TARGET_MARKER}.name"

exec "$@"