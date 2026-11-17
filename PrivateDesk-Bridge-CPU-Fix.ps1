# PrivateDesk local PC bridge
# Binds only to IPv4 loopback. Actions are restricted to a fixed allowlist.
# No arbitrary shell commands, paths, or process termination are accepted.

$ErrorActionPreference = 'Stop'
$port = 8765
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $port)

if (-not ('PrivateDesk.Native' -as [type])) {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
namespace PrivateDesk {
  public static class Native {
    [StructLayout(LayoutKind.Sequential)]
    private struct FILETIME { public uint Low; public uint High; }
    [DllImport("kernel32.dll", SetLastError=true)]
    private static extern bool GetSystemTimes(out FILETIME idle, out FILETIME kernel, out FILETIME user);
    private static ulong U(FILETIME t) { return ((ulong)t.High << 32) | t.Low; }
    public static ulong[] ReadCpu() {
      FILETIME i,k,u;
      if (!GetSystemTimes(out i,out k,out u)) throw new System.ComponentModel.Win32Exception();
      return new ulong[] { U(i), U(k), U(u) };
    }
    [DllImport("user32.dll", SetLastError=true)]
    private static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool LockWorkStation();
    public static void TapKey(byte vk) {
      keybd_event(vk, 0, 0, UIntPtr.Zero);
      keybd_event(vk, 0, 2, UIntPtr.Zero);
    }
  }
}
"@
}

$script:previousCpu = [PrivateDesk.Native]::ReadCpu()
$script:cpuPercent = -1
$cpuSampleClock = [System.Diagnostics.Stopwatch]::StartNew()
$computer = [Environment]::MachineName
$osName = (Get-CimInstance -ClassName Win32_OperatingSystem -Property Caption).Caption

function Get-CpuPercent {
    $current = [PrivateDesk.Native]::ReadCpu()
    $old = $script:previousCpu
    $script:previousCpu = $current
    $idleDelta = [double]($current[0] - $old[0])
    $kernelDelta = [double]($current[1] - $old[1])
    $userDelta = [double]($current[2] - $old[2])
    $totalDelta = $kernelDelta + $userDelta
    if ($totalDelta -le 0 -or $idleDelta -gt $totalDelta) { return -1 }
    $busy = 100.0 * (1.0 - ($idleDelta / $totalDelta))
    return [int][math]::Round([math]::Max(0, [math]::Min(100, $busy)))
}

