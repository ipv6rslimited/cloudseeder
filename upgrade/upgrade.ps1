if ($args.Count -ne 3) {
  Write-Host "Usage: script.ps1 CONTAINER_NAME APPLIANCE_NAME VERSION"
  Exit 1
}

$CONTAINER_NAME = $args[0]
$APPLIANCE_NAME = $args[1]
$VERSION = $args[2]

$backupPath = Join-Path $env:LOCALAPPDATA "ipv6rs\backup.exe"
Write-Host "Running backup for $CONTAINER_NAME..."
$backupResult = Start-Process $backupPath -ArgumentList "backup", $CONTAINER_NAME -NoNewWindow -Wait -PassThru
if ($backupResult.ExitCode -ne 0) {
  Write-Host "Backup failed for $CONTAINER_NAME"
  Exit $backupResult.ExitCode
}

Write-Host "Ensuring the container $CONTAINER_NAME is running..."
$startResult = Start-Process "podman" -ArgumentList "start", $CONTAINER_NAME -NoNewWindow -Wait -PassThru
if ($startResult.ExitCode -ne 0) {
  Write-Host "Failed to start container $CONTAINER_NAME"
  Exit $startResult.ExitCode
}

Write-Host "Fetching and executing upgrade script in $CONTAINER_NAME for $APPLIANCE_NAME to version $VERSION..."
$curlCommand = "curl -fsSL 'https://raw.githubusercontent.com/ipv6rs/cloudseeder-updates/main/appliances/$APPLIANCE_NAME/$VERSION' | bash"
$execResult = Start-Process -FilePath "podman" -ArgumentList "exec", $CONTAINER_NAME, "sh", "-c", "`"$curlCommand`"" -NoNewWindow -Wait -PassThru
if ($execResult.ExitCode -ne 0) {
  Write-Host "Curl command or script execution failed within container $CONTAINER_NAME"
  Exit $execResult.ExitCode
}

$checkerPath = Join-Path $env:LOCALAPPDATA "ipv6rs\checker.exe"
Start-Process $checkerPath -NoNewWindow -Wait -PassThru

Write-Host "All operations completed successfully."
