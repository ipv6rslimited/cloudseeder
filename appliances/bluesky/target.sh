#!/bin/bash
TARGET_MARKER="/root/.targetonce"
TARGET_VERSION=2

curl https://raw.githubusercontent.com/bluesky-social/pds/v0.4.12/installer.sh >installer.sh

chmod u+x installer.sh
echo "N"  | ./installer.sh /pds $SERVERNAME $ADMINEMAIL

echo "$TARGET_VERSION" > "${TARGET_MARKER}"
chattr +i "${TARGET_MARKER}"

echo "bluesky" > "${TARGET_MARKER}.name"

exec "$@"
