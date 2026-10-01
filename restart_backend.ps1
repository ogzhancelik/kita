<#
.SYNOPSIS
    Restarts the Kita Go backend without restarting Cloudflare tunnels.
    Preserves the existing trycloudflare.com URL and active frontend session.

.EXAMPLE
    .\restart_backend.ps1
#>

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BackendDir = Join-Path $ScriptDir "kita_backend"
$RunDir = Join-Path $ScriptDir ".kita_run"
$BackendPidFile = Join-Path $RunDir "backend.pid"
$BackendLog = Join-Path $RunDir "backend.log"
$BackendErrLog = Join-Path $RunDir "backend_err.log"

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host " Restarting Kita Backend (keeping Cloudflare URL)..." -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# 1. Identify and terminate the current backend process
$targetPids = [System.Collections.Generic.List[int]]::new()

if (Test-Path $BackendPidFile) {
    $filePid = Get-Content $BackendPidFile -ErrorAction SilentlyContinue
    if ($filePid -and ($filePid -as [int])) {
        $targetPids.Add([int]$filePid)
    }
}

$netConn = Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue
if ($netConn) {
    foreach ($conn in $netConn) {
        if ($conn.OwningProcess -and -not $targetPids.Contains($conn.OwningProcess)) {
            $targetPids.Add($conn.OwningProcess)
        }
    }
}

# Also check for lingering 'kita_server' or 'main' spawned in kita_backend if not yet found
if ($targetPids.Count -eq 0) {
    $goProcs = Get-Process -Name "kita_server", "main" -ErrorAction SilentlyContinue
    foreach ($gp in $goProcs) {
        $targetPids.Add($gp.Id)
    }
}

foreach ($targetPid in $targetPids) {
    Write-Host "Stopping backend process (PID: $targetPid)..." -ForegroundColor Yellow
    try {
        Start-Process -FilePath "taskkill.exe" -ArgumentList "/F", "/T", "/PID", $targetPid -NoNewWindow -Wait -ErrorAction SilentlyContinue
        Stop-Process -Id $targetPid -Force -ErrorAction SilentlyContinue
    } catch {}
}

# Wait for port 8080 to become free
$timeout = 10
while ($timeout -gt 0) {
    $stillListening = Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue
    if (-not $stillListening) { break }
    Start-Sleep -Milliseconds 500
    $timeout--
}

# 2. Start the new Go backend process
if (-not (Test-Path $RunDir)) {
    New-Item -ItemType Directory -Path $RunDir | Out-Null
}

Write-Host "Building Kita backend..." -ForegroundColor DarkGray
Push-Location $BackendDir
try {
    & go build -o "kita_server.exe" "./cmd/api/main.go"
    $buildExit = $LASTEXITCODE
} finally {
    Pop-Location
}

if ($buildExit -ne 0) {
    Write-Host "Error: Go build failed! Aborting restart." -ForegroundColor Red
    exit 1
}

$exePath = Join-Path $BackendDir "kita_server.exe"
$newBackendProc = Start-Process $exePath -WorkingDirectory $BackendDir -RedirectStandardOutput $BackendLog -RedirectStandardError $BackendErrLog -PassThru -NoNewWindow
Set-Content -Path $BackendPidFile -Value $newBackendProc.Id

Start-Sleep -Seconds 2

if ($newBackendProc.HasExited) {
    Write-Host "Error: Backend failed to start! Recent logs:" -ForegroundColor Red
    if (Test-Path $BackendErrLog) { Get-Content $BackendErrLog -Tail 15 }
    if (Test-Path $BackendLog) { Get-Content $BackendLog -Tail 15 }
    exit 1
}

Write-Host "Backend restarted successfully (New PID: $($newBackendProc.Id))!" -ForegroundColor Green
Write-Host "Cloudflare tunnel & trycloudflare.com URL remain intact!" -ForegroundColor Green
Write-Host "Real-time logs: Get-Content .kita_run\backend.log -Wait -Tail 20" -ForegroundColor DarkGray
exit 0
