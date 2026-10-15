# Starts 25 ghost room bots in a background process
$targetScript = Join-Path $PSScriptRoot "docs\start_ghost_rooms.ps1"
if (Test-Path $targetScript) {
    & $targetScript @args
} else {
    Write-Host "Could not find docs\start_ghost_rooms.ps1" -ForegroundColor Red
}
