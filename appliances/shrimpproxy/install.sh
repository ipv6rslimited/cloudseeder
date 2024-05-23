#!/bin/bash
clear
echo
echo '   ***   *******              *******'
echo '    ***   ***  ***           ***    ***'
echo '     ***   ***  ***           ***'
echo '      ***   ******* ***    *** *********  *** ****    *****'
echo '       ***   ***      ***  ***  ***    *** ****  *** ****'
echo '        ***   ***       ******   ***   ***  ***         *****'
echo '         ***   ***        ****     *******   ***       *****'
echo
echo '                     Brought to you by IPv6rs <https://ipv6.rs/>'
echo
echo '            *******************************************************'
echo
echo
echo
(cd $HOME/.ipv6rs/appliances/shrimpproxy/ && podman build -t shrimpproxy . && podman run -d \
  -p 127.0.0.1:3128:3128 \
  --cap-add=NET_ADMIN \
  --volume /sys/fs/cgroup:/sys/fs/cgroup:ro \
  --device /dev/net/tun \
  --env ROOT_PASSWORD="__PASSWORD" \
  --env WGCONFIG="$(cat __WG | tr '\n' '%')" \
  --env SERVERNAME="__SERVERNAME" \
  --env EMAIL="__EMAIL" \
  --name __NAME \
  --security-opt "label=disable" \
  localhost/shrimpproxy:latest && podman exec __NAME bash -c /.root.sh)
echo
echo
echo
echo
echo '   ***   *******              *******'
echo '    ***   ***  ***           ***    ***'
echo '     ***   ***  ***           ***'
echo '      ***   ******* ***    *** *********  *** ****    *****'
echo '       ***   ***      ***  ***  ***    *** ****  *** ****'
echo '        ***   ***       ******   ***   ***  ***         *****'
echo '         ***   ***        ****     *******   ***       *****'
echo
echo '                     Brought to you by IPv6rs <https://ipv6.rs/>'
echo
echo '            *******************************************************'
echo
echo
echo
echo To enter your VM type: podman exec -it __NAME /bin/bash
echo You can enable an ssh server by typing: systemctl enable --now ssh
echo
echo Finish setup at by creating a user and restarting the proxy:
echo In cd /root, type ./mkpasswd -create username passwrd
echo systemctl restart shrimp
echo
echo You can toggle lockdown mode with ./lockdown.sh
echo
echo

