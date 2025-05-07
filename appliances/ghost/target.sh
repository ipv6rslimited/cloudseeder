#!/bin/bash
TARGET_MARKER="/root/.targetonce"
TARGET_VERSION=16

DBPASSWORD=$(< /dev/urandom tr -dc 'A-Za-z0-9' | head -c20)
echo "casper" > /root/.ghost_username
echo "$DBPASSWORD" > /root/.ghost_db_password
chmod 600 /root/.ghost_db_password
mysql -u root -e "
 ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${DBPASSWORD}';
 FLUSH PRIVILEGES;"
systemctl restart mysql
mkdir -p /var/www/$SERVERNAME
chown "casper:casper" /var/www/$SERVERNAME
chmod 775 /var/www/$SERVERNAME
curl --max-time 2 http://$SERVERNAME
su - casper -c "PATH=/usr/bin:$PATH cd /var/www/$SERVERNAME && ghost install --db=mysql --dbhost=localhost --dbname=ghost --dbuser=root --dbpass=$DBPASSWORD --url=https://$SERVERNAME --process=systemd --no-prompt --sslemail=$EMAIL 5.118.0"

echo "$TARGET_VERSION" > "${TARGET_MARKER}"
chattr +i "${TARGET_MARKER}"

echo "ghost" > "${TARGET_MARKER}.name"

exec "$@"
