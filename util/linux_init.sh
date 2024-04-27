#!/bin/bash
REQUIRED_VERSION="1.14.4"
REQUIRED_VERSION_PARTS=(${REQUIRED_VERSION//./ })

version_lt() {
  local IFS=.
  local i ver1=($1) ver2=($2)

  for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
    ver1[i]=0
  done
  for ((i=0; i<${#ver1[@]}; i++)); do
    if ((10#${ver1[i]} < 10#${ver2[i]})); then
      return 0
    elif ((10#${ver1[i]} > 10#${ver2[i]})); then
      return 1
    fi
  done
  return 1
}

ARCH=$(uname -m)
case "$ARCH" in
  x86_64) CRUN_ARCH="amd64" ;;
  arm*) CRUN_ARCH="arm" ;;
  aarch64) CRUN_ARCH="arm64" ;;
  *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

INSTALL_PATH="${HOME}/.local/bin/crun"

if [ -x "$INSTALL_PATH" ]; then
  CURRENT_VERSION=$("${INSTALL_PATH}" --version | head -n 1 | awk '{print $3}')
  if [ $? -ne 0 ]; then
    echo "Error executing ${INSTALL_PATH} --version"
    exit 1
  fi

  if version_lt $CURRENT_VERSION $REQUIRED_VERSION; then
    echo "Current crun version (${CURRENT_VERSION}) at ${INSTALL_PATH} is less than ${REQUIRED_VERSION}, updating..."
  else
    echo "Current crun version (${CURRENT_VERSION}) at ${INSTALL_PATH} meets or exceeds the requirement. No need to update."
    exit 0
  fi
else
  echo "crun is not installed at ${INSTALL_PATH}, proceeding with installation."
fi

DOWNLOAD_URL="https://github.com/containers/crun/releases/download/${REQUIRED_VERSION}/crun-${REQUIRED_VERSION}-linux-${CRUN_ARCH}"
mkdir -p "$(dirname "${INSTALL_PATH}")"

curl -L "${DOWNLOAD_URL}" -o "${INSTALL_PATH}"
chmod +x "${INSTALL_PATH}"
echo "crun installed/updated successfully to version ${REQUIRED_VERSION} at ${INSTALL_PATH}."

CONFIG_PATH="${HOME}/.config/containers/containers.conf"
mkdir -p "$(dirname "${CONFIG_PATH}")"
cat <<EOF >"${CONFIG_PATH}"
[engine.runtimes]
crun = [
  "${INSTALL_PATH}",
  "/usr/bin/crun"
]
EOF

echo "containers.conf configured successfully."

