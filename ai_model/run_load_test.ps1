# Set console to UTF-8 for better character support
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "--- Nyay Mitra AI Load Test Runner ---" -ForegroundColor Cyan

# Use absolute path for log file
$logFile = Join-Path (Get-Location) "backend_test_log.txt"

# 1. Kill any existing instances
Write-Host "Cleaning up previous instances..." -ForegroundColor Gray
$proc = Get-NetTCPConnection -LocalPort 8000 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -ErrorAction SilentlyContinue
if ($proc) { 
    Stop-Process -Id $proc -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

if (Test-Path $logFile) { Remove-Item $logFile }

# 2. Start Backend
Write-Host "Starting AI Backend (main.py)..." -ForegroundColor Cyan
# Start in a new window or as a background process
$backendProc = Start-Process python -ArgumentList "main.py" -WorkingDirectory "." -PassThru -NoNewWindow -RedirectStandardOutput $logFile -RedirectStandardError $logFile

# 3. Wait for Server to be ready
Write-Host "Waiting for server to initialize RAG (HuggingFace + FAISS)..." -ForegroundColor Yellow
$maxAttempts = 60 # 120 seconds total
$attempt = 0
$serverReady = $false

while ($attempt -lt $maxAttempts -and -not $serverReady) {
    $attempt++
    try {
        # Using 127.0.0.1 instead of localhost for reliability
        $response = Invoke-WebRequest -Uri "http://127.0.0.1:8000/" -UseBasicParsing -TimeoutSec 1 -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            $serverReady = $true
            Write-Host "[SUCCESS] Server is up and healthy!" -ForegroundColor Green
        }
    }
    catch {
        # Still starting
    }
    if (-not $serverReady) {
        if ($attempt -eq 1) { Write-Host "This may take 30-60s on first run as models load." -ForegroundColor Gray }
        Write-Host "Attempt ${attempt}/${maxAttempts}: Waiting..." -ForegroundColor Gray
        Start-Sleep -Seconds 2
    }
}

if (-not $serverReady) {
    Write-Host "[ERROR] Server failed to start within 120 seconds." -ForegroundColor Red
    if (Test-Path $logFile) {
        Write-Host "Last 10 lines of backend_test_log.txt:" -ForegroundColor Red
        Get-Content $logFile -Tail 10
    }
    else {
        Write-Host "No log file found at $logFile" -ForegroundColor Red
    }
    exit 1
}

# 4. Start Locust
Write-Host "Launching Locust Load Test UI..." -ForegroundColor Green
Write-Host ">> Visit http://localhost:8089 to start the test." -ForegroundColor Green
locust -f locustfile.py --host http://localhost:8000
