#!/bin/bash
TARGET_MARKER="/root/.targetonce"
TARGET_VERSION=6

# This package is powered by github.com/arter97/immich-native

immich_nginx_temp=$(cat <<EOF
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

immich_nginx=$(cat <<EOF
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
  proxy_pass http://127.0.0.1:2283/;
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

immich_service=$(cat <<'EOF'
[Unit]
Description=immich server
Documentation=https://github.com/immich-app/immich
Requires=redis-server.service
Requires=postgresql.service
Requires=immich-machine-learning.service

[Service]
User=immich
Group=immich
Type=simple
Restart=on-failure
UMask=0077

WorkingDirectory=/var/lib/immich/app
EnvironmentFile=/var/lib/immich/env
ExecStart=node /var/lib/immich/app/dist/main

SyslogIdentifier=immich
StandardOutput=append:/var/log/immich/immich.log
StandardError=append:/var/log/immich/immich.log

[Install]
WantedBy=multi-user.target
EOF
)

immich_machine_learning_service=$(cat <<'EOF'
[Unit]
Description=immich machine-learning
Documentation=https://github.com/immich-app/immich

[Service]
User=immich
Group=immich
Type=simple
Restart=on-failure
UMask=0077

WorkingDirectory=/var/lib/immich/app
EnvironmentFile=/var/lib/immich/env
ExecStart=/var/lib/immich/app/machine-learning/start.sh

SyslogIdentifier=immich-machine-learning
StandardOutput=append:/var/log/immich/immich-machine-learning.log
StandardError=append:/var/log/immich/immich-machine-learning.log

[Install]
WantedBy=multi-user.target
EOF
)

install_script=$(cat <<'SCRIPTEOF'
#!/bin/bash

set -xeuo pipefail

REV=v1.126.1

IMMICH_PATH=/var/lib/immich
APP=$IMMICH_PATH/app

BASEDIR=$(dirname "$0")
umask 077

rm -rf $APP $APP/../i18n
mkdir -p $APP

# Wipe npm, pypoetry, etc
# This expects immich user's home directory to be on $IMMICH_PATH/home
rm -rf $IMMICH_PATH/home
mkdir -p $IMMICH_PATH/home
echo 'umask 077' > $IMMICH_PATH/home/.bashrc

TMP=/tmp/immich-$(uuidgen)
if [[ $REV =~ ^[0-9A-Fa-f]+$ ]]; then
  # REV is a full commit hash, full clone is required
  git clone https://github.com/immich-app/immich $TMP
else
  git clone https://github.com/immich-app/immich $TMP --depth=1 -b $REV
fi
cd $TMP
git reset --hard $REV
rm -rf .git

# Use 127.0.0.1
find . -type f \( -name '*.ts' -o -name '*.js' \) -exec grep app.listen {} + | \
  sed 's/.*app.listen//' | grep -v '()' | grep '^(' | \
  tr -d "[:blank:]" | awk -F"[(),]" '{print $2}' | sort | uniq | while read port; do
    find . -type f \( -name '*.ts' -o -name '*.js' \) -exec sed -i -e "s@app.listen(${port})@app.listen(${port}, '127.0.0.1')@g" {} +
done
find . -type f \( -name '*.ts' -o -name '*.js' \) -exec sed -i -e "s@PrometheusExporter({ port })@PrometheusExporter({ host: '127.0.0.1', port: port })@g" {} +
grep -RlE "\"0\.0\.0\.0\"|'0\.0\.0\.0'" | xargs -n1 sed -i -e "s@'0\.0\.0\.0'@'127.0.0.1'@g" -e 's@"0\.0\.0\.0"@"127.0.0.1"@g'

# Replace /usr/src
grep -Rl /usr/src | xargs -n1 sed -i -e "s@/usr/src@$IMMICH_PATH@g"
mkdir -p $IMMICH_PATH/cache
grep -RlE "\"/cache\"|'/cache'" | xargs -n1 sed -i -e "s@\"/cache\"@\"$IMMICH_PATH/cache\"@g" -e "s@'/cache'@'$IMMICH_PATH/cache'@g"
grep -RlE "\"/build\"|'/build'" | xargs -n1 sed -i -e "s@\"/build\"@\"$APP\"@g" -e "s@'/build'@'$APP'@g"

# immich-server
cd server
npm ci
npm run build
npm prune --omit=dev --omit=optional
cd -

cd open-api/typescript-sdk
npm ci
npm run build
cd -

cd web
npm ci
npm run build
cd -

cp -a server/node_modules server/dist server/bin $APP/
cp -a web/build $APP/www
cp -a server/resources server/package.json server/package-lock.json $APP/
cp -a server/start*.sh $APP/
cp -a LICENSE $APP/
cp -a i18n $APP/../
cd $APP
npm cache clean --force
cd -

# immich-machine-learning
mkdir -p $APP/machine-learning
python3 -m venv $APP/machine-learning/venv
(
  # Initiate subshell to setup venv
  . $APP/machine-learning/venv/bin/activate
  pip3 install poetry
  cd machine-learning
  poetry install --no-root --with dev --with cpu
  cd ..
)

cp -a \
  machine-learning/ann \
  machine-learning/start.sh \
  machine-learning/log_conf.json \
  machine-learning/gunicorn_conf.py \
  machine-learning/app \
    $APP/machine-learning/

# Install GeoNames
mkdir -p $APP/geodata
cd $APP/geodata
wget -o - https://download.geonames.org/export/dump/admin1CodesASCII.txt &
wget -o - https://download.geonames.org/export/dump/admin2Codes.txt &
wget -o - https://download.geonames.org/export/dump/cities500.zip &
wget -o - https://raw.githubusercontent.com/nvkelso/natural-earth-vector/v5.1.2/geojson/ne_10m_admin_0_countries.geojson &
wait
unzip cities500.zip
date --iso-8601=seconds | tr -d "\n" > geodata-date.txt
rm cities500.zip

# Install sharp
cd $APP
npm install sharp

# Setup upload directory
mkdir -p $IMMICH_PATH/upload
ln -s $IMMICH_PATH/upload $APP/
ln -s $IMMICH_PATH/upload $APP/machine-learning/
chown -R immich:immich $IMMICH_PATH/upload

# Custom start.sh script
cat <<EOF > $APP/start.sh
#!/bin/bash

set -a
. $IMMICH_PATH/env
set +a

cd $APP
exec node $APP/dist/main "\$@"
EOF

cat <<EOF > $APP/machine-learning/start.sh
#!/bin/bash

set -a
. $IMMICH_PATH/env
set +a

cd $APP/machine-learning
. venv/bin/activate

: "\${IMMICH_HOST:=127.0.0.1}"
: "\${IMMICH_PORT:=3003}"
: "\${MACHINE_LEARNING_WORKERS:=1}"
: "\${MACHINE_LEARNING_HTTP_KEEPALIVE_TIMEOUT_S:=2}"
: "\${MACHINE_LEARNING_WORKER_TIMEOUT:=300}"

exec gunicorn app.main:app \
  -k app.config.CustomUvicornWorker \
  -c gunicorn_conf.py \
  -b "\$IMMICH_HOST":"\$IMMICH_PORT" \
  -w "\$MACHINE_LEARNING_WORKERS" \
  -t "\$MACHINE_LEARNING_WORKER_TIMEOUT" \
  --log-config-json log_conf.json \
  --keep-alive "\$MACHINE_LEARNING_HTTP_KEEPALIVE_TIMEOUT_S" \
  --graceful-timeout 0
EOF

# Cleanup
rm -rf $TMP

echo
echo "Done."
echo
SCRIPTEOF
)

DBPASSWORD=$(< /dev/urandom tr -dc 'A-Za-z0-9' | head -c20)
env_file=$(cat <<EOF
# You can find documentation for all the supported env variables at https://immich.app/docs/install/environment-variables

# Connection secret for postgres. You should change it to a random password
DB_PASSWORD=$DBPASSWORD

# The values below this line do not need to be changed
###################################################################################
NODE_ENV=production

DB_USERNAME=immich
DB_DATABASE_NAME=immich
DB_VECTOR_EXTENSION=pgvector

# The location where your uploaded files are stored
UPLOAD_LOCATION=./library

# The Immich version to use. You can pin this to a specific version like "v1.71.0"
IMMICH_VERSION=release

# Hosts & ports
IMMICH_HOST=127.0.0.1
DB_HOSTNAME=127.0.0.1
IMMICH_MACHINE_LEARNING_URL=http://127.0.0.1:3003
REDIS_HOSTNAME=127.0.0.1
EOF
)

redis_systemd_service=$(cat <<EOF
[Unit]
Description=Advanced key-value store
After=network.target
Documentation=http://redis.io/documentation, man:redis-server(1)

[Service]
Type=notify
ExecStart=/usr/bin/redis-server /etc/redis/redis.conf
ExecStop=/bin/kill -s TERM \$MAINPID
PIDFile=/run/redis/redis-server.pid
TimeoutStopSec=0
Restart=always
User=redis
Group=redis
RuntimeDirectory=redis
RuntimeDirectoryMode=2755

UMask=007
PrivateTmp=yes
LimitNOFILE=65535
ProtectHome=yes
ReadOnlyDirectories=/
ReadWriteDirectories=-/var/lib/redis
ReadWriteDirectories=-/var/log/redis
ReadWriteDirectories=-/run/redis

[Install]
WantedBy=multi-user.target
Alias=redis.service
EOF
)

echo "$env_file" > /var/lib/immich/env
chown immich:immich /var/lib/immich/env
sudo -u postgres psql -c "CREATE DATABASE immich;" -c "CREATE USER immich WITH ENCRYPTED PASSWORD '$DBPASSWORD';" -c "GRANT ALL PRIVILEGES ON DATABASE immich TO immich;" -c "ALTER USER immich WITH SUPERUSER;" -c "CREATE EXTENSION IF NOT EXISTS vector;"
echo "$install_script" > /tmp/install.sh
chmod 0755 /tmp/install.sh
sudo -u immich bash -c "/tmp/install.sh"
rm /tmp/install.sh
echo "$immich_machine_learning_service" > /etc/systemd/system/immich-machine-learning.service
echo "$immich_service" > /etc/systemd/system/immich.service
echo "$redis_systemd_service" > /etc/systemd/system/redis-server.service

systemctl daemon-reload
systemctl restart redis-server.service
systemctl enable --now immich-machine-learning.service
systemctl enable --now immich.service

echo "$immich_nginx_temp" > /etc/nginx/sites-available/immich.conf
ln -s /etc/nginx/sites-available/immich.conf /etc/nginx/sites-enabled/immich.conf

curl --max-time 2 http://$SERVERNAME
certbot --nginx --agree-tos --email $EMAIL --redirect --expand --non-interactive --nginx-server-root /etc/nginx/ --domain $SERVERNAME --deploy-hook "systemctl reload nginx"
rm /etc/nginx/sites-enabled/immich.conf
echo "$immich_nginx" > /etc/nginx/sites-available/immich.conf
ln -s /etc/nginx/sites-available/immich.conf /etc/nginx/sites-enabled/immich.conf

systemctl reload nginx

echo "$TARGET_VERSION" > "${TARGET_MARKER}"
chattr +i "${TARGET_MARKER}"

echo "immich" > "${TARGET_MARKER}.name"

exec "$@"
