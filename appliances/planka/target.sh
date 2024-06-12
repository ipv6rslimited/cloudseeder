#!/bin/bash
TARGET_MARKER="/root/.targetonce"
TARGET_VERSION=6


planka_nginx_temp=$(cat <<EOF
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

planka_nginx=$(cat <<EOF
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
SECRET_KEY=$(openssl rand -hex 64)

planka_env=$(cat << EOF
## Required
BASE_URL=https://$SERVERNAME
DATABASE_URL=postgresql://planka:$DBPASSWORD@127.0.0.1/planka
SECRET_KEY=$SECRET_KEY

## Optional

# TRUST_PROXY=0
# TOKEN_EXPIRES_IN=365 # In days

# related: https://github.com/knex/knex/issues/2354
# As knex does not pass query parameters from the connection string we
# have to use environment variables in order to pass the desired values, e.g.
# PGSSLMODE=<value>

# Configure knex to accept SSL certificates
# KNEX_REJECT_UNAUTHORIZED_SSL_CERTIFICATE=false

DEFAULT_ADMIN_EMAIL=$ADMINEMAIL
DEFAULT_ADMIN_PASSWORD=$ADMINPASSWORD
DEFAULT_ADMIN_NAME="$ADMINNAME"
DEFAULT_ADMIN_USERNAME=$ADMINUSERNAME

# OIDC_ISSUER=
# OIDC_CLIENT_ID=
# OIDC_CLIENT_SECRET=
# OIDC_SCOPES=openid email profile
# OIDC_ADMIN_ROLES=admin
# OIDC_ROLES_ATTRIBUTE=groups
# OIDC_IGNORE_ROLES=true

## Do not edit this

TZ=UTC
EOF
)

planka_service=$(cat <<'EOF'
[Unit]
Description=planka server
Documentation=https://planka.cloud
Requires=postgresql.service

[Service]
User=planka
Group=planka
Type=simple
Restart=on-failure

Environment="NODE_ENV=production"
WorkingDirectory=/var/www/planka/
EnvironmentFile=/var/www/planka/.env
ExecStart=/usr/bin/node app.js --port=8080

SyslogIdentifier=planka
StandardOutput=append:/var/log/planka/planka.log
StandardError=append:/var/log/planka/planka.log

[Install]
WantedBy=multi-user.target
EOF
)

cd /tmp && sudo -u postgres psql -c "CREATE ROLE planka WITH LOGIN SUPERUSER;" && sudo -u postgres createdb planka && sudo -u planka bash -c "psql -d planka -c \"ALTER USER planka PASSWORD '$DBPASSWORD';\""
cp /root/planka-prebuild.zip /home/planka
chown planka:planka /home/planka/planka-prebuild.zip
sudo -u planka bash -c "unzip /home/planka/planka-prebuild.zip -d /var/www"
rm /home/planka/planka-prebuild.zip
sudo -u planka bash -c "cd /var/www/planka && npm install"
echo "$planka_env" > /var/www/planka/.env
chown planka:planka /var/www/planka/.env
sudo -u planka bash -c "cd /var/www/planka && npm run db:init"
echo "$planka_service" > /etc/systemd/system/planka.service
systemctl daemon-reload
systemctl enable --now planka.service

echo "$planka_nginx_temp" > /etc/nginx/sites-available/planka.conf
ln -s /etc/nginx/sites-available/planka.conf /etc/nginx/sites-enabled/planka.conf

curl --max-time 2 http://$SERVERNAME
certbot --nginx --agree-tos --email $EMAIL --redirect --expand --non-interactive --nginx-server-root /etc/nginx/ --domain $SERVERNAME
rm /etc/nginx/sites-enabled/planka.conf
echo "$planka_nginx" > /etc/nginx/sites-available/planka.conf
ln -s /etc/nginx/sites-available/planka.conf /etc/nginx/sites-enabled/planka.conf

systemctl reload nginx

echo "$TARGET_VERSION" > "${TARGET_MARKER}"
chattr +i "${TARGET_MARKER}"

echo "planka" > "${TARGET_MARKER}.name"

exec "$@"
