# Run dart analyze and write all output (including violations) to a log file.
# Usage: from repo root: .\scripts\analyze_to_log.ps1
#        or: pwsh -File scripts\analyze_to_log.ps1

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$logDir = Join-Path $root 'reports'
$date = Get-Date -Format 'yyyyMMdd'
$time = Get-Date -Format 'HHmmss'
$logName = "${date}_analysis_violations_$time.log"
$logPath = Join-Path $logDir $logName

if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

Push-Location $root
try {
    Write-Host "Running dart analyze; output -> $logPath"
    cmd /c "dart analyze > `"$logPath`" 2>&1"
    $exitCode = $LASTEXITCODE
    Write-Host "Log written: $logPath"
    Write-Host "Exit code: $exitCode (0 = no issues, 1 = info, 2 = warnings/errors)"
    exit $exitCode
} finally {
    Pop-Location
}
