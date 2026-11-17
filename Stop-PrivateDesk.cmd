
@echo off
powershell.exe -NoProfile -Command "$names = @('PrivateDesk-Bridge-CPU-Fix.ps1','Watch-PrivateDesk-ADB.ps1'); $p = Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'powershell.exe' -and ($names | Where-Object { $_.CommandLine -like ('*' + $_ + '*') }) }; if ($p) { $p | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }; Write-Host 'PrivateDesk stopped.' } else { Write-Host 'PrivateDesk is not running.' }"
echo.
pause
