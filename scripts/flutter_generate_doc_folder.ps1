#Requires -Version 7
<#
.SYNOPSIS
Generates and optionally uploads Flutter project documentation to the gh-pages branch.

.DESCRIPTION
This PowerShell script automates the process of generating Flutter project documentation using `dartdoc` and optionally uploading it to the `gh-pages` branch of a Git repository. It cleans the output directory, activates `dartdoc` if necessary, generates the documentation, checks for common warnings, and handles the Git operations for committing and pushing the documentation to the `gh-pages` branch.

.NOTES
  Version:   2.8
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

# PowerShell script to generate and upload Flutter documentation
# Get the directory where the script is located
$scriptDir = $PSScriptRoot

# Set the working directory to the parent directory of the script's directory
$workingDir = Split-Path -Path $scriptDir -Parent

# Navigate to the working directory
Set-Location -Path $workingDir

# Define the documentation output directory
$docOutputDir = Join-Path $workingDir "doc"

# Clean the documentation directory
if (Test-Path $docOutputDir) {
    Remove-Item $docOutputDir -Recurse -Force
    Write-Output "Cleaned the documentation directory."
}

# Run Flutter command to generate documentation
flutter pub global activate dartdoc
flutter pub global run dartdoc

# Check if the documentation is created
$apiDocPath = Join-Path $docOutputDir "api"
if (Test-Path $apiDocPath) {
    Write-Output "Documentation generated successfully in $apiDocPath."
} else {
    Write-Output "Failed to generate documentation."
    exit 1
}

# Optional: Check for common warnings
$logPath = Join-Path $workingDir "dartdoc-log.txt"
flutter pub global run dartdoc > $logPath

# Check the log for common issues
$logContent = Get-Content $logPath

# Unresolved doc reference
if ($logContent -match "warning: unresolved doc reference") {
    Write-Output "Warning: Unresolved doc reference found."
}

# Broken links
if ($logContent -match "dartdoc generated a broken link") {
    Write-Output "Warning: Broken links detected."
}

# Ask the user if they want to upload the documentation
$upload = Read-Host "Do you want to upload the documentation to the gh-pages branch? (y/n)"
if ($upload -eq 'y') {
    # Uploading to gh-pages branch
    git checkout --orphan gh-pages
    mkdir -p doc/api
    Copy-Item -r $apiDocPath/* doc/api/
    git add doc
    git commit -m "Update generated documentation"
    git push origin gh-pages --force
    Write-Output "Documentation uploaded to gh-pages branch successfully."
} else {
    Write-Output "Documentation not uploaded."
}
