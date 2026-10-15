# Starts 25 ghost room bots in a background process
$proc = Get-Process ghost_rooms -ErrorAction SilentlyContinue
if ($proc) {
    Write-Host "Ghost rooms bot is ALREADY running (PID: $($proc.Id))." -ForegroundColor Yellow
    Write-Host "To stop it, run: .\stop_ghost_rooms.ps1" -ForegroundColor Cyan
    exit 0
}

$binPath = Join-Path $PSScriptRoot "kita_backend\bin\ghost_rooms.exe"
$srcPath = Join-Path $PSScriptRoot "kita_backend\cmd\ghost_rooms\main.go"

$needsBuild = (-not (Test-Path $binPath)) -or ((Test-Path $srcPath) -and (Get-Item $srcPath).LastWriteTime -gt (Get-Item $binPath).LastWriteTime)
if ($needsBuild) {
    Write-Host "Compiling ghost_rooms.exe with latest changes..." -ForegroundColor Cyan
    Set-Location (Join-Path $PSScriptRoot "kita_backend")
    go build -o bin/ghost_rooms.exe ./cmd/ghost_rooms
    Set-Location $PSScriptRoot
}


Write-Host "Starting ghost rooms..." -ForegroundColor Green
Start-Process -FilePath $binPath -WorkingDirectory (Join-Path $PSScriptRoot "kita_backend") -WindowStyle Hidden

Start-Sleep -Seconds 2
$newProc = Get-Process ghost_rooms -ErrorAction SilentlyContinue
if ($newProc) {
    Write-Host ">>> 25 Ghost Rooms are ACTIVE! (PID: $($newProc.Id)) <<<" -ForegroundColor Green
    Write-Host "To stop them anytime, run: .\stop_ghost_rooms.ps1" -ForegroundColor Cyan
} else {
    Write-Host "Failed to start ghost rooms. Check if backend is running on :8080." -ForegroundColor Red
}
