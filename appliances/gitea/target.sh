#!/bin/bash
TARGET_MARKER="/root/.targetonce"
TARGET_VERSION=4



gitea_nginx_temp=$(cat <<EOF
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

gitea_nginx=$(cat <<EOF
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


gitea_systemd=$(cat <<EOF
[Unit]
Description=Gitea
After=syslog.target
After=network.target
After=mysql.service

[Service]
RestartSec=2s
Type=simple
User=git
Group=git
WorkingDirectory=/var/lib/gitea/
ExecStart=/usr/bin/gitea web -c /etc/gitea/app.ini
Restart=always
Environment=USER=git HOME=/home/git GITEA_WORK_DIR=/var/lib/gitea

[Install]
WantedBy=multi-user.target
EOF
)

DBPASSWORD=$(< /dev/urandom tr -dc 'A-Za-z0-9' | head -c20)
echo "$DBPASSWORD" > /root/.gitea_db_password
chmod 600 /root/.gitea_db_password
mysql -u root -e "
 SET GLOBAL innodb_file_per_table = ON;
 CREATE DATABASE gitea;
 CREATE USER 'gitea'@'localhost' IDENTIFIED BY '$DBPASSWORD';
 GRANT ALL ON gitea.* TO 'gitea'@'localhost' WITH GRANT OPTION;
 ALTER DATABASE gitea CHARACTER SET = utf8mb4 COLLATE utf8mb4_unicode_ci;
 FLUSH PRIVILEGES;"
systemctl restart mysql
sed -i '/^\[mysqld\]$/a innodb_file_format = Barracuda\ninnodb_large_prefix = 1\ninnodb_default_row_format = dynamic' /etc/mysql/mysql.conf.d/mysqld.cnf
echo "$gitea_systemd" > /etc/systemd/system/gitea.service
systemctl daemon-reload
systemctl enable --now gitea

echo "$gitea_nginx_temp" > /etc/nginx/sites-available/gitea.conf
ln -s /etc/nginx/sites-available/gitea.conf /etc/nginx/sites-enabled/gitea.conf

curl --max-time 2 http://$SERVERNAME
certbot --nginx --agree-tos --email $EMAIL --redirect --expand --non-interactive --nginx-server-root /etc/nginx/ --domain $SERVERNAME
rm /etc/nginx/sites-enabled/gitea.conf
echo "$gitea_nginx" > /etc/nginx/sites-available/gitea.conf
ln -s /etc/nginx/sites-available/gitea.conf /etc/nginx/sites-enabled/gitea.conf

systemctl reload nginx

echo "$TARGET_VERSION" > "${TARGET_MARKER}"
chattr +i "${TARGET_MARKER}"

echo "gitea" > "${TARGET_MARKER}.name"

exec "$@"
