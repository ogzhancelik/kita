# Starts 25 ghost room bots in a background process
$proc = Get-Process ghost_rooms -ErrorAction SilentlyContinue
if ($proc) {
    Write-Host "Ghost rooms bot is ALREADY running (PID: $($proc.Id))." -ForegroundColor Yellow
    Write-Host "To stop it, run: .\stop_ghost_rooms.ps1" -ForegroundColor Cyan
    exit 0
}

$projectRoot = $PSScriptRoot
if (-not (Test-Path (Join-Path $projectRoot "kita_backend"))) {
    $parent = Split-Path -Parent $projectRoot
    if (Test-Path (Join-Path $parent "kita_backend")) {
        $projectRoot = $parent
    }
}

$backendDir = Join-Path $projectRoot "kita_backend"
$binPath = Join-Path $backendDir "bin\ghost_rooms.exe"
$srcPath = Join-Path $backendDir "cmd\ghost_rooms\main.go"

$needsBuild = (-not (Test-Path $binPath)) -or ((Test-Path $srcPath) -and (Get-Item $srcPath).LastWriteTime -gt (Get-Item $binPath).LastWriteTime)
if ($needsBuild) {
    Write-Host "Compiling ghost_rooms.exe with latest changes..." -ForegroundColor Cyan
    $origLoc = Get-Location
    Set-Location $backendDir
    go build -o bin/ghost_rooms.exe ./cmd/ghost_rooms
    Set-Location $origLoc
}


$runDir = Join-Path $projectRoot ".kita_run"
if (-not (Test-Path $runDir)) { New-Item -ItemType Directory -Path $runDir -Force | Out-Null }
$outLog = Join-Path $runDir "ghost_rooms.log"
$errLog = Join-Path $runDir "ghost_rooms_err.log"

Write-Host "Starting ghost rooms..." -ForegroundColor Green
Start-Process -FilePath $binPath -WorkingDirectory $backendDir -RedirectStandardOutput $outLog -RedirectStandardError $errLog -WindowStyle Hidden

Start-Sleep -Seconds 2
$newProc = Get-Process ghost_rooms -ErrorAction SilentlyContinue
if ($newProc) {
    Write-Host ">>> 25 Ghost Rooms are ACTIVE! (PID: $($newProc.Id)) <<<" -ForegroundColor Green
    Write-Host "To stop them anytime, run: .\stop_ghost_rooms.ps1" -ForegroundColor Cyan
} else {
    Write-Host "Failed to start ghost rooms. Check if backend is running on :8080." -ForegroundColor Red
    if (Test-Path $errLog) {
        Get-Content $errLog -Tail 10
    }
}
