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
(cd $HOME/.ipv6rs/appliances/lamp/ && podman build -t lamp . && podman run -d \
  --cap-add=NET_ADMIN \
  --device /dev/net/tun \
  --env ROOT_PASSWORD="__PASSWORD" \
  --env WGCONFIG="$(cat __WG | tr '\n' '%')" \
  --name __NAME \
  --security-opt "label=disable" \
  localhost/lamp:latest && podman exec __NAME bash -c /.root.sh)
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

