#!/bin/bash
TARGET_MARKER="/root/.targetonce"
TARGET_VERSION=2

sed -i "s/index.html/index.php index.html/g" "/etc/apache2/mods-enabled/dir.conf"
service apache2 reload

echo "$TARGET_VERSION" > "${TARGET_MARKER}"
chattr +i "${TARGET_MARKER}"

echo "lamp" > "${TARGET_MARKER}.name"

exec "$@"
