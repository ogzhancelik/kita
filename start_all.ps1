<#
==============================================================================
 Kita Fullstack Runner (PowerShell)
 Starts Go backend and Flutter web-server.

 Usage:
   .\start_all.ps1              # Local / LAN mode (http://<ip>:3000)
   .\start_all.ps1 -Tunnel      # Public Cloudflare Tunnel mode (trycloudflare.com)
   .\start_all.ps1 -t           # Alias for -Tunnel
==============================================================================
#>
param(
    [switch]$Tunnel,
    [switch]$t,
    [switch]$Help
)

if ($Help) {
    Write-Host "Usage: .\start_all.ps1 [-Tunnel | -t]"
    Write-Host "  (no args) : Runs locally on 0.0.0.0:3000 and prints your LAN IP"
    Write-Host "  -Tunnel   : Exposes backend and frontend via Cloudflare Tunnels"
    exit 0
}

$IsTunnel = $Tunnel -or $t

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BackendDir = Join-Path $ScriptDir "kita_backend"
$FrontendDir = Join-Path $ScriptDir "kita_frontend"
$RunDir = Join-Path $ScriptDir ".kita_run"

if (-not (Test-Path $RunDir)) {
    New-Item -ItemType Directory -Path $RunDir | Out-Null
}

$BackendLog = Join-Path $RunDir "backend.log"
$BackendPidFile = Join-Path $RunDir "backend.pid"
$CfBackendLog = Join-Path $RunDir "cf_backend.log"
$CfFrontendLog = Join-Path $RunDir "cf_frontend.log"

$processes = [System.Collections.Generic.List[System.Diagnostics.Process]]::new()

