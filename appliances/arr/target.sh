#!/bin/bash
TARGET_MARKER="/root/.targetonce"
TARGET_VERSION=1

prowlarr_qbittorrent_nginx_temp=$(cat <<EOF
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

prowlarr_qbittorrent_nginx=$(cat <<EOF
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

  auth_basic "Protected Area";
  auth_basic_user_file /etc/nginx/.arrpasswd;


  location /radarr {
  if (\$request_uri ~* ^/radarr\$) {
    return 301 \$scheme://\$host/radarr/;
  }
  proxy_pass http://127.0.0.1:7878;
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
  location /sonarr {
  if (\$request_uri ~* ^/sonarr\$) {
    return 301 \$scheme://\$host/sonarr/;
  }
  proxy_pass http://127.0.0.1:8989;
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
  location /lidarr {
  if (\$request_uri ~* ^/lidarr\$) {
    return 301 \$scheme://\$host/lidarr/;
  }
  proxy_pass http://127.0.0.1:8686;
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
  location /readarr {
  if (\$request_uri ~* ^/readarr\$) {
    return 301 \$scheme://\$host/readarr/;
  }
  proxy_pass http://127.0.0.1:8787;
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
  location /whisparr {
  if (\$request_uri ~* ^/whisparr\$) {
    return 301 \$scheme://\$host/whisparr/;
  }
  proxy_pass http://127.0.0.1:6969;
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
  location /qbittorrent {
  if (\$request_uri ~* ^/qbittorrent\$) {
    return 301 \$scheme://\$host/qbittorrent/;
  }
  rewrite ^/qbittorrent/(.*)\$ /\$1 break;
  proxy_pass http://127.0.0.1:8080;
  proxy_set_header Host \$host;
  proxy_set_header X-Real-IP \$remote_addr;
  proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto \$scheme;
  proxy_set_header X-Forwarded-Protocol \$scheme;
  proxy_set_header X-Forwarded-Host \$http_host;
  proxy_set_header Upgrade \$http_upgrade;
  proxy_set_header Connection "upgrade";
  proxy_set_header Accept-Encoding gzip;
  proxy_pass_header Content-Disposition;
  proxy_pass_header Content-Type;
  add_header X-Content-Type-Options nosniff;
  add_header Cache-Control "no-cache, no-store, must-revalidate";
  proxy_ignore_headers "Cache-Control";
  proxy_buffering off;
  }
  location / {
  proxy_pass http://127.0.0.1:9696/;
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

qbittorrent_password_generator=$(cat <<EOF
/*
**
** qbittorrent_password_generator
** Generates a password hash inline with qBittorrent's PBKDF2 scheme
**
** Distributed under the COOLER License.
**
** Copyright (c) 2024 IPv6.rs <https://ipv6.rs>
** All Rights Reserved
**
*/
#include <iostream>
#include <vector>
#include <openssl/rand.h>
#include <openssl/evp.h>
#include <openssl/bio.h>
#include <openssl/buffer.h>

std::vector<unsigned char> generate_salt(size_t length) {
  std::vector<unsigned char> salt(length);
  if (!RAND_bytes(salt.data(), salt.size())) {
    throw std::runtime_error("Failed to generate random salt.");
  }
  return salt;
}

std::vector<unsigned char> pbkdf2_hash(const std::string& password, const std::vector<unsigned char>& salt, int iterations, int outputBytes) {
  std::vector<unsigned char> key(outputBytes);
  const EVP_MD* algorithm = EVP_sha512();

  if (!PKCS5_PBKDF2_HMAC(password.c_str(), password.length(), salt.data(), salt.size(), iterations, algorithm, key.size(), key.data())) {
    throw std::runtime_error("PKCS5_PBKDF2_HMAC failed.");
  }

  return key;
}

std::string base64_encode(const unsigned char *input, int length) {
  BIO *bmem, *b64;
  BUF_MEM *bptr;

  b64 = BIO_new(BIO_f_base64());
  BIO_set_flags(b64, BIO_FLAGS_BASE64_NO_NL);
  bmem = BIO_new(BIO_s_mem());
  b64 = BIO_push(b64, bmem);
  BIO_write(b64, input, length);
  BIO_flush(b64);
  BIO_get_mem_ptr(b64, &bptr);

  std::string output(bptr->data, bptr->length);
  BIO_free_all(b64);

  return output;
}

int main(int argc, char *argv[]) {
  if (argc != 2) {
    std::cerr << "Usage: " << argv[0] << " <password>" << std::endl;
    return 1;
  }

  try {
    std::string password = argv[1];
    auto salt = generate_salt(16);
    int iterations = 100000;
    int outputBytes = 64;

    auto key = pbkdf2_hash(password, salt, iterations, outputBytes);

    std::string encoded_salt = base64_encode(salt.data(), salt.size());
    std::string encoded_key = base64_encode(key.data(), key.size());

    std::cout << encoded_salt << ":" << encoded_key;
  } catch (const std::exception& e) {
    std::cerr << "Error: " << e.what() << std::endl;
    return 1;
  }

  return 0;
}
EOF
)

echo "$qbittorrent_password_generator" > /tmp/qb.cpp
(cd /tmp && g++ -o /usr/sbin/qbittorrent_password_generator qb.cpp -lcrypto)

htpasswd -Bbn admin "$ROOT_PASSWORD" > /etc/nginx/.arrpasswd

qbittorrent_config=$(cat <<EOF
[BitTorrent]
Session\DefaultSavePath=/downloads
Session\ExcludedFileNames=
Session\Interface=wg0
Session\InterfaceName=wg0
Session\Port=50212
Session\QueueingSystemEnabled=false
Session\TempPathEnabled=true

[Preferences]
Advanced\RecheckOnCompletion=false
Advanced\trackerPort=9000
Advanced\trackerPortForwarding=false
Connection\Interface=wg0
WebUI\Address=127.0.0.1
WebUI\Password_PBKDF2="@ByteArray(`/usr/sbin/qbittorrent_password_generator $ROOT_PASSWORD`)"
WebUI\ReverseProxySupportEnabled=true

[RSS]
AutoDownloader\DownloadRepacks=true
AutoDownloader\SmartEpisodeFilter=s(\\d+)e(\\d+), (\\d+)x(\\d+), "(\\d{4}[.\\-]\\d{1,2}[.\\-]\\d{1,2})", "(\\d{1,2}[.\\-]\\d{1,2}[.\\-]\\d{4})"
EOF
)

qbittorrent_systemd=$(cat <<EOF
[Unit]
Description=qBittorrent Command Line Client
After=network.target

[Service]
Type=forking
User=qbittorrent
Group=media
ExecStart=/usr/bin/qbittorrent-nox -d --webui-port=8080
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF
)

write_systemd_config() {
  local name="$1"
  local systemd_config=$(cat <<EOF
[Unit]
Description=$name Daemon
After=syslog.target network.target
[Service]
User=root
Group=media
Type=simple

ExecStart=/opt/$name/$name -nobrowser -data=/var/lib/${name,,}/
TimeoutStopSec=20
KillMode=process
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF
  )

  echo "$systemd_config" > "/etc/systemd/system/${name,,}.service"
}

# Call the function for each service
write_systemd_config "Radarr"
write_systemd_config "Sonarr"
write_systemd_config "Lidarr"
write_systemd_config "Readarr"
write_systemd_config "Whisparr"
write_systemd_config "Prowlarr"


echo "$qbittorrent_systemd" > /etc/systemd/system/qbittorrent.service

systemctl daemon-reload
sudo systemctl enable --now -q radarr
sudo systemctl enable --now -q sonarr
sudo systemctl enable --now -q lidarr
sudo systemctl enable --now -q readarr
sudo systemctl enable --now -q whisparr
sudo systemctl enable --now -q prowlarr
sudo systemctl enable --now -q qbittorrent


sleep 15

sudo systemctl stop radarr
sudo systemctl stop sonarr
sudo systemctl stop lidarr
sudo systemctl stop readarr
sudo systemctl stop whisparr
sudo systemctl stop qbittorrent
(cd /media &&
 mkdir -p radarr sonarr lidarr readarr whisparr)

sleep 5


echo "$qbittorrent_config" > /home/qbittorrent/.config/qBittorrent/qBittorrent.conf

systemctl start qbittorrent

sleep 5

sleep 10

sed -i 's/<BindAddress>.*<\/BindAddress>/<BindAddress>127.0.0.1<\/BindAddress>/' /var/lib/prowlarr/config.xml
sed -i 's/<AuthenticationMethod>None<\/AuthenticationMethod>/<AuthenticationMethod>External<\/AuthenticationMethod>/' /var/lib/prowlarr/config.xml
sed -i 's/<AuthenticationRequired>Enabled<\/AuthenticationRequired>/<AuthenticationRequired>DisabledForLocalAddresses<\/AuthenticationRequired>/' /var/lib/prowlarr/config.xml
prowler_api_key=$(grep '<ApiKey>' /var/lib/prowlarr/config.xml | sed -E 's/.*<ApiKey>(.*)<\/ApiKey>.*/\1/')

apps=("Radarr" "Sonarr" "Readarr" "Lidarr" "Whisparr") 
for app in "${apps[@]}"; do
  config_path="/var/lib/${app,,}/config.xml"
  if [ -f "$config_path" ]; then
    app_lower=$(echo "${app,,}")

    sed -i 's/<BindAddress>.*<\/BindAddress>/<BindAddress>127.0.0.1<\/BindAddress>/' "$config_path"

    if [ "$app_lower" == "readarr" ]; then
      sed -i 's/<AuthenticationMethod>None<\/AuthenticationMethod>/<AuthenticationMethod>None<\/AuthenticationMethod>/' "$config_path"
    else
      sed -i 's/<AuthenticationMethod>None<\/AuthenticationMethod>/<AuthenticationMethod>External<\/AuthenticationMethod>/' "$config_path"
    fi
    sed -i "s/<UrlBase><\/UrlBase>/<UrlBase>\/${app,,}<\/UrlBase>/" "$config_path"

    systemctl enable --now -q ${app,,}
    sleep 5
    api_key=$(grep '<ApiKey>' "$config_path" | sed -E 's/.*<ApiKey>(.*)<\/ApiKey>.*/\1/')
    port=$(grep '<Port>' "$config_path" | sed -E 's/.*<Port>(.*)<\/Port>.*/\1/')


    echo "API Key for $app: $api_key"
    echo "Port for $app: $port"

    if [ "$app_lower" == "lidarr" ] || [ "$app_lower" == "readarr" ]; then
      apilevel=1
    else
      apilevel=3
    fi

    if [ "$app_lower" == "lidarr" ]; then
      curl -X POST "http://127.0.0.1:$port/${app_lower}/api/v${apilevel}/downloadclient" \
      -H "Content-Type: application/json" \
      -H "X-Api-Key: $api_key" \
      -d "{
        \"enable\": true,
        \"protocol\": \"torrent\",
        \"priority\": 1,
        \"removeCompletedDownloads\": true,
        \"removeFailedDownloads\": true,
        \"name\": \"qBittorrent\",
        \"fields\": [
          {\"name\": \"host\", \"value\": \"localhost\"},
          {\"name\": \"port\", \"value\": 8080},
          {\"name\": \"useSsl\", \"value\": false},
          {\"name\": \"urlBase\", \"value\": \"\"},
          {\"name\": \"username\", \"value\": \"admin\"},
          {\"name\": \"password\", \"value\": \"$ROOT_PASSWORD\"},
          {\"name\": \"musicCategory\", \"value\": \"${app,,}\"},
          {\"name\": \"recentMusicPriority\", \"value\": 0},
          {\"name\": \"olderMusicPriority\", \"value\": 0},
          {\"name\": \"initialState\", \"value\": 0},
          {\"name\": \"sequentialOrder\", \"value\": false},
          {\"name\": \"firstAndLast\", \"value\": false},
          {\"name\": \"contentLayout\", \"value\": 0}
        ],
        \"implementationName\": \"qBittorrent\",
        \"implementation\": \"QBittorrent\",
        \"configContract\": \"QBittorrentSettings\",
        \"infoLink\": \"https://wiki.servarr.com/lidarr/supported#qbittorrent\",
        \"tags\": []
      }"
      curl -X POST 'http://127.0.0.1:8686/lidarr/api/v1/rootFolder' \
      -H 'Content-Type: application/json' \
      -H "X-Api-Key: $api_key" \
      -d '{
        "isCalibreLibrary": false,
        "outputProfile": "default",
        "defaultQualityProfileId": 1,
        "defaultMetadataProfileId": 1,
        "defaultMonitorOption": "all",
        "defaultNewItemMonitorOption": "all",
        "defaultTags": [],
        "name": "root",
        "path": "/media/lidarr/"
      }'
    elif [ "$app_lower" == "readarr" ]; then
      curl -X POST "http://127.0.0.1:$port/${app_lower}/api/v${apilevel}/downloadclient" \
      -H "Content-Type: application/json" \
      -H "X-Api-Key: $api_key" \
      -d "{
        \"enable\": true,
        \"protocol\": \"torrent\",
        \"priority\": 1,
        \"removeCompletedDownloads\": true,
        \"removeFailedDownloads\": true,
        \"name\": \"qBittorrent\",
        \"fields\": [
          {\"name\": \"host\", \"value\": \"localhost\"},
          {\"name\": \"port\", \"value\": 8080},
          {\"name\": \"useSsl\", \"value\": false},
          {\"name\": \"username\", \"value\": \"admin\"},
          {\"name\": \"password\", \"value\": \"$ROOT_PASSWORD\"},
          {\"name\": \"musicCategory\", \"value\": \"${app,,}\"},
          {\"name\": \"recentTvPriority\", \"value\": 0},
          {\"name\": \"olderTvPriority\", \"value\": 0},
          {\"name\": \"initialState\", \"value\": 0},
          {\"name\": \"sequentialOrder\", \"value\": false},
          {\"name\": \"firstAndLast\", \"value\": false},
          {\"name\": \"contentLayout\", \"value\": 0}
        ],
        \"implementationName\": \"qBittorrent\",
        \"implementation\": \"QBittorrent\",
        \"configContract\": \"QBittorrentSettings\",
        \"infoLink\": \"https://wiki.servarr.com/readarr/supported#qbittorrent\",
        \"tags\": []
      }"
      curl -X POST 'http://127.0.0.1:8787/readarr/api/v1/rootFolder' \
      -H 'Content-Type: application/json' \
      -H "X-Api-Key: $api_key" \
      -d '{
        "isCalibreLibrary": false,
        "outputProfile": "default",
        "defaultQualityProfileId": 1,
        "defaultMetadataProfileId": 1,
        "defaultMonitorOption": "all",
        "defaultNewItemMonitorOption": "all",
        "defaultTags": [],
        "name": "root",
        "path": "/media/readarr/"
      }'
    else
      curl -X POST "http://127.0.0.1:$port/${app_lower}/api/v${apilevel}/downloadclient" \
      -H "X-Api-Key: $api_key" \
      -H "Content-Type: application/json" \
      --data-raw "{
        \"enable\": true,
        \"protocol\": \"torrent\",
        \"priority\": 1,
        \"categories\": [],
        \"supportsCategories\": true,
        \"name\": \"qBittorrent\", 
        \"fields\": [
          {\"name\": \"host\", \"value\": \"localhost\"},
          {\"name\": \"port\", \"value\": 8080},
          {\"name\": \"useSsl\", \"value\": false},
          {\"name\": \"urlBase\", \"value\": \"\"},
          {\"name\": \"username\", \"value\": \"admin\"},
          {\"name\": \"password\", \"value\": \"$ROOT_PASSWORD\"},
          {\"name\": \"category\", \"value\": \"${app,,}\"},
          {\"name\": \"priority\", \"value\": 0},
          {\"name\": \"initialState\", \"value\": 0},
          {\"name\": \"sequentialOrder\", \"value\": false},
          {\"name\": \"firstAndLast\", \"value\": false},
          {\"name\": \"contentLayout\", \"value\": 0}
        ],
        \"implementationName\": \"QBittorrent\",
        \"implementation\": \"QBittorrent\",
        \"configContract\": \"QBittorrentSettings\",
        \"infoLink\": \"https://wiki.servarr.com/${app,,}/supported#qbittorrent\",
        \"tags\": []
      }"
      curl -X POST "http://127.0.0.1:$port/${app_lower}/api/v${apilevel}/rootFolder" \
      -H 'Content-Type: application/json' \
      -H "X-Api-Key: $api_key" \
      -d "{
        \"name\": \"root\",
        \"path\": \"/media/${app_lower}\",
        \"freeSpace\": 0
      }"
    fi

    curl -X POST "http://localhost:9696/api/v1/applications" \
      -H "X-Api-Key: $prowler_api_key" \
      -H "Content-Type: application/json" \
      --data-raw "{
            \"name\": \"$app\",
            \"fields\": [
              {
                \"name\": \"apiKey\",
                \"type\": \"string\",
                \"value\": \"$api_key\"
              },
              {   
                \"name\": \"baseUrl\",
                \"type\": \"string\",
                \"value\": \"http://127.0.0.1:$port/${app,,}\"
              },
              {
                \"name\": \"prowlarrUrl\",
                \"type\": \"string\",
                \"value\": \"http://127.0.0.1:9696\"
              }
            ],
            \"implementationName\": \"$app\",
            \"infoLink\": \"https://wiki.servarr.com/$app\",
            \"implementation\": \"$app\",
            \"configContract\": \"${app}Settings\",
            \"syncLevel\": \"2\"
          }"
  else
    echo "Configuration file for $app does not exist at $config_path"
  fi
done

curl -X POST "http://127.0.0.1:9696/api/v1/downloadclient" \
-H "X-Api-Key: $prowler_api_key" \
-H "Content-Type: application/json" \
--data-raw "{
  \"enable\": true,
  \"protocol\": \"torrent\",
  \"priority\": 1,
  \"categories\": [],
  \"supportsCategories\": true,
  \"name\": \"qBittorrent\", 
  \"fields\": [
    {\"name\": \"host\", \"value\": \"localhost\"},
    {\"name\": \"port\", \"value\": 8080},
    {\"name\": \"useSsl\", \"value\": false},
    {\"name\": \"urlBase\", \"value\": \"\"},
    {\"name\": \"username\", \"value\": \"admin\"},
    {\"name\": \"password\", \"value\": \"$ROOT_PASSWORD\"},
    {\"name\": \"category\", \"value\": \"prowlarr\"},
    {\"name\": \"priority\", \"value\": 0},
    {\"name\": \"initialState\", \"value\": 0},
    {\"name\": \"sequentialOrder\", \"value\": false},
    {\"name\": \"firstAndLast\", \"value\": false},
    {\"name\": \"contentLayout\", \"value\": 0}
  ],
  \"implementationName\": \"QBittorrent\",
  \"implementation\": \"QBittorrent\",
  \"configContract\": \"QBittorrentSettings\",
  \"infoLink\": \"https://wiki.servarr.com/prowlarr/supported#qbittorrent\",
  \"tags\": []
}"

echo "$prowlarr_qbittorrent_nginx_temp" > /etc/nginx/sites-available/qbittorrent.conf
ln -s /etc/nginx/sites-available/qbittorrent.conf /etc/nginx/sites-enabled/qbittorrent.conf

curl --max-time 2 http://$SERVERNAME
certbot --nginx --agree-tos --email $EMAIL --redirect --expand --non-interactive --nginx-server-root /etc/nginx/ --domain $SERVERNAME
rm /etc/nginx/sites-enabled/qbittorrent.conf
echo "$prowlarr_qbittorrent_nginx" > /etc/nginx/sites-available/qbittorrent.conf
ln -s /etc/nginx/sites-available/qbittorrent.conf /etc/nginx/sites-enabled/qbittorrent.conf

systemctl reload nginx

echo "$TARGET_VERSION" > "${TARGET_MARKER}"
chattr +i "${TARGET_MARKER}"

echo "arr" > "${TARGET_MARKER}.name"

exec "$@"
