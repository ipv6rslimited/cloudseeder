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
(cd $HOME/.ipv6rs/appliances/nostr/ && podman build -t nostr . && podman run -d \
  --cap-add=NET_ADMIN \
  --volume /sys/fs/cgroup:/sys/fs/cgroup:ro \
  --device /dev/net/tun \
  --env ROOT_PASSWORD="__PASSWORD" \
  --env WGCONFIG="$(cat __WG | tr '\n' '%')" \
  --env SERVERNAME="__SERVERNAME" \
  --env EMAIL="__EMAIL" \
  --env CONTACTEMAIL="__CONTACTEMAIL" \
  --env PUBKEY="__PUBKEY" \
  --name __NAME \
  --security-opt "label=disable" \
  localhost/nostr:latest && podman exec __NAME bash -c /.root.sh)
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
echo Your relay is at wss://__SERVERNAME/
echo It is setup so that only you can post to it!
echo
echo

