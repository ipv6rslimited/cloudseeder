#!/bin/bash
TARGET_MARKER="/root/.targetonce"
TARGET_VERSION=3

noble_support_patch_file=$(cat <<'EOF'
@@ -95,7 +95,10 @@
       echo "* Detected supported distribution Ubuntu 22.04 LTS"
     elif [[ "${DISTRIB_CODENAME}" == "mantic" ]]; then
       SUPPORTED_OS="true"
-      echo "* Detected supported distribution Ubuntu 23.10 LTS"
+      echo "* Detected supported distribution Ubuntu 23.10"
+    elif [[ "${DISTRIB_CODENAME}" == "noble" ]]; then
+      SUPPORTED_OS="true"
+      echo "* Detected supported distribution Ubuntu 24.04 LTS"
     fi
   elif [[ "${DISTRIB_ID}" == "debian" ]]; then
     if [[ "${DISTRIB_CODENAME}" == "bullseye" ]]; then
EOF
)

echo "$noble_support_patch_file" > noble_support.patch

curl https://raw.githubusercontent.com/bluesky-social/pds/v0.4.107/installer.sh >installer.sh

patch -u installer.sh -i noble_support.patch

chmod u+x installer.sh
echo "N"  | ./installer.sh /pds $SERVERNAME $ADMINEMAIL

echo "$TARGET_VERSION" > "${TARGET_MARKER}"
chattr +i "${TARGET_MARKER}"

echo "bluesky" > "${TARGET_MARKER}.name"

exec "$@"
