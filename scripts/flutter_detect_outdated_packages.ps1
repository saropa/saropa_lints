# Get the directory where the script is located
$scriptDir = $PSScriptRoot

# Set the working directory to the parent directory of the script's directory
$workingDir = Split-Path -Path $scriptDir -Parent

# Set the directories to exclude, separated by spaces
$EXCLUDE_DIRS = @(".git", ".dart_tool", ".crashlytics", ".gradle")

# Find all directories containing a pubspec.yaml file
$PROJECT_DIRS = Get-ChildItem -Path $workingDir -Filter pubspec.yaml -Recurse | Select-Object -ExpandProperty DirectoryName

# Navigate to each project directory and run flutter pub outdated
foreach ($dir in $PROJECT_DIRS) {
    # Check if the directory is in the list of directories to exclude
    if ($EXCLUDE_DIRS -contains (Split-Path $dir -Leaf)) {
        Write-Output "$dir *SKIPPED"
        continue
    }

    Set-Location $dir
    Write-Output ""
    Write-Output ""
    Write-Output ""
    Write-Output "----------------------------------------------------------------------------------------------------------------------------------------------"
    Write-Output "Running flutter pub outdated in $dir"
    flutter pub outdated
}
