
@echo off
title Stop PrivateDesk Bridge
echo Stopping PrivateDesk Bridge...

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$p = Get-CimInstance Win32_Process -Filter \"Name='powershell.exe' OR Name='pwsh.exe'\" | Where-Object { $_.CommandLine -match 'PrivateDesk-Bridge' }; if ($p) { $p | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }; Write-Host 'Bridge stopped.' } else { Write-Host 'No running PrivateDesk Bridge found.' }"

pause
