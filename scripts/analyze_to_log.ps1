# Run dart analyze and write all output (including violations) to a log file.
# Usage: from repo root: .\scripts\analyze_to_log.ps1
#        or: pwsh -File scripts\analyze_to_log.ps1

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$date = Get-Date -Format 'yyyyMMdd'
$time = Get-Date -Format 'HHmmss'
$logDir = Join-Path $root 'reports' $date
$logName = "${date}_analysis_violations_$time.log"
$logPath = Join-Path $logDir $logName

if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

Push-Location $root
try {
    Write-Host "Running dart analyze; output -> $logPath"
    $rawPath = Join-Path $logDir "_raw_$logName"
    cmd /c "dart analyze > `"$rawPath`" 2>&1"
    $exitCode = $LASTEXITCODE
    # Strip progress bar lines (block chars like ░█▓▒ with │) and wide blank lines
    $lines = Get-Content -Path $rawPath -Encoding UTF8
    $filtered = $lines | Where-Object {
        $s = $_.Trim()
        -not ($s.Length -gt 0 -and '░▒▓█'.Contains($s[0]) -and $s.Contains('│')) -and
        -not ($s.Length -eq 0 -and $_.Length -gt 40)
    }
    $filtered | Set-Content -Path $logPath -Encoding UTF8
    Remove-Item -Path $rawPath -Force -ErrorAction SilentlyContinue
    Write-Host "Log written: $logPath"
    Write-Host "Exit code: $exitCode (0 = no issues, 1 = info, 2 = warnings/errors)"
    exit $exitCode
} finally {
    Pop-Location
}