function Get-LaunchAppPath([string]$app) {
    switch ($app) {
        'chrome' {
            $candidates = @(
                (Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe'),
                (Join-Path ${env:ProgramFiles(x86)} 'Google\Chrome\Application\chrome.exe'),
                (Join-Path $env:LOCALAPPDATA 'Google\Chrome\Application\chrome.exe')
            )
            foreach ($candidate in $candidates) { if ($candidate -and (Test-Path -LiteralPath $candidate)) { return $candidate } }
            throw 'Google Chrome was not found on this PC.'
        }
        'calculator' { return (Join-Path $env:WINDIR 'System32\calc.exe') }
        default { throw 'App is not in the approved launch list.' }
    }
}

function Start-ApprovedApp([string]$app) {
    if ($app -in @('chrome','calculator')) {
        $path = Get-LaunchAppPath $app
        Start-Process -FilePath $path | Out-Null
        return
    }

    $expectedNames = switch -CaseSensitive ($app) {
        'spotify' { @('Spotify') }
        'discord' { @('Discord') }
        'claude' { @('Claude') }
        'githubdesktop' { @('GitHub Desktop') }
        'whatsapp' { @('WhatsApp','WhatsApp Beta') }
        default { throw 'App is not in the approved launch list.' }
    }

    $startApps = @(Get-StartApps)
    $entry = $null
    foreach ($expectedName in $expectedNames) {
        $entry = $startApps | Where-Object { $_.Name -eq $expectedName -and $_.AppID } | Select-Object -First 1
        if ($entry) { break }
    }
    if (-not $entry) {
        $displayName = ($expectedNames -join ' or ')
        throw "$displayName was not found in the Windows Start menu. Install it or check its Start menu name."
    }
    $explorer = Join-Path $env:WINDIR 'explorer.exe'
    Start-Process -FilePath $explorer -ArgumentList @("shell:AppsFolder\$($entry.AppID)") | Out-Null
}

function Invoke-ApprovedAction([string]$name) {
    switch -CaseSensitive ($name) {
        'lock' {
            [PrivateDesk.Native]::LockWorkStation() | Out-Null
            return 'PC locked.'
        }
        'shutdown' {
            Start-Process -FilePath (Join-Path $env:WINDIR 'System32\shutdown.exe') -ArgumentList @('/s','/t','60') -WindowStyle Hidden
            return 'Shutdown scheduled in 60 seconds.'
        }
        'restart' {
            Start-Process -FilePath (Join-Path $env:WINDIR 'System32\shutdown.exe') -ArgumentList @('/r','/t','60') -WindowStyle Hidden
            return 'Restart scheduled in 60 seconds.'
        }
        'cancelShutdown' {
            Start-Process -FilePath (Join-Path $env:WINDIR 'System32\shutdown.exe') -ArgumentList @('/a') -WindowStyle Hidden
            return 'Pending shutdown or restart cancelled, if one was scheduled.'
        }
        'launch:chrome' { Start-ApprovedApp 'chrome'; return 'Chrome launched.' }
        'launch:calculator' { Start-ApprovedApp 'calculator'; return 'Calculator launched.' }
        'launch:spotify' { Start-ApprovedApp 'spotify'; return 'Spotify launched.' }
        'launch:discord' { Start-ApprovedApp 'discord'; return 'Discord launched.' }
        'launch:claude' { Start-ApprovedApp 'claude'; return 'Claude launched.' }
        'launch:githubdesktop' { Start-ApprovedApp 'githubdesktop'; return 'GitHub Desktop launched.' }
        'launch:whatsapp' { Start-ApprovedApp 'whatsapp'; return 'WhatsApp launched.' }
        'minimizeAll' {
            $shell = New-Object -ComObject Shell.Application
            try { $shell.MinimizeAll() } finally { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell) }
            return 'All windows minimized.'
        }
        'media:previous' { [PrivateDesk.Native]::TapKey(0xB1); return 'Previous track.' }
        'media:playPause' { [PrivateDesk.Native]::TapKey(0xB3); return 'Play / Pause sent.' }
        'media:next' { [PrivateDesk.Native]::TapKey(0xB0); return 'Next track.' }
        'media:volumeUp' { [PrivateDesk.Native]::TapKey(0xAF); return 'Volume increased.' }
        'media:volumeDown' { [PrivateDesk.Native]::TapKey(0xAE); return 'Volume decreased.' }
        'media:mute' { [PrivateDesk.Native]::TapKey(0xAD); return 'Mute toggled.' }
        default { throw 'This action is not allowed.' }
    }
}

function Send-Response($stream, [int]$status, [string]$contentType, [byte[]]$body) {
    $reason = switch ($status) { 200 {'OK'} 400 {'Bad Request'} 404 {'Not Found'} 405 {'Method Not Allowed'} 500 {'Internal Server Error'} default {'OK'} }
    $header = "HTTP/1.1 $status $reason`r`nContent-Type: $contentType`r`nContent-Length: $($body.Length)`r`nConnection: close`r`nCache-Control: no-store`r`nX-Content-Type-Options: nosniff`r`n`r`n"
    $h = [Text.Encoding]::ASCII.GetBytes($header)
    $stream.Write($h, 0, $h.Length)
    if ($body.Length -gt 0) { $stream.Write($body, 0, $body.Length) }
    $stream.Flush()
}

function Send-Json($stream, [int]$status, $object) {
    $json = $object | ConvertTo-Json -Depth 5 -Compress
    Send-Response $stream $status 'application/json; charset=utf-8' ([Text.Encoding]::UTF8.GetBytes($json))
}

