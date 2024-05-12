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
$directoryPath = Join-Path $env:LOCALAPPDATA "ipv6rs\appliances\arr\"
$wgConfig = Get-Content "__WG" -Raw |
  ForEach-Object { $_ -replace "`r`n", "`n" } |
  ForEach-Object { $_ -replace "`n", "`%" }
Set-Location $directoryPath
& podman build -t arr .
& podman run -d --cap-add NET_ADMIN --volume "/sys/fs/cgroup:/sys/fs/cgroup:ro" --device "/dev/net/tun" --env "SERVERNAME=__SERVERNAME" --env "EMAIL=__EMAIL" --env "ROOT_PASSWORD=__PASSWORD" --env "WGCONFIG=$wgConfig" --volume "__FOLDER:/media:rw" --security-opt "label=disable" --name __NAME localhost/arr:latest
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
Write-Output "Finish setup at: https://__SERVERNAME/"
Write-Output "You can visit all your *Arr apps at /<app> like /radarr"
Write-Output "QBittorrent is available at /qbittorrent locked to IPv6rs"
Write-Output "Your password for QBittorrent and the server is your root password."
Read-Host "Press Enter to continue"

