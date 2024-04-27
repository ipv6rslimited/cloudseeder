#!/bin/bash
INIT_MARKER="/root/.runonce"
SCRIPT_VERSION=1

ipv6rs_timer=$(cat <<EOF
[Unit]
Description=Check IPv6rs Connection 30s

[Timer]
OnBootSec=30
OnUnitActiveSec=30
AccuracySec=1s
Unit=connection_check.service

[Install]
WantedBy=timers.target
EOF
)

ipv6rs_service=$(cat <<EOF
[Unit]
Description=IPv6rs Connection Checker
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
ExecStart=/usr/sbin/check_connection.sh
EOF
)

ipv6rs_checker=$(cat <<'EOF'
#!/bin/bash
INTERFACE=wg0

FULL_IP=$(ip -6 addr show $INTERFACE | grep 'inet6' | grep -v 'scope link' | awk '{print $2}')
IP=${FULL_IP%/*}
PREFIX=${FULL_IP##*/}

function adjust_ipv6() {
  local ip=$1
  local prefix=$2
  local suffix=""
  IFS=':' read -r -a blocks <<< "$ip"

  # Check if the IP starts with the specific prefix and adjust accordingly
  if [[ "$ip" =~ ^2607:a140: ]]; then
    echo "2607:a140:${blocks[2]}::2"
    return 0
  fi

  if [ "$prefix" -eq 64 ]; then
    suffix="::3"
    ip="${blocks[0]}:${blocks[1]}:${blocks[2]}:${blocks[3]}${suffix}"
  else
    echo "Unsupported prefix: $prefix"
    exit 1
  fi

  echo "$ip"
}

if [ "$PREFIX" -eq 128 ]; then
  TARGET_IP=$(adjust_ipv6 $IP 64)
elif [ "$PREFIX" -eq 64 ]; then
  TARGET_IP=$(adjust_ipv6 $IP 40)
else
  echo "Unexpected prefix length: $PREFIX"
  exit 1
fi

echo "Local IP: $IP/$PREFIX"
echo "Target IP: $TARGET_IP"

ATTEMPT=0
MAX_ATTEMPTS=5

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  RESPONSE=$(echo | nc -6w 5 $TARGET_IP 1000)
  RESULT=$?

  if [[ $RESULT -eq 0 ]] && [[ "$RESPONSE" == "OK" ]]; then
    echo "Connection successful and received 'OK'"
    exit 0
  fi

  ((ATTEMPT++))
  echo "Attempt $ATTEMPT failed, trying again..."
done

echo "Connection failed after $MAX_ATTEMPTS attempts, restarting WireGuard interface..."
systemctl restart wg-quick@$INTERFACE
EOF
)

unattended_upgrades=$(cat <<EOF
[Unit]
Description=Run unattended upgrades

[Service]
Type=oneshot
ExecStart=/usr/bin/unattended-upgrade
EOF
)

unattended_upgrades_timer=$(cat <<EOF
[Unit]
Description=Run unattended upgrades daily

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF
)

auto_upgrades_apt=$(cat <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
)

unattended_upgrades_apt=$(cat <<EOF
Unattended-Upgrade::Allowed-Origins {
  "${distro_id}:${distro_codename}-security";
};
Unattended-Upgrade::Automatic-Reboot "true";
EOF
)

initial_setup() {
  echo "Performing initial setup tasks..."

  echo "root:${ROOT_PASSWORD}" | chpasswd

  echo -e "${WGCONFIG}" | tr '%' '\n' > /etc/wireguard/wg0.conf
  systemctl enable --now wg-quick@wg0

  sleep 5

  bash -c /.target.sh
  rm /.target.sh

  systemctl disable sshd.service
  mkdir /var/run/sshd
  sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
  sed -i 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' /etc/pam.d/sshd

  echo "$auto_upgrades_apt" > /etc/apt/apt.conf.d/20auto-upgrades
  echo "$unattended_upgrades_apt" > /etc/apt/apt.conf.d/50unattended-upgrades
  echo "$unattended_upgrades" > /etc/systemd/system/unattended-upgrades.service
  echo "$unattended_upgrades_timer" > /etc/systemd/system/unattended-upgrades.timer
  systemctl enable --now unattended-upgrades.timer

  echo "$ipv6rs_timer" > /etc/systemd/system/connection_check.timer
  echo "$ipv6rs_service" > /etc/systemd/system/connection_check.service
  echo "$ipv6rs_checker" > /usr/sbin/check_connection.sh
  chmod u+x /usr/sbin/check_connection.sh
  systemctl daemon-reload
  systemctl enable --now connection_check.timer
  systemctl start connection_check.service

  echo "$SCRIPT_VERSION" > "${INIT_MARKER}"
  chattr +i "${INIT_MARKER}"
}

if [ ! -f "${INIT_MARKER}" ]; then
  initial_setup
else
  echo "Already run."
fi

exec "$@"
rm -- "$0"
