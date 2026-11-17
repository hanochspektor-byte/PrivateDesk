
$adbPath = "C:\Users\user\GamesDeveloping\platform-tools-latest-windows\platform-tools\adb.exe"
$phoneSerial = "7b486809"

if (-not (Test-Path $adbPath)) {
    Write-Host "ADB not found: $adbPath"
    exit 1
}

$wasConnected = $false

while ($true) {
    $state = & $adbPath -s $phoneSerial get-state 2>$null
    $connected = ($LASTEXITCODE -eq 0 -and ($state -join "").Trim() -eq "device")

    if ($connected -and -not $wasConnected) {
        & $adbPath -s $phoneSerial reverse tcp:8765 tcp:8765
    }

    $wasConnected = $connected
    Start-Sleep -Seconds 3
}
