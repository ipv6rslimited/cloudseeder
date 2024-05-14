#!/bin/bash
TARGET_MARKER="/root/.targetonce"
TARGET_VERSION=2

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
  proxy_pass http://127.0.0.1:3001/;
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
Requires=immich.service

[Service]
User=immich
Group=immich
Type=simple
Restart=on-failure

WorkingDirectory=/var/lib/immich/app
EnvironmentFile=/var/lib/immich/env
ExecStart=node /var/lib/immich/app/dist/main immich

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

immich_microservices_service=$(cat <<'EOF'
[Unit]
Description=immich microservices
Documentation=https://github.com/immich-app/immich
Requires=redis-server.service
Requires=postgresql.service

[Service]
User=immich
Group=immich
Type=simple
Restart=on-failure

WorkingDirectory=/var/lib/immich/app
EnvironmentFile=/var/lib/immich/env
ExecStart=node /var/lib/immich/app/dist/main microservices

SyslogIdentifier=immich-microservices
StandardOutput=append:/var/log/immich/immich-microservices.log
StandardError=append:/var/log/immich/immich-microservices.log

[Install]
WantedBy=multi-user.target
EOF
)

install_script=$(cat <<'SCRIPTEOF'
#!/bin/bash

set -xeuo pipefail

TAG=v1.104.0

IMMICH_PATH=/var/lib/immich
APP=$IMMICH_PATH/app

BASEDIR=$(dirname "$0")

rm -rf $APP
mkdir -p $APP

# Wipe npm, pypoetry, etc
# This expects immich user's home directory to be on $IMMICH_PATH/home
rm -rf $IMMICH_PATH/home
mkdir -p $IMMICH_PATH/home

TMP=/tmp/immich-$(uuidgen)
git clone https://github.com/immich-app/immich $TMP
cd $TMP
git reset --hard $TAG

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
  # pip install poetry
  max_attempts=5
  attempt=1
  while [ $attempt -le $max_attempts ]; do
    echo "Attempt $attempt of $max_attempts: Installing dependencies..."
    set +e
    poetry install --no-root --with dev --with cpu && break || echo "Attempt failed, retrying in 10 seconds..."
    set -e
    sleep 10
    attempt=$((attempt + 1))
  done

  if [ $attempt -gt $max_attempts ]; then
    echo "Failed to install dependencies after $max_attempts attempts."
    exit 1
  fi
  cd ..
)
cp -a machine-learning/ann machine-learning/start.sh machine-learning/app $APP/machine-learning/

# Replace /usr/src
cd $APP
grep -Rl /usr/src | xargs -n1 sed -i -e "s@/usr/src@$IMMICH_PATH@g"
ln -sf $IMMICH_PATH/app/resources $IMMICH_PATH/
mkdir -p $IMMICH_PATH/cache
sed -i -e "s@\"/cache\"@\"$IMMICH_PATH/cache\"@g" $APP/machine-learning/app/config.py

# Install sharp
cd $APP
npm install sharp

# Setup upload directory
mkdir -p $IMMICH_PATH/upload
ln -s $IMMICH_PATH/upload $APP/
ln -s $IMMICH_PATH/upload $APP/machine-learning/

# Use 127.0.0.1
sed -i -e "s@app.listen(port)@app.listen(port, '127.0.0.1')@g" $APP/dist/main.js

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

: "\${MACHINE_LEARNING_HOST:=127.0.0.1}"
: "\${MACHINE_LEARNING_PORT:=3003}"
: "\${MACHINE_LEARNING_WORKERS:=1}"
: "\${MACHINE_LEARNING_WORKER_TIMEOUT:=120}"

exec gunicorn app.main:app \
        -k app.config.CustomUvicornWorker \
        -w "\$MACHINE_LEARNING_WORKERS" \
        -b "\$MACHINE_LEARNING_HOST":"\$MACHINE_LEARNING_PORT" \
        -t "\$MACHINE_LEARNING_WORKER_TIMEOUT" \
        --log-config-json log_conf.json \
        --graceful-timeout 0
EOF

# Cleanup
rm -rf $TMP

echo
echo "Done. Please install the systemd services to start using Immich."
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
DB_HOSTNAME=127.0.0.1
MACHINE_LEARNING_HOST=127.0.0.1
IMMICH_MACHINE_LEARNING_URL=http://127.0.0.1:3003
REDIS_HOSTNAME=127.0.0.1
EOF
)

echo "$env_file" > /var/lib/immich/env
chown immich:immich /var/lib/immich/env
sudo -u postgres psql -c "CREATE DATABASE immich;" -c "CREATE USER immich WITH ENCRYPTED PASSWORD '$DBPASSWORD';" -c "GRANT ALL PRIVILEGES ON DATABASE immich TO immich;" -c "ALTER USER immich WITH SUPERUSER;"
npm install -g npm@10.5.2
echo "$install_script" > /tmp/install.sh
chmod 0755 /tmp/install.sh
sudo -u immich bash -c "/tmp/install.sh"
rm /tmp/install.sh
echo "$immich_machine_learning_service" > /etc/systemd/system/immich-machine-learning.service
echo "$immich_microservices_service" > /etc/systemd/system/immich-microservices.service
echo "$immich_service" > /etc/systemd/system/immich.service

systemctl daemon-reload
systemctl enable --now immich-machine-learning.service
systemctl enable --now immich-microservices.service
systemctl enable --now immich.service

echo "$immich_nginx_temp" > /etc/nginx/sites-available/immich.conf
ln -s /etc/nginx/sites-available/immich.conf /etc/nginx/sites-enabled/immich.conf

curl --max-time 2 http://$SERVERNAME
certbot --nginx --agree-tos --email $EMAIL --redirect --expand --non-interactive --nginx-server-root /etc/nginx/ --domain $SERVERNAME
rm /etc/nginx/sites-enabled/immich.conf
echo "$immich_nginx" > /etc/nginx/sites-available/immich.conf
ln -s /etc/nginx/sites-available/immich.conf /etc/nginx/sites-enabled/immich.conf

systemctl reload nginx

echo "$TARGET_VERSION" > "${TARGET_MARKER}"
chattr +i "${TARGET_MARKER}"

echo "immich" > "${TARGET_MARKER}.name"

exec "$@"
