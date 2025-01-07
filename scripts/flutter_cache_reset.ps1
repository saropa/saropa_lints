# Create a PowerShell script to clean up Flutter artifacts

# Get the directory where the script is located
$scriptDir = $PSScriptRoot

# Set the working directory to the parent directory of the script's directory
$workingDir = Split-Path -Path $scriptDir -Parent

# Define the paths
$buildDir = Join-Path -Path $workingDir -ChildPath "build"
$pubCacheDir = Join-Path -Path $env:USERPROFILE -ChildPath ".pub-cache"

try {
    Write-Host ""
    Write-Host ""
    Write-Host ""
    Write-Host "#########################################################"

    # Delete the "build" directory
    if (Test-Path -Path $buildDir -PathType Container) {
        Write-Host "Deleting the 'build' directory..."
        Remove-Item -Path $buildDir -Recurse -Force
    } else {
        Write-Host "The 'build' directory does not exist."
    }

    # Clear the contents of the ".pub-cache" directory
    if (Test-Path -Path $pubCacheDir -PathType Container) {
        Write-Host "Clearing the contents of the '.pub-cache' directory..."
        Remove-Item -Path $pubCacheDir\* -Recurse -Force
    } else {
        Write-Host "The '.pub-cache' directory does not exist."
    }

    # Run "flutter clean" in the current directory
    Write-Host "Running 'flutter clean' in $workingDir..."
    Invoke-Expression "flutter clean"

    # Run "flutter pub cache clean" to remove the global package cache
    Write-Host "Removing the global package cache..."
    Invoke-Expression "echo Y | flutter pub cache clean"

    # Run "flutter pub get" in the current directory
    Write-Host "Running 'flutter pub get' in $workingDir..."
    Invoke-Expression "flutter pub get"

    # Find subdirectories (subprojects)
    $subDirs = Get-ChildItem -Directory -Path $workingDir | Where-Object { Test-Path (Join-Path $_.FullName "pubspec.yaml") }
    foreach ($subDir in $subDirs) {
        Write-Host "---------------------------------------------------------"
        Write-Host "Running 'flutter pub get' for subproject in $($subDir.FullName)..."
        Set-Location -Path $subDir.FullName
        Invoke-Expression "flutter pub get"
    }

    Write-Host "Cleanup completed successfully in $workingDir."
    Write-Host "#########################################################"
} catch {
    Write-Host "An error occurred: $_"
}

