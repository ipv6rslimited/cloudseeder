#!/bin/bash
TARGET_MARKER="/root/.targetonce"
TARGET_VERSION=1

SECRET=$(openssl rand -hex 32)
DBPASSWORD=$(< /dev/urandom tr -dc 'A-Za-z0-9' | head -c20)
echo "$DBPASSWORD" > /root/.peertube_db_password
chmod 600 /root/.peertube_db_password

sudo -u postgres createuser peertube
sudo -u postgres createdb -O peertube -E UTF8 -T template0 peertube_prod
sudo -u postgres psql -d peertube_prod -c "
  ALTER USER peertube WITH PASSWORD '$DBPASSWORD';
  CREATE EXTENSION IF NOT EXISTS pg_trgm;
  CREATE EXTENSION IF NOT EXISTS unaccent;
"
sudo -u peertube cp /var/www/peertube/peertube-latest/config/default.yaml /var/www/peertube/config/default.yaml
sudo -u peertube cp /var/www/peertube/peertube-latest/config/production.yaml.example /var/www/peertube/config/production.yaml

sudo -u peertube sed -i '/^webserver:/,/^[a-zA-Z]/{
  /hostname:/ s|hostname:.*|hostname: '"$SERVERNAME"'|
}' /var/www/peertube/config/production.yaml
sudo -u peertube sed -i '/^secrets:/,/^[a-zA-Z]/{
  /peertube:/ s|peertube:.*|peertube: '"$SECRET"'|
}' /var/www/peertube/config/production.yaml
sudo -u peertube sed -i '/^database:/,/^[a-zA-Z]/{
  /username:/ s|username:.*|username: peertube|
  /password:/ s|password:.*|password: '"$DBPASSWORD"'|
}' /var/www/peertube/config/production.yaml
sudo -u peertube sed -i '/^admin:/,/^[a-zA-Z]/{
  /email:/ s|email:.*|email: '"$EMAIL"'|
}' /var/www/peertube/config/production.yaml

cp /var/www/peertube/peertube-latest/support/nginx/peertube /etc/nginx/sites-available/peertube 
sed -i "s/\${WEBSERVER_HOST}/$SERVERNAME/g" /etc/nginx/sites-available/peertube
sed -i 's/${PEERTUBE_HOST}/127.0.0.1:9000/g' /etc/nginx/sites-available/peertube
ln -s /etc/nginx/sites-available/peertube /etc/nginx/sites-enabled/peertube
systemctl enable --now nginx
systemctl enable --now redis-server
systemctl enable --now postgresql

systemctl stop nginx
certbot certonly --standalone --agree-tos --email $EMAIL --preferred-challenges http --expand --non-interactive --domain $SERVERNAME
systemctl start nginx

cp /var/www/peertube/peertube-latest/support/systemd/peertube.service /etc/systemd/system/
systemctl daemon-reload

systemctl enable --now peertube

sleep 10
echo "Waiting for PeerTube to initialize"

PEERTUBE_ROOT=$(cd /var/www/peertube/peertube-latest && sudo -u peertube NODE_CONFIG_DIR=/var/www/peertube/config NODE_ENV=production npm run parse-log -- --level info | grep "password" | awk -F": " '{print $NF}')
echo "$PEERTUBE_ROOT" > /root/.peertube_password

echo "$TARGET_VERSION" > "${TARGET_MARKER}"
chattr +i "${TARGET_MARKER}"

echo "peertube" > "${TARGET_MARKER}.name"

exec "$@"
