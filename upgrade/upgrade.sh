#!/bin/bash

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 CONTAINER_NAME APPLIANCE_NAME VERSION"
  exit 1
fi

CONTAINER_NAME=$1
APPLIANCE_NAME=$2
VERSION=$3

echo "Running backup for $CONTAINER_NAME..."
$HOME/.ipv6rs/backup backup "$CONTAINER_NAME"
if [ $? -ne 0 ]; then
  echo "Backup failed for $CONTAINER_NAME"
  exit 1
fi

echo "Ensuring the container $CONTAINER_NAME is running..."
podman start "$CONTAINER_NAME"
if [ $? -ne 0 ]; then
  echo "Failed to start container $CONTAINER_NAME"
  exit 1
fi

echo "Fetching and executing upgrade script in $CONTAINER_NAME for $APPLIANCE_NAME to version $VERSION..."
podman exec "$CONTAINER_NAME" sh -c "curl -fsSL 'https://raw.githubusercontent.com/ipv6rs/cloudseeder-updates/main/appliances/$APPLIANCE_NAME/$VERSION' | bash"
if [ $? -ne 0 ]; then
  echo "Curl command or script execution failed within container $CONTAINER_NAME"
  exit 1
fi

$HOME/.ipv6rs/checker

echo "All operations completed successfully."
