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

(cd $HOME/.ipv6rs/appliances/ollamaweb/ && podman build -t ollamaweb . && podman run -d \
  --cap-add=NET_ADMIN \
  --volume /sys/fs/cgroup:/sys/fs/cgroup:ro \
  --device /dev/net/tun \
  --env ROOT_PASSWORD="__PASSWORD" \
  --env WGCONFIG="$(cat __WG | tr '\n' '%')" \
  --env SERVERNAME="__SERVERNAME" \
  --env EMAIL="__EMAIL" \
  --name __NAME \
  --security-opt "label=disable" \
  localhost/ollamaweb:latest && podman exec __NAME bash -c /.root.sh)
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
echo
echo Make sure to set your env vars https://github.com/ollama/ollama/blob/main/docs/faq.md#how-do-i-configure-ollama-server
echo and then restart Ollama!
echo
echo Secondly, you will need to set your OLLAMA BASE URL after logging into OpenwebUI.
echo It is either the IP of your LAN interface, like 192.168.x.x, or if you are using
echo a bridge, it may be part of your bridge instead, like 192.168.64.x.
echo
echo

