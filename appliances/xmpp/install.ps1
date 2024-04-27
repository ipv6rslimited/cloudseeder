Clear-Host
@"
   ***   *******              *******
    ***   ***  ***           ***    ***
     ***   ***  ***           ***
      ***   ******* ***    *** *********  *** ****    *****
       ***   ***      ***  ***  ***    *** ****  *** ****
        ***   ***       ******   ***   ***  ***         *****
         ***   ***        ****     *******   ***       *****
                     
                     Brought to you by IPv6rs <https://ipv6.rs/>

            *******************************************************
"@
$directoryPath = Join-Path $env:LOCALAPPDATA "ipv6rs\appliances\xmpp\"
$wgConfig = Get-Content "__WG" -Raw |
  ForEach-Object { $_ -replace "`r`n", "`n" } |
  ForEach-Object { $_ -replace "`n", "`%" }
Set-Location $directoryPath
& podman build -t xmpp .
& podman run -d --cap-add NET_ADMIN --volume "/sys/fs/cgroup:/sys/fs/cgroup:ro" --device "/dev/net/tun" --env "ADMIN=__ADMIN" --env "SERVERNAME=__SERVERNAME" --env "EMAIL=__EMAIL" --env "ROOT_PASSWORD=__PASSWORD" --env "WGCONFIG=$wgConfig" --security-opt "label=disable" --name __NAME localhost/xmpp:latest
& podman exec __NAME bash -c /.root.sh
@"
   ***   *******              *******
    ***   ***  ***           ***    ***
     ***   ***  ***           ***
      ***   ******* ***    *** *********  *** ****    *****
       ***   ***      ***  ***  ***    *** ****  *** ****
        ***   ***       ******   ***   ***  ***         *****
         ***   ***        ****     *******   ***       *****
                     
                     Brought to you by IPv6rs <https://ipv6.rs/>

            *******************************************************
"@
Write-Output "To enter your VM type: podman exec -it __NAME /bin/bash"
Write-Output "You can enable an ssh server by typing: systemctl enable --now ssh" 
Write-Output ""
Write-Output "Make sure to login and make your admin account by typing:"
Write-Output "prosodyctl adduser __ADMIN"
Read-Host "Press Enter to continue"



