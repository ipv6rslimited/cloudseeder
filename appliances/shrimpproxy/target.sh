#!/bin/bash
TARGET_MARKER="/root/.targetonce"
TARGET_VERSION=1

shrimp_lockdown=$(cat << 'EOF'
#!/bin/bash

if [ ! -f "shrimp.conf" ]; then
  echo "Configuration file not found!"
  exit 1
fi

current_value=$(grep '"lockdownMode"' "shrimp.conf" | awk -F': ' '{print $2}' | tr -d ',"')

if [ "$current_value" = "true" ]; then
  new_value="false"
else
  new_value="true"
fi

sed -i "s/\"lockdownMode\": $current_value/\"lockdownMode\": $new_value/" "shrimp.conf"

systemctl restart shrimp

echo "lockdownMode set to $new_value"
EOF
)

shrimp_systemd=$(cat <<EOF
[Unit]
Description=shrimp proxy
After=remote-fs.target network.target
  
[Install]
WantedBy=multi-user.target
  
[Service]
User=root
Type=simple
ExecStart=/root/shrimp
WorkingDirectory=/root
TimeoutStopSec=20
KillMode=process
Restart=on-failure
EOF
)

ip_address=$(ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

INTERFACE=wg0

FULL_IP=$(ip -6 addr show $INTERFACE | grep 'inet6' | grep -v 'scope link' | awk '{print $2}')
IP=${FULL_IP%/*}
PREFIX=${FULL_IP##*/}

function adjust_ipv6() {
  local ip=$1
  local prefix=$2

  IFS=':' read -r -a blocks <<< "$ip"

  if [[ "$ip" =~ ^2607:a140: ]]; then
    echo "2607:a140:${blocks[2]}::2"
  else
    echo "Unsupported prefix: $prefix"
    exit 1
  fi
}

if [ "$PREFIX" -eq 128 ]; then
  TARGET_IP=$(adjust_ipv6 $IP $PREFIX)
else
  echo "Unexpected prefix length: $PREFIX"
  exit 1
fi

shrimp_config=$(cat <<EOF
{
  "listenAddrs": ["[::]:443"],
  "plaintextAddr": "$ip_address:3128",
  "lockdownMode": false,
  "ipv6Interface": "wg0",
  "dns64Server": "$TARGET_IP",
  "credentialsFile": "passwd",
  "debugMode": false,
  "certFile": "/etc/letsencrypt/live/$SERVERNAME/fullchain.pem",
  "keyFile": "/etc/letsencrypt/live/$SERVERNAME/privkey.pem",
  "ipv4Translator": "visibleip.com",
  "dnsCacheCapacity": 100,
  "dnsTTL": 300,
  "allowedHosts": [".*"],
  "disallowedHosts": [
    "^localhost\$",
    "^127\\\\.0\\\\.0\\\\.1\$",
    "^10\\\\.",
    "^172\\\\.(1[6-9]|2[0-9]|3[0-1])\\\\.",
    "^192\\\\.168\\\\."
  ]
}
EOF
)

echo "export PATH=$PATH:/usr/local/go/bin" >> /root/.profile
source /root/.profile
cd root/shrimp_src
go mod tidy
go build shrimp.go
cd util
go mod tidy
go build mkpasswd.go
mv mkpasswd /root
cd ..
mv shrimp /root
echo "$shrimp_config" > /root/shrimp.conf
touch /root/passwd
echo "$shrimp_systemd" > /etc/systemd/system/shrimp.service
systemctl daemon-reload

certbot certonly --agree-tos --email $EMAIL --redirect --non-interactive --standalone --preferred-challenges http --domain $SERVERNAME

systemctl enable --now shrimp

echo "$shrimp_lockdown" > /root/lockdown.sh
chmod u+x /root/lockdown.sh

echo "$TARGET_VERSION" > "${TARGET_MARKER}"
chattr +i "${TARGET_MARKER}"

echo "squidproxy" > "${TARGET_MARKER}.name"

exec "$@"
