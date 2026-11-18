
# PrivateDesk ADB Watcher
# Uses the exact ADB executable used by Unity.
# Never kills or restarts the ADB server.

$ErrorActionPreference = 'Continue'

$adbPath = "C:\Program Files\Unity\Hub\Editor\6000.3.21f1\Editor\Data\PlaybackEngines\AndroidPlayer\SDK\platform-tools\adb.exe"
$phoneSerial = "7b486809"

if (-not (Test-Path -LiteralPath $adbPath)) {
    Write-Host "Unity ADB not found: $adbPath"
    exit 1
}

Write-Host "PrivateDesk ADB Watcher started."
Write-Host "ADB: $adbPath"
Write-Host "Device: $phoneSerial"

while ($true) {
    try {
        $state = & $adbPath -s $phoneSerial get-state 2>$null
        $connected = ($LASTEXITCODE -eq 0 -and ($state -join "").Trim() -eq "device")

        if ($connected) {
            $reverseList = & $adbPath -s $phoneSerial reverse --list 2>$null

            if ($LASTEXITCODE -eq 0) {
                $mappingExists = $reverseList -match 'tcp:8765\s+tcp:8765'

                if (-not $mappingExists) {
                    Write-Host "Restoring PrivateDesk USB connection..."
                    & $adbPath -s $phoneSerial reverse tcp:8765 tcp:8765
                }
            }
        }
    }
    catch {
        Write-Host "Watcher error: $($_.Exception.Message)"
    }

    Start-Sleep -Seconds 3
}
