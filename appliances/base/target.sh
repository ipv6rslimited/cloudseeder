#!/bin/bash
TARGET_MARKER="/root/.targetonce"
TARGET_VERSION=1


echo "$TARGET_VERSION" > "${TARGET_MARKER}"
chattr +i "${TARGET_MARKER}"

echo "base" > "${TARGET_MARKER}.name"

exec "$@"
