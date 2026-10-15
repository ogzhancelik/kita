# Stops any running ghost room bots process
$procs = Get-Process ghost_rooms -ErrorAction SilentlyContinue
if ($procs) {
    foreach ($p in $procs) {
        Write-Host "Stopping ghost rooms bot (PID: $($p.Id))..." -ForegroundColor Yellow
        Stop-Process -Id $p.Id -Force
    }
    Write-Host "All ghost rooms have been stopped and removed from lobby." -ForegroundColor Green
} else {
    Write-Host "No ghost rooms process is currently running." -ForegroundColor Cyan
}
