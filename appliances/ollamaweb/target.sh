#!/bin/bash
TARGET_MARKER="/root/.targetonce"
TARGET_VERSION=3

openwebui_nginx_temp=$(cat <<EOF
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

openwebui_nginx=$(cat <<EOF
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
  proxy_buffering off;
  }
}
EOF
)

openwebui_config=$(cat <<EOF
OLLAMA_BASE_URL='http://enter-ip-here:11434'

OPENAI_API_BASE_URL=''
OPENAI_API_KEY=''

SCARF_NO_ANALYTICS=true
DO_NOT_TRACK=true

LITELLM_LOCAL_MODEL_COST_MAP="True"

EOF
)

openwebui_systemd=$(cat <<EOF
[Unit]
Description=OpenWebUI
After=network.target

[Service]
User=root        
Group=root
WorkingDirectory=/app/backend
ExecStart=sh start.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF
)

echo "$openwebui_nginx_temp" > /etc/nginx/sites-available/openwebui.conf
ln -s /etc/nginx/sites-available/openwebui.conf /etc/nginx/sites-enabled/openwebui.conf
  
curl --max-time 2 http://$SERVERNAME
certbot --nginx --agree-tos --email $EMAIL --redirect --expand --non-interactive --nginx-server-root /etc/nginx/ --domain $SERVERNAME
rm /etc/nginx/sites-enabled/openwebui.conf
echo "$openwebui_nginx" > /etc/nginx/sites-available/openwebui.conf   
ln -s /etc/nginx/sites-available/openwebui.conf /etc/nginx/sites-enabled/openwebui.conf
  
systemctl reload nginx
systemctl daemon-reload

echo "$openwebui_config" > /app/.env

(cd /app &&
 npm i &&
 npm run build &&
 cd backend &&
 pip install -r requirements.txt -U)
echo "$openwebui_systemd" > /etc/systemd/system/openwebui.service
systemctl daemon-reload 
systemctl enable openwebui.service
systemctl start openwebui.service

echo "$TARGET_VERSION" > "${TARGET_MARKER}"
chattr +i "${TARGET_MARKER}"

echo "ollamaweb" > "${TARGET_MARKER}.name"

exec "$@"