function Free-Port([int]$Port) {
    $connections = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    if ($connections) {
        foreach ($conn in $connections) {
            if ($conn.OwningProcess -and $conn.OwningProcess -gt 0) {
                Write-Host "Releasing port $Port held by PID $($conn.OwningProcess)..." -ForegroundColor Yellow
                try {
                    Start-Process -FilePath "taskkill.exe" -ArgumentList "/F", "/T", "/PID", $conn.OwningProcess -NoNewWindow -Wait -ErrorAction SilentlyContinue
                } catch {
                    Stop-Process -Id $conn.OwningProcess -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
}

function Cleanup {
    Write-Host "`n====================================================" -ForegroundColor Yellow
    Write-Host " Shutting down Kita services..." -ForegroundColor Yellow
    Write-Host "====================================================" -ForegroundColor Yellow
    foreach ($p in $processes) {
        if ($p -and -not $p.HasExited) {
            try {
                Start-Process -FilePath "taskkill.exe" -ArgumentList "/F", "/T", "/PID", $p.Id -NoNewWindow -Wait -ErrorAction SilentlyContinue
                Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
            } catch {}
        }
    }
    if (Test-Path $BackendPidFile) {
        $restartedPid = Get-Content $BackendPidFile -ErrorAction SilentlyContinue
        if ($restartedPid) {
            try {
                Start-Process -FilePath "taskkill.exe" -ArgumentList "/F", "/T", "/PID", $restartedPid -NoNewWindow -Wait -ErrorAction SilentlyContinue
                Stop-Process -Id $restartedPid -Force -ErrorAction SilentlyContinue
            } catch {}
        }
    }
    Free-Port 8080
    Free-Port 3000
    Remove-Item -Path $RunDir -Recurse -Force -ErrorAction SilentlyContinue
    Set-Location $ScriptDir
    Write-Host "All services stopped. Bye!" -ForegroundColor Green
}

# Helper: Detect LAN IP
function Get-LocalIP {
    $ip = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.InterfaceAlias -match 'Wi-Fi|Ethernet' -and $_.IPAddress -notmatch '^127\.' } |
        Select-Object -ExpandProperty IPAddress | Select-Object -First 1)
    if (-not $ip) {
        $ip = "localhost"
    }
    return $ip
}

# Helper: Extract Cloudflare URL from log file
function Extract-TunnelUrl([string]$logFile, [string]$serviceName, [int]$timeoutSec = 30) {
    Write-Host -NoNewline "  Waiting for $serviceName tunnel URL..."
    $elapsed = 0
    while ($elapsed -lt $timeoutSec) {
        if (Test-Path $logFile) {
            $match = Select-String -Path $logFile -Pattern 'https://[-a-zA-Z0-9]+\.trycloudflare\.com' | Select-Object -First 1
            if ($match) {
                Write-Host " Ready!" -ForegroundColor Green
                return $match.Matches[0].Value
            }
        }
        Start-Sleep -Seconds 1
        $elapsed++
        Write-Host -NoNewline "."
    }
    Write-Host " Failed (timeout)!" -ForegroundColor Red
    return $null
}

try {
    $LocalIP = Get-LocalIP

    # Ensure ports are clear of stale processes before starting
    Free-Port 8080

    # 1. Start Go Backend
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host " [1/3] Starting Kita Backend (Go / Gin)..." -ForegroundColor Cyan
    Write-Host "====================================================" -ForegroundColor Cyan

    $backendPsi = New-Object System.Diagnostics.ProcessStartInfo
    $backendPsi.FileName = "go"
    $backendPsi.Arguments = "run ./cmd/api/main.go"
    $backendPsi.WorkingDirectory = $BackendDir
    $backendPsi.RedirectStandardOutput = $true
    $backendPsi.RedirectStandardError = $true
    $backendPsi.UseShellExecute = $false
    $backendPsi.CreateNoWindow = $true

    $backendProc = [System.Diagnostics.Process]::Start($backendPsi)
    $processes.Add($backendProc)
    Set-Content -Path $BackendPidFile -Value $backendProc.Id

    # Stream output to log file asynchronously
    Register-ObjectEvent -InputObject $backendProc -EventName OutputDataReceived -Action {
        if ($EventArgs.Data) { Add-Content -Path $using:BackendLog -Value $EventArgs.Data }
    } | Out-Null
    Register-ObjectEvent -InputObject $backendProc -EventName ErrorDataReceived -Action {
        if ($EventArgs.Data) { Add-Content -Path $using:BackendLog -Value $EventArgs.Data }
    } | Out-Null
    $backendProc.BeginOutputReadLine()
    $backendProc.BeginErrorReadLine()

    Start-Sleep -Seconds 2
    if ($backendProc.HasExited) {
        Write-Host "Error: Backend failed to start. Logs:" -ForegroundColor Red
        if (Test-Path $BackendLog) { Get-Content $BackendLog }
        exit 1
    }
    Write-Host "Backend is running (PID: $($backendProc.Id)) on port 8080." -ForegroundColor Green

    # 2. Cloudflare Tunnels
    $CfBackendUrl = $null
    $CfFrontendUrl = $null

    if ($IsTunnel) {
        Write-Host "`n====================================================" -ForegroundColor Cyan
        Write-Host " [2/3] Establishing Cloudflare Tunnels..." -ForegroundColor Cyan
        Write-Host "====================================================" -ForegroundColor Cyan

        # Backend Tunnel
        Write-Host "Starting Backend Tunnel (http://localhost:8080)..."
        $cfBackendProc = Start-Process cloudflared -ArgumentList "tunnel", "--url", "http://localhost:8080" -RedirectStandardError $CfBackendLog -PassThru -NoNewWindow
        $processes.Add($cfBackendProc)

        $CfBackendUrl = Extract-TunnelUrl $CfBackendLog "Backend" 30
        if (-not $CfBackendUrl) {
            Write-Host "Could not obtain backend Cloudflare URL." -ForegroundColor Red
            exit 1
        }

        # Frontend Tunnel
        Write-Host "Starting Frontend Tunnel (http://localhost:3000)..."
        $cfFrontendProc = Start-Process cloudflared -ArgumentList "tunnel", "--url", "http://localhost:3000" -RedirectStandardError $CfFrontendLog -PassThru -NoNewWindow
        $processes.Add($cfFrontendProc)

        $CfFrontendUrl = Extract-TunnelUrl $CfFrontendLog "Frontend" 30
        if (-not $CfFrontendUrl) {
            Write-Host "Could not obtain frontend Cloudflare URL." -ForegroundColor Red
            exit 1
        }
    }

    # 3. Print Banner
    Write-Host "`n====================================================================" -ForegroundColor Magenta
    Write-Host "                     KITA SERVER READY TO PLAY                      " -ForegroundColor Magenta
    Write-Host "====================================================================" -ForegroundColor Magenta
    if ($IsTunnel) {
        Write-Host " Mode:               Cloudflare Tunnel (Public Access Worldwide)`n" -ForegroundColor Yellow
        Write-Host " [>] Public Frontend: $CfFrontendUrl" -ForegroundColor Cyan
        Write-Host " [>] Public Backend:  $CfBackendUrl" -ForegroundColor Cyan
        $wsUrl = $CfBackendUrl -replace '^https://', 'wss://'
        Write-Host " [>] Public WS:       $wsUrl/ws" -ForegroundColor Cyan
        Write-Host "`n [>] Local Network:   http://${LocalIP}:3000"
        Write-Host " [>] Localhost:       http://localhost:3000"
    } else {
        Write-Host " Mode:               Local Area Network (LAN)`n" -ForegroundColor Yellow
        Write-Host " [>] Network URL:     http://${LocalIP}:3000" -ForegroundColor Cyan
        Write-Host " [>] Localhost:       http://localhost:3000"
        Write-Host " [>] Backend API:     http://${LocalIP}:8080"
        Write-Host "`n Tip: Run with -Tunnel to share globally via Cloudflare!" -ForegroundColor DarkGray
    }
    Write-Host "====================================================================`n" -ForegroundColor Magenta

    # 4. Start Flutter Web Server
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host " [3/3] Starting Kita Frontend (Flutter Web Server)..." -ForegroundColor Cyan
    Write-Host "====================================================" -ForegroundColor Cyan
    Set-Location $FrontendDir

    if ($IsTunnel) {
        Write-Host "Executing: flutter run -d web-server --web-hostname 0.0.0.0 --web-port 3000 --dart-define=API_URL=$CfBackendUrl" -ForegroundColor DarkGray
        flutter run -d web-server --web-hostname 0.0.0.0 --web-port 3000 "--dart-define=API_URL=$CfBackendUrl"
    } else {
        Write-Host "Executing: flutter run -d web-server --web-hostname 0.0.0.0 --web-port 3000" -ForegroundColor DarkGray
        flutter run -d web-server --web-hostname 0.0.0.0 --web-port 3000
    }
} finally {
    Cleanup
}
