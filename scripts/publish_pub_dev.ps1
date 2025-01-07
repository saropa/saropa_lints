#Requires -Version 7
<#
.SYNOPSIS
Publishes a Dart/Flutter package to pub.dev and creates a corresponding GitHub release.

.DESCRIPTION
This PowerShell script automates the process of publishing a Dart/Flutter package to pub.dev.
It runs tests, cleans the build directory, publishes the package using `flutter pub publish`,
and then creates a tagged release on GitHub with release notes extracted from the CHANGELOG.

.NOTES
  Version:   1.3
  Author:    Saropa
  Copyright: © 2024 Saropa. All rights reserved.
  Website:   https://saropa.com
  Email:     dev.tools@saropa.com
#>

# Function to display the Saropa "S" logo in ASCII art
function Show-SaropaLogo {
    Write-Host @"

$([char]0x1b)[38;5;208m                               ....$([char]0x1b)[0m
$([char]0x1b)[38;5;208m                       `-+shdmNMMMMNmdhs+-$([char]0x1b)[0m
$([char]0x1b)[38;5;209m                    -odMMMNyo/-..````.++:+o+/-$([char]0x1b)[0m
$([char]0x1b)[38;5;215m                 `/dMMMMMM/`               ``````````$([char]0x1b)[0m
$([char]0x1b)[38;5;220m                `dMMMMMMMMNdhhhdddmmmNmmddhs+-$([char]0x1b)[0m
$([char]0x1b)[38;5;226m                /MMMMMMMMMMMMMMMMMMMMMMMMMMMMMNh/$([char]0x1b)[0m
$([char]0x1b)[38;5;190m              . :sdmNNNNMMMMMNNNMMMMMMMMMMMMMMMMm+$([char]0x1b)[0m
$([char]0x1b)[38;5;154m              o     `..~~~::~+==+~:/+sdNMMMMMMMMMMMo$([char]0x1b)[0m
$([char]0x1b)[38;5;118m              m                        .+NMMMMMMMMMN$([char]0x1b)[0m
$([char]0x1b)[38;5;123m              m+                         :MMMMMMMMMm$([char]0x1b)[0m
$([char]0x1b)[38;5;87m              /N:                        :MMMMMMMMM/$([char]0x1b)[0m
$([char]0x1b)[38;5;51m               oNs.                    `+NMMMMMMMMo$([char]0x1b)[0m
$([char]0x1b)[38;5;45m                :dNy/.              ./smMMMMMMMMm:$([char]0x1b)[0m
$([char]0x1b)[38;5;39m                 `/dMNmhyso+++oosydNNMMMMMMMMMd/$([char]0x1b)[0m
$([char]0x1b)[38;5;33m                    .odMMMMMMMMMMMMMMMMMMMMdo-$([char]0x1b)[0m
$([char]0x1b)[38;5;57m                       `-+shdNNMMMMNNdhs+-$([char]0x1b)[0m
$([char]0x1b)[38;5;57m                               ````$([char]0x1b)[0m

"@ -ForegroundColor Green

    # Copyright notice with color, indentation, and email
    $coloredCopyright = @"
    $([char]0x1b)[38;5;195m© 2024 Saropa. All rights reserved.
    $([char]0x1b)[38;5;117mhttps://saropa.com
"@
    Write-Host $coloredCopyright

    # Clickable email address for compatible terminals
    $email = "dev.tools@saropa.com"
    $esc = [char]27
    Write-Host "`r`n    $esc]8;;mailto:$email$esc\$email$esc]8;;$esc\`r`n" # Added indent and line breaks
}

# Display ASCII art logo with color
Show-SaropaLogo

# Get the directory where the script is located
$scriptDir = $PSScriptRoot

# Set the working directory to the parent directory of the script's directory
$workingDir = Split-Path -Path $scriptDir -Parent

# Navigate to the working directory
Set-Location -Path $workingDir

# Run tests to ensure everything is good
Write-Output "Running tests..."
flutter test

# Check if tests passed
if ($LASTEXITCODE -ne 0) {
    Write-Output "Tests failed. Aborting publish."
    exit 1
}

# Ask the user for the release number
$releaseNumber = Read-Host "Enter the release number (e.g., 0.4.0)"

# Validate the release number format (basic check)
if (!($releaseNumber -match "^\d+\.\d+\.\d+$")) {
    Write-Error "Invalid release number format. Use MAJOR.MINOR.PATCH (e.g., 0.4.0)."
    exit 1
}

# Update pubspec.yaml version
Write-Output "Updating pubspec.yaml version to $releaseNumber..."
$pubspecContent = Get-Content pubspec.yaml
$pubspecContent = $pubspecContent -replace '(?<=^version: ).*', $releaseNumber
Set-Content -Path pubspec.yaml -Value $pubspecContent

# Extract release notes from CHANGELOG.md
Write-Output "Extracting release notes from CHANGELOG.md..."
$changelogContent = Get-Content CHANGELOG.md -Raw
$releaseNotes = $changelogContent -replace "(?s).*?## \[$releaseNumber\].*?\n(.*?)## \[\d+\.\d+\.\d+\].*$", '$1'
$releaseNotes = $releaseNotes.Trim()

if ([string]::IsNullOrWhiteSpace($releaseNotes)) {
    Write-Warning "No release notes found for version $releaseNumber in CHANGELOG.md. Using a generic message."
    $releaseNotes = "Release $releaseNumber"
}

# Ask the user if they want to publish the package to pub.dev
$publish = Read-Host "Do you want to publish the package to pub.dev? (y/n)"
if ($publish -eq 'y') {
    # Clean the build directory
    flutter clean

    Write-Output "Publishing version $releaseNumber to pub.dev..."

    # Publish the package to pub.dev (remove --force if you want to confirm)
    flutter pub publish --force

    # Check if publishing was successful
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to publish package to pub.dev."
        exit 1
    }

    Write-Output "Package published to pub.dev successfully."

    # Commit and push changes
    Write-Output "Committing and pushing changes..."
    git add pubspec.yaml CHANGELOG.md
    git commit -m "Release v$releaseNumber"
    git push origin main

    # Create Git tag
    $tagName = "v$releaseNumber"
    Write-Output "Creating Git tag $tagName..."
    git tag -a $tagName -m "Release $tagName"

    # Push tag to GitHub
    Write-Output "Pushing tag to GitHub..."
    git push origin $tagName

    # Create GitHub release using GitHub CLI (gh) - Install it if you don't have it
    Write-Output "Creating GitHub release..."
    gh release create $tagName --title "Release $tagName" --notes "$releaseNotes"

    # Check if GitHub release creation was successful
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create GitHub release. You may need to install the GitHub CLI (gh) or create the release manually."
        exit 1
    }
    Write-Output "GitHub release created successfully."
} else {
    Write-Output "Package not published."
}