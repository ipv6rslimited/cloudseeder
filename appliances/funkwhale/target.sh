#!/bin/bash
TARGET_MARKER="/root/.targetonce"
TARGET_VERSION=2

funkwhale_make_admin=$(cat <<EOF
#!/bin/bash
cd /srv/funkwhale && sudo -u funkwhale venv/bin/funkwhale-manage fw users create --superuser
EOF
)
funkwhale_nginx_temp=$(cat <<EOF
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

funkwhale_proxy=$(cat <<'EOF'
# global proxy conf
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header X-Forwarded-Host $host:$server_port;
proxy_set_header X-Forwarded-Port $server_port;
proxy_redirect off;

# websocket support
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection $connection_upgrade;
EOF
)

funkwhale_nginx=$(cat <<'EOF'
upstream funkwhale-api {
    # depending on your setup, you may want to update this
    server ${FUNKWHALE_API_IP}:${FUNKWHALE_API_PORT};
}

# Required for websocket support.
map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}

server {
    listen 80;
    listen [::]:80;
    # update this to match your instance name
    server_name ${FUNKWHALE_HOSTNAME};

    # useful for Let's Encrypt
    location /.well-known/acme-challenge/ {
        allow all;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen      443 ssl http2;
    listen [::]:443 ssl http2;

    server_name ${FUNKWHALE_HOSTNAME};

    # TLS
    # Feel free to use your own configuration for SSL here or simply remove the
    # lines and move the configuration to the previous server block if you
    # don't want to run funkwhale behind https (this is not recommended)
    # have a look here for let's encrypt configuration:
    # https://certbot.eff.org/all-instructions/#debian-9-stretch-nginx
    ssl_protocols TLSv1.2;
    ssl_ciphers HIGH:!MEDIUM:!LOW:!aNULL:!NULL:!SHA;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_certificate     /etc/letsencrypt/live/${FUNKWHALE_HOSTNAME}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${FUNKWHALE_HOSTNAME}/privkey.pem;

    # HSTS
    add_header Strict-Transport-Security "max-age=31536000";


    # General configs
    root ${FUNKWHALE_FRONTEND_PATH};
    client_max_body_size ${NGINX_MAX_BODY_SIZE};
    charset utf-8;

    # compression settings
    gzip on;
    gzip_comp_level    5;
    gzip_min_length    256;
    gzip_proxied       any;
    gzip_vary          on;
    gzip_types
        application/javascript
        application/vnd.geo+json
        application/vnd.ms-fontobject
        application/x-font-ttf
        application/x-web-app-manifest+json
        font/opentype
        image/bmp
        image/svg+xml
        image/x-icon
        text/cache-manifest
        text/css
        text/plain
        text/vcard
        text/vnd.rim.location.xloc
        text/vtt
        text/x-component
        text/x-cross-domain-policy;
    # end of compression settings

    # headers
    add_header Content-Security-Policy "default-src 'self'; connect-src https: wss: http: ws: 'self' 'unsafe-eval'; script-src 'self' 'wasm-unsafe-eval'; style-src https: http: 'self' 'unsafe-inline'; img-src https: http: 'self' data:; font-src https: http: 'self' data:; media-src https: http: 'self' data:; object-src 'none'";
    add_header Referrer-Policy "strict-origin-when-cross-origin";
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header Service-Worker-Allowed "/";

    location /api/ {
        include /etc/nginx/funkwhale_proxy.conf;
        # This is needed if you have file import via upload enabled.
        client_max_body_size ${NGINX_MAX_BODY_SIZE};
        proxy_pass   http://funkwhale-api;
    }

    location ~ ^/library/(albums|tracks|artists|playlists)/ {
        include /etc/nginx/funkwhale_proxy.conf;
        proxy_pass   http://funkwhale-api;
    }

    location /channels/ {
        include /etc/nginx/funkwhale_proxy.conf;
        proxy_pass   http://funkwhale-api;
    }

    location ~ ^/@(vite-plugin-pwa|vite|id)/ {
        include /etc/nginx/funkwhale_proxy.conf;
        alias ${FUNKWHALE_FRONTEND_PATH}/;
        try_files $uri $uri/ /index.html;
    }

    location /@ {
        include /etc/nginx/funkwhale_proxy.conf;
        proxy_pass   http://funkwhale-api;
    }

    location / {
        expires 1d;
        include /etc/nginx/funkwhale_proxy.conf;
        alias ${FUNKWHALE_FRONTEND_PATH}/;
        try_files $uri $uri/ /index.html;
    }

    location ~ "/(front/)?embed.html" {
        alias ${FUNKWHALE_FRONTEND_PATH}/embed.html;
        add_header Content-Security-Policy "connect-src https: http: 'self'; default-src 'self'; script-src 'self' unpkg.com 'unsafe-inline' 'unsafe-eval'; style-src https: http: 'self' 'unsafe-inline'; img-src https: http: 'self' data:; font-src https: http: 'self' data:; object-src 'none'; media-src https: http: 'self' data:";
        add_header Referrer-Policy "strict-origin-when-cross-origin";

        expires 1d;
    }

    location /federation/ {
        include /etc/nginx/funkwhale_proxy.conf;
        proxy_pass   http://funkwhale-api;
    }

    # You can comment this if you do not plan to use the Subsonic API.
    location /rest/ {
        include /etc/nginx/funkwhale_proxy.conf;
        proxy_pass   http://funkwhale-api/api/subsonic/rest/;
    }

    location /.well-known/ {
        include /etc/nginx/funkwhale_proxy.conf;
        proxy_pass   http://funkwhale-api;
    }

    # Allow direct access to only specific subdirectories in /media
    location /media/__sized__/ {
        alias ${MEDIA_ROOT}/__sized__/;
        add_header Access-Control-Allow-Origin '*';
    }

    # Allow direct access to only specific subdirectories in /media
    location /media/attachments/ {
        alias ${MEDIA_ROOT}/attachments/;
        add_header Access-Control-Allow-Origin '*';
    }

    # Allow direct access to only specific subdirectories in /media
    location /media/dynamic_preferences/ {
        alias ${MEDIA_ROOT}/dynamic_preferences/;
        add_header Access-Control-Allow-Origin '*';
    }

    # This is an internal location that is used to serve
    # media (uploaded) files once correct permission / authentication
    # has been checked on API side.
    # Comment the "NON-S3" commented lines and uncomment "S3" commented lines
    # if you're storing media files in a S3 bucket.
    location ~ /_protected/media/(.+) {
        internal;
        alias   ${MEDIA_ROOT}/$1;                                           # NON-S3
        # Needed to ensure DSub auth isn't forwarded to S3/Minio, see #932.
#       proxy_set_header Authorization "";                                  # S3
#       proxy_pass $1;                                                      # S3
        add_header Access-Control-Allow-Origin '*';
    }

    location /_protected/music/ {
        # This is an internal location that is used to serve
        # local music files once correct permission / authentication
        # has been checked on API side.
        # Set this to the same value as your MUSIC_DIRECTORY_PATH setting.
        internal;
        alias   ${MUSIC_DIRECTORY_PATH}/;
        add_header Access-Control-Allow-Origin '*';
    }

    location /manifest.json {
        # If the reverse proxy is terminating SSL, nginx gets confused and redirects to http, hence the full URL
        return 302 ${FUNKWHALE_PROTOCOL}://${FUNKWHALE_HOSTNAME}/api/v1/instance/spa-manifest.json;
    }

    location /staticfiles/ {
        alias ${STATIC_ROOT}/;
    }
}
EOF
)



DBPASSWORD=$(< /dev/urandom tr -dc 'A-Za-z0-9' | head -c20)
echo "$DBPASSWORD" > /root/.funkwhale_db_password
chmod 600 /root/.funkwhale_db_password


DJANGOKEY=$(openssl rand -base64 45)


funkwhale_env=$(cat <<EOF
FUNKWHALE_API_IP=127.0.0.1
FUNKWHALE_API_PORT=5000
FUNKWHALE_WEB_WORKERS=4
FUNKWHALE_HOSTNAME=$SERVERNAME
FUNKWHALE_PROTOCOL=https
LOGLEVEL=error

# Configure e-mail sending using this variale
# By default, funkwhale will output e-mails sent to stdout
# here are a few examples for this setting
# EMAIL_CONFIG=consolemail://         # output e-mails to console (the default)
# EMAIL_CONFIG=dummymail://          # disable e-mail sending completely
# On a production instance, you'll usually want to use an external SMTP server:
# If 'user' or 'password' contain special characters (eg.
# 'noreply@youremail.host' as 'user'), be sure to urlencode them, using
# for example the command:
# 'python3 -c 'import urllib.parse; print(urllib.parse.quote_plus
# ("noreply@youremail.host"))''
# (returns 'noreply%40youremail.host')
# EMAIL_CONFIG=smtp://user:password@youremail.host:25
# EMAIL_CONFIG=smtp+ssl://user:password@youremail.host:465
# EMAIL_CONFIG=smtp+tls://user:password@youremail.host:587

# Make e-mail verification mandatory before using the service
# Doesn't apply to admins.
# ACCOUNT_EMAIL_VERIFICATION_ENFORCE=false

# The e-mail address to use to send system e-mails.
# DEFAULT_FROM_EMAIL=noreply@yourdomain

REVERSE_PROXY_TYPE=nginx
DATABASE_URL=postgresql://funkwhale@:5432/funkwhale
CACHE_URL=redis://127.0.0.1:6379/0

# Where media files (such as album covers or audio tracks) should be stored
# on your system?
# (Ensure this directory actually exists)
MEDIA_ROOT=/srv/funkwhale/data/media

# Where static files (such as API css or icons) should be compiled
# on your system?
# (Ensure this directory actually exists)
STATIC_ROOT=/srv/funkwhale/data/static

DJANGO_SETTINGS_MODULE=config.settings.production
DJANGO_SECRET_KEY=$DJANGOKEY

# You don't have to edit this, but you can put the admin on another URL if you
# want to
# DJANGO_ADMIN_URL=^api/admin/

# In-place import settings
# You can safely leave those settings uncommented if you don't plan to use
# in place imports.
# Typical docker setup:
#   MUSIC_DIRECTORY_PATH=/music  # docker-only
#   MUSIC_DIRECTORY_SERVE_PATH=/srv/funkwhale/data/music
# Typical non-docker setup:
#   MUSIC_DIRECTORY_PATH=/srv/funkwhale/data/music
#   # MUSIC_DIRECTORY_SERVE_PATH= # stays commented, not needed

MUSIC_DIRECTORY_PATH=/srv/funkwhale/data/music
MUSIC_DIRECTORY_SERVE_PATH=/srv/funkwhale/data/music

# LDAP settings
# Use the following options to allow authentication on your Funkwhale instance
# using a LDAP directory.
# Have a look at https://docs.funkwhale.audio/installation/ldap.html for
# detailed instructions.

# LDAP_ENABLED=False
# LDAP_SERVER_URI=ldap://your.server:389
# LDAP_BIND_DN=cn=admin,dc=domain,dc=com
# LDAP_BIND_PASSWORD=bindpassword
# LDAP_SEARCH_FILTER=(|(cn={0})(mail={0}))
# LDAP_START_TLS=False
# LDAP_ROOT_DN=dc=domain,dc=com

FUNKWHALE_FRONTEND_PATH=/srv/funkwhale/front/dist

# Nginx related configuration
NGINX_MAX_BODY_SIZE=100M

## External storages configuration
# Funkwhale can store uploaded files on Amazon S3 and S3-compatible storages (such as Minio)
# Uncomment and fill the variables below

AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_STORAGE_BUCKET_NAME=
# An optional bucket subdirectory were you want to store the files. This is especially useful
# if you plan to use share the bucket with other services
# AWS_LOCATION=

# If you use a S3-compatible storage such as minio, set the following variable
# the full URL to the storage server. Example:
#   AWS_S3_ENDPOINT_URL=https://minio.mydomain.com
# AWS_S3_ENDPOINT_URL=

# If you want to serve media directly from your S3 bucket rather than through a proxy,
# set this to false
# PROXY_MEDIA=false

# If you are using Amazon S3 to serve media directly, you will need to specify your region
# name in order to access files. Example:
#   AWS_S3_REGION_NAME=eu-west-2
# AWS_S3_REGION_NAME=

# If you are using Amazon S3, use this setting to configure how long generated URLs should stay
# valid. The default value is 3600 (60 minutes). The maximum accepted value is 604800 (7 days)

# AWS_QUERYSTRING_EXPIRE=

# If you are using an S3-compatible object storage provider, and need to provide a default
# ACL for object uploads that is different from the default applied by boto3, you may
# override it here. Example:
#    AWS_DEFAULT_ACL=public-read
# Available options can be found here: https://docs.aws.amazon.com/AmazonS3/latest/userguide/acl-overview.html#canned-acl

# AWS_DEFAULT_ACL=

# Funkwhale allows collecting errors using Sentry compatible APIs. If you want
# to help us improving Funkwhale, feel free to use our instance:
#FUNKWHALE_SENTRY_DSN=https://5840197379c64f65aad3c5c09274994d@am.funkwhale.audio/1
EOF
)

funkwhale_target=$(cat <<EOF
[Unit]
Description=Funkwhale
Wants=funkwhale-server.service funkwhale-worker.service funkwhale-beat.service

[Install]
WantedBy=multi-user.target
EOF
)
funkwhale_server_service=$(cat <<'EOF'
[Unit]
Description=Funkwhale application server
After=redis.service postgresql.service
PartOf=funkwhale.target

[Service]
User=funkwhale
# adapt this depending on the path of your funkwhale installation
WorkingDirectory=/srv/funkwhale/api
EnvironmentFile=/srv/funkwhale/config/.env

Type=notify
KillMode=mixed
ExecStart=/srv/funkwhale/venv/bin/gunicorn \
    config.asgi:application \
    --workers ${FUNKWHALE_WEB_WORKERS} \
    --worker-class uvicorn.workers.UvicornWorker \
    --bind ${FUNKWHALE_API_IP}:${FUNKWHALE_API_PORT}
ExecReload=/bin/kill -s HUP $MAINPID

[Install]
WantedBy=multi-user.target
EOF
)

funkwhale_worker_service=$(cat <<'EOF'
[Unit]
Description=Funkwhale celery worker
After=redis.service postgresql.service
PartOf=funkwhale.target

[Service]
User=funkwhale
# adapt this depending on the path of your funkwhale installation
WorkingDirectory=/srv/funkwhale/api
Environment="CELERYD_CONCURRENCY=0"
EnvironmentFile=/srv/funkwhale/config/.env

ExecStart=/srv/funkwhale/venv/bin/celery \
    --app funkwhale_api.taskapp \
    worker \
    --loglevel INFO \
    --concurrency=${CELERYD_CONCURRENCY}

[Install]
WantedBy=multi-user.target
EOF
)

funkwhale_beat_service=$(cat <<EOF
[Unit]
Description=Funkwhale celery beat process
After=redis.service postgresql.service
PartOf=funkwhale.target

[Service]
User=funkwhale
# adapt this depending on the path of your funkwhale installation
WorkingDirectory=/srv/funkwhale/api
EnvironmentFile=/srv/funkwhale/config/.env

ExecStart=/srv/funkwhale/venv/bin/celery \
    --app funkwhale_api.taskapp \
    beat \
    --loglevel INFO

[Install]
WantedBy=multi-user.target
EOF
)

echo "$funkwhale_env" > /srv/funkwhale/config/.env
chown funkwhale:funkwhale /srv/funkwhale/config/.env
chmod 600 /srv/funkwhale/config/.env


sudo -u postgres psql -c "CREATE DATABASE funkwhale WITH ENCODING 'utf8';"
sudo -u postgres psql -c "CREATE USER funkwhale;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE funkwhale TO funkwhale;"
sudo -u postgres psql funkwhale -c 'CREATE EXTENSION "unaccent";'
sudo -u postgres psql funkwhale -c 'CREATE EXTENSION "citext";'

(cd /srv/funkwhale && sudo -u funkwhale venv/bin/funkwhale-manage migrate && sudo venv/bin/funkwhale-manage collectstatic)

echo "$funkwhale_target" > "/etc/systemd/system/funkwhale.target"
echo "$funkwhale_server_service" > "/etc/systemd/system/funkwhale-server.service"
echo "$funkwhale_worker_service" > "/etc/systemd/system/funkwhale-worker.service"
echo "$funkwhale_beat_service" > "/etc/systemd/system/funkwhale-beat.service"
chown -R funkwhale:funkwhale /srv/funkwhale
usermod -aG funkwhale www-data

systemctl daemon-reload
systemctl enable --now funkwhale.target

echo "$funkwhale_proxy" > /etc/nginx/funkwhale_proxy.conf
echo "$funkwhale_nginx" > /etc/nginx/sites-available/funkwhale.template
set -a && source /srv/funkwhale/config/.env && set +a
envsubst "`env | awk -F = '{printf \" $%s\", $$1}'`" \
   < /etc/nginx/sites-available/funkwhale.template \
   > /etc/nginx/sites-available/funkwhale.conf

echo "$funkwhale_nginx_temp" > /etc/nginx/sites-available/funkwhales.conf
ln -s /etc/nginx/sites-available/funkwhales.conf /etc/nginx/sites-enabled/funkwhales.conf
systemctl reload nginx

curl --max-time 2 http://$SERVERNAME
certbot --nginx --agree-tos --email $EMAIL --redirect --expand --non-interactive --nginx-server-root /etc/nginx/ --domain $SERVERNAME

rm /etc/nginx/sites-enabled/funkwhales.conf
rm /etc/nginx/sites-available/funkwhales.conf
ln -s /etc/nginx/sites-available/funkwhale.conf /etc/nginx/sites-enabled/
systemctl reload nginx

echo "$funkwhale_make_admin" > /root/make_admin.sh
chmod u+x /root/make_admin.sh

echo "$TARGET_VERSION" > "${TARGET_MARKER}"
chattr +i "${TARGET_MARKER}"

echo "funkwhale" > "${TARGET_MARKER}.name"

exec "$@"
