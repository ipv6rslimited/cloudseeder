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
$directoryPath = Join-Path $env:LOCALAPPDATA "ipv6rs\appliances\shrimpproxy\"
$wgConfig = Get-Content "__WG" -Raw |
  ForEach-Object { $_ -replace "`r`n", "`n" } |
  ForEach-Object { $_ -replace "`n", "`%" }
Set-Location $directoryPath
& podman build -t shrimpproxy .
& podman run -d --cap-add NET_ADMIN --volume "/sys/fs/cgroup:/sys/fs/cgroup:ro" --device "/dev/net/tun" -p "127.0.0.1:3128:3128" --env "SERVERNAME=__SERVERNAME" --env "EMAIL=__EMAIL" --env "ROOT_PASSWORD=__PASSWORD" --env "WGCONFIG=$wgConfig" --security-opt "label=disable" --name __NAME localhost/shrimpproxy:latest
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
Write-Output "Finish setup at by creating a user and restarting the proxy:"
Write-Output "In cd /root, type ./mkpasswd -create username passwrd"
Write-Output "systemctl restart shrimp"
Write-Output ""
Write-Output "You can toggle lockdown mode with ./lockdown.sh"
Write-Output ""
Read-Host "Press Enter to continue"

