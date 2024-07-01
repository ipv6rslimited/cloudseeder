#!/bin/bash
TARGET_MARKER="/root/.targetonce"
TARGET_VERSION=2

eula_script=$(cat <<EOF
#!/bin/bash

cat /root/eula.txt

echo "Do you agree to the EULA? (yes/no)"
read response

if [[ "\$response" == "yes" ]]; then
  sed -i 's/eula=false/eula=true/' /root/eula.txt
  echo "Minecraft is now running."
  systemctl start minecraft
elif [[ "\$response" == "no" ]]; then
  echo "You did not agree to the EULA. Exiting."
else
  echo "Invalid response. Please enter 'yes' or 'no'. Exiting."
fi

EOF
)

minecraft_systemd=$(cat <<EOF 
[Unit]
Description=Minecraft
After=network.target
 
[Service]
User=root
Group=root
WorkingDirectory=/root/
ExecStart=java -Xms1024M -Xmx4G -jar server.jar nogui
Restart=always
  
[Install]
WantedBy=multi-user.target
EOF
)



(cd /root && java -Xms1024M -Xmx1024M -jar server.jar nogui)

echo "$eula_script" > /root/eula.sh
chmod u+x /root/eula.sh

echo "$minecraft_systemd" > /etc/systemd/system/minecraft.service

systemctl daemon-reload
systemctl enable minecraft

echo "$TARGET_VERSION" > "${TARGET_MARKER}"
chattr +i "${TARGET_MARKER}"

echo "minecraft" > "${TARGET_MARKER}.name"

exec "$@"
