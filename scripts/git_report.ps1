# PowerShell script to log Git commits within a specific date range

# Get the directory where the script is located
$scriptDir = $PSScriptRoot

# Set the working directory to the parent directory of the script's directory
$workingDir = Split-Path -Path $scriptDir -Parent

# Navigate to the working directory
Set-Location -Path $workingDir

# Define the start date and end date (today's date)
$startDate = "2024-10-01"  # Adjust the start date as needed
$endDate = (Get-Date).AddDays(1).ToString("yyyy-MM-dd")

# Debugging: Print the date range
Write-Output "Fetching commits from $startDate to $endDate"

# Run the Git log command with the date range filter
git log --since="$startDate" --until="$endDate" --pretty=format:"%H %s%n%b" > "commit_details_$startDate-$endDate.log"

# Debugging: Check if the file is created and has content
if (Test-Path "commit_details_$startDate-$endDate.log") {
    $fileContent = Get-Content "commit_details_$startDate-$endDate.log"
    if ($fileContent) {
        Write-Output "Commits have been logged successfully."
    } else {
        Write-Output "No commits found in the specified date range."
    }
} else {
    Write-Output "Failed to create the commit details file."
}