try {
    $listener.Start()
    Write-Host "PrivateDesk bridge is running at http://127.0.0.1:$port/"
    Write-Host 'Approved actions: launch allowlisted apps, minimize all windows, lock, media keys, volume, shutdown/restart with confirmation in the UI.'
    Write-Host 'The server listens on loopback only. Press Ctrl+C to stop.'
    while ($true) {
        if (-not $listener.Pending()) { Start-Sleep -Milliseconds 100; continue }
        $client = $listener.AcceptTcpClient()
        try {
            $client.ReceiveTimeout = 4000
            $client.SendTimeout = 4000
            $stream = $client.GetStream()
            $reader = New-Object System.IO.StreamReader($stream, [Text.Encoding]::ASCII, $false, 1024, $true)
            $requestLine = $reader.ReadLine()
            if ([string]::IsNullOrWhiteSpace($requestLine)) { continue }
            $parts = $requestLine.Split(' ')
            if ($parts.Length -lt 2) { Send-Json $stream 400 @{ok=$false;error='Invalid request.'}; continue }
            $method = $parts[0].ToUpperInvariant()
            $path = $parts[1].Split('?')[0]
            $headers = @{}
            while ($true) {
                $line = $reader.ReadLine()
                if ($null -eq $line -or $line -eq '') { break }
                $colon = $line.IndexOf(':')
                if ($colon -gt 0) { $headers[$line.Substring(0,$colon).Trim().ToLowerInvariant()] = $line.Substring($colon+1).Trim() }
            }

            if ($method -eq 'GET' -and ($path -eq '/' -or $path -eq '/index.html')) {
                $indexPath = Join-Path $PSScriptRoot 'index.html'
                if (-not (Test-Path -LiteralPath $indexPath)) { Send-Json $stream 404 @{ok=$false;error='index.html not found beside the bridge.'}; continue }
                $bytes = [IO.File]::ReadAllBytes($indexPath)
                Send-Response $stream 200 'text/html; charset=utf-8' $bytes
            }
            elseif ($method -eq 'GET' -and $path -eq '/health') {
                if ($cpuSampleClock.ElapsedMilliseconds -ge 1000) {
                    $script:cpuPercent = Get-CpuPercent
                    $cpuSampleClock.Restart()
                }
                Send-Json $stream 200 @{ok=$true;status='ok';computerName=$computer;osName=$osName;cpu=$script:cpuPercent}
            }
            elseif ($method -eq 'GET' -and $path -eq '/processes') {
                $items = @(Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 8 | ForEach-Object {
                    @{name=$_.ProcessName;id=$_.Id;memoryMb=[math]::Round($_.WorkingSet64 / 1MB, 0)}
                })
                Send-Json $stream 200 @{ok=$true;processes=$items}
            }
            elseif ($method -eq 'POST' -and $path -eq '/action') {
                $length = 0
                if ($headers.ContainsKey('content-length')) { [void][int]::TryParse($headers['content-length'], [ref]$length) }
                if ($length -le 0 -or $length -gt 2048) { Send-Json $stream 400 @{ok=$false;error='Invalid request body.'}; continue }
                $buffer = New-Object char[] $length
                $read = 0
                while ($read -lt $length) {
                    $n = $reader.Read($buffer, $read, $length - $read)
                    if ($n -le 0) { break }
                    $read += $n
                }
                if ($read -ne $length) { Send-Json $stream 400 @{ok=$false;error='Incomplete request body.'}; continue }
                try { $body = -join $buffer; $request = $body | ConvertFrom-Json }
                catch { Send-Json $stream 400 @{ok=$false;error='Invalid JSON.'}; continue }
                if ($request.action -isnot [string]) { Send-Json $stream 400 @{ok=$false;error='Missing action.'}; continue }
                try {
                    $message = Invoke-ApprovedAction $request.action
                    Send-Json $stream 200 @{ok=$true;message=$message}
                }
                catch { Send-Json $stream 400 @{ok=$false;error=$_.Exception.Message} }
            }
            elseif ($method -ne 'GET' -and $method -ne 'POST') {
                Send-Json $stream 405 @{ok=$false;error='Method not allowed.'}
            }
            else {
                Send-Json $stream 404 @{ok=$false;error='Not found.'}
            }
            $reader.Dispose()
            $stream.Dispose()
        }
        catch {
            # Close malformed or interrupted client requests without terminating the bridge.
        }
        finally { $client.Close() }
    }
}
finally {
    if ($listener -and $listener.Server.IsBound) { $listener.Stop() }
}
