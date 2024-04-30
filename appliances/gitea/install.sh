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
(cd $HOME/.ipv6rs/appliances/gitea/ && podman build -t gitea . && podman run -d \
  --cap-add=NET_ADMIN \
  --volume /sys/fs/cgroup:/sys/fs/cgroup:ro \
  --device /dev/net/tun \
  --env ROOT_PASSWORD="__PASSWORD" \
  --env WGCONFIG="$(cat __WG | tr '\n' '%')" \
  --env SERVERNAME="__SERVERNAME" \
  --env EMAIL="__EMAIL" \
  --name __NAME \
  --security-opt "label=disable" \
  localhost/gitea:latest && podman exec __NAME bash -c /.root.sh)
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
echo Finish setup at: https://__SERVERNAME/
echo Password for DB is in root folder /root/.gitea_db_password
echo
echo

