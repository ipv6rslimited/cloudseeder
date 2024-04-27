#!/bin/bash
TARGET_MARKER="/root/.targetonce"
TARGET_VERSION=1

CONFIG=$(cat <<EOF
<VirtualHost *:80>
    ServerName $SERVERNAME
    Redirect permanent / https://$SERVERNAME
    ErrorLog /var/log/apache2/$SERVERNAME-error.log
    CustomLog /var/log/apache2/$SERVERNAME-access.log combined
</VirtualHost>
<IfModule mod_ssl.c>
    <VirtualHost *:443>
        ServerName $SERVERNAME
        DocumentRoot /var/www/html
        ProxyPreserveHost On
        ProxyPass "/.well-known/" "!"
        RequestHeader set X-Forwarded-Proto "https"
        RequestHeader set X-Forwarded-Port "443"
        ProxyPass "/socket" "ws://0.0.0.0:8096/socket"
        ProxyPassReverse "/socket" "ws://0.0.0.0:8096/socket"
        ProxyPass "/" "http://0.0.0.0:8096/"
        ProxyPassReverse "/" "http://0.0.0.0:8096/"
        SSLEngine on
        SSLCertificateFile /etc/letsencrypt/live/$SERVERNAME/fullchain.pem
        SSLCertificateKeyFile /etc/letsencrypt/live/$SERVERNAME/privkey.pem
        Protocols h2 http/1.1
        SSLCipherSuite HIGH:RC4-SHA:AES128-SHA:!aNULL:!MD5
        SSLHonorCipherOrder on
        SSLProtocol all -SSLv2 -SSLv3 -TLSv1 -TLSv1.1
        ErrorLog /var/log/apache2/$SERVERNAME-error.log
        CustomLog /var/log/apache2/$SERVERNAME-access.log combined
    </VirtualHost>
</IfModule>
EOF
)

mkdir -p /var/www/html
systemctl stop apache2
certbot certonly --standalone --agree-tos --email $EMAIL --preferred-challenges http --expand --non-interactive --domain $SERVERNAME
systemctl start apache2
sudo a2enmod proxy proxy_http ssl proxy_wstunnel remoteip http2 headers
echo "$CONFIG" > /etc/apache2/sites-available/jellyfin.conf
sudo a2ensite jellyfin.conf
sudo systemctl restart apache2

echo "$TARGET_VERSION" > "${TARGET_MARKER}"
chattr +i "${TARGET_MARKER}"

echo "jellyfin" > "${TARGET_MARKER}.name"

exec "$@"
