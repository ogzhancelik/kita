# Stops any running ghost room bots process
$targetScript = Join-Path $PSScriptRoot "docs\stop_ghost_rooms.ps1"
if (Test-Path $targetScript) {
    & $targetScript @args
} else {
    Write-Host "Could not find docs\stop_ghost_rooms.ps1" -ForegroundColor Red
}
