# Define parameters for the script
param (
    # The first command line argument is the path to the directory to search
    [Parameter(Position=0)]
    [string]$Path = (Get-Location).Path,  # Default to the current directory if no path is provided

    # The -ShowSkipped switch controls whether to output skipped files and directories
    [switch]$ShowSkipped,

    # The -Help switch displays help information and then exits
    [switch]$Help,

    # The -NoSkips switch controls whether to skip anything
    [switch]$NoSkips,

    # The -NoSummary switch controls whether to hide the totals
    [switch]$NoSummary
)
# Get the directory where the script is located
$scriptDir = $PSScriptRoot

# Set the working directory to the parent directory of the script's directory
$workingDir = Split-Path -Path $scriptDir -Parent

# If -Help is specified, display help information and then exit
if ($Help) {
    Write-Output @"
Usage: .\FindDuplicates.ps1 [-Path <path>] [-ShowSkipped] [-Help] [-NoSkips] [-NoSummary]

-Path <path>        Specify the path to the directory to search. If no path is provided, the current directory is used.

-ShowSkipped        Output skipped files and directories.

-Help               Display this help message.

-NoSkips            Do not skip anything.

-NoSummary          Do not display summary totals.
"@
    exit
}

# List of directories to exclude from the search (unless -NoSkips is specified)
$ExcludeDirs = if ($NoSkips) { @() } else { @('.dart_tool', 'dependency_overrides') }
if ($ShowSkipped -and $ExcludeDirs) {
    Write-Output "Excluded directories: $($ExcludeDirs -join ', ')"
}

# List of filenames to exclude from the search (unless -NoSkips is specified)
$ExcludeFileNames = if ($NoSkips) { @() } else { @('.git') }
if ($ShowSkipped -and $ExcludeFileNames) {
    Write-Output "Excluded file names: $($ExcludeFileNames -join ', ')"
}

# List of class names to exclude from the search (unless -NoSkips is specified)
$ExcludeClassNames = if ($NoSkips) { @() } else { 'for', 'that', 'which', 'in', 'with', 'used', 'representing' }
if ($ShowSkipped -and $ExcludeClassNames) {
    Write-Output "Excluded class names: $($ExcludeClassNames -join ', ')"
}

# List of comment identifiers (unless -IncludeComments is specified)
$CommentIdentifiers = if ($IncludeComments) { @() } else { '//', '///', '/*' }
if ($ShowSkipped -and $IncludeComments) {
    Write-Output "Excluded comments: $($IncludeComments -join ', ')"
}

# Initialize an empty hashtable to store class names
$ClassNames = @{}

# Initialize an empty hashtable to store duplicate class names and their file paths
$Duplicates = @{}

# Initialize counters for total duplicates, total affected files, total folders scanned, and total files scanned
$totalDuplicates = 0
$totalFiles = 0
$totalFolders = 0
$totalFilesScanned = 0

# Start timer for measuring total time taken
$timer = [Diagnostics.Stopwatch]::StartNew()

# Loop over each file in the directory and its subdirectories
Get-ChildItem -Path $workingDir -Recurse -Include *.dart | ForEach-Object {
    $totalFilesScanned++  # Increment total files scanned counter

    # Check if the file is in one of the excluded directories
    if ($_.DirectoryName) {
        foreach ($Dir in $ExcludeDirs) {
            if ($_.DirectoryName.Split('\') -contains $Dir) {
                # Output excluded directory if -ShowSkipped is specified
                if ($ShowSkipped) { Write-Output ("Excluded directory: " + $_.DirectoryName) }
                return  # Skip this file and continue with the next one
            }
        }
        $totalFolders++  # Increment total folders scanned counter
    }

    # Check if the file name is in the exclude list
    if ($_.Name -in $ExcludeFileNames) { 
        # Output excluded file if -ShowSkipped is specified
        if ($ShowSkipped) { Write-Output ("Excluded file: " + $_.FullName) }
        return  # Skip this file and continue with the next one
    }

    # Read the content of the file
    $Content = Get-Content $_.FullName -Raw

    # Skip this file if its content is null (empty or unreadable)
    if ($null -eq $Content) { return }

    # Find all class declarations in the file content that are not within quotes or comments
    $FoundMatches = [regex]::Matches($Content, '(?<!["''])(?<!' + ($CommentIdentifiers -join '|') + ')\sclass (\w+)(?!["''])')

    # Loop over each match (class declaration)
    foreach ($Match in $FoundMatches) {
        # Get the class name from the match
        $ClassName = $Match.Groups[1].Value

        # Check if the class name is in the exclude list, and skip it if it is
        if ($ClassName -in $ExcludeClassNames) { continue }

        # Check if the class name is already in the hashtable of class names
        if ($ClassNames.ContainsKey($ClassName)) {
            # If it is, add it to the duplicates hashtable along with its file path
            if ($Duplicates.ContainsKey($ClassName)) {
                $Duplicates[$ClassName] += ", " + $_.FullName  # Add new file path to existing list of duplicates for this class name
            } else {
                $Duplicates[$ClassName] = $ClassNames[$ClassName] + ", " + $_.FullName  # Add first duplicate of this class name to duplicates hashtable
            }
            $totalDuplicates++  # Increment total duplicates counter
            $totalFiles++  # Increment total affected files counter
        } else {
            # If it's not in the hashtable, add it to the hashtable along with its file path
            $ClassNames[$ClassName] = $_.FullName  # Add new class name to hashtable of class names
        }
    }
}

# Print out all duplicate class names and their file paths after all files have been processed
foreach ($Entry in $Duplicates.GetEnumerator()) {
    # Count the number of duplicates for this class name
    $Count = ($Entry.Value -split ', ').Count

    Write-Output ("`nDuplicate class name: " + $Entry.Key + " ($Count)")
    foreach ($FilePath in ($Entry.Value -split ', ')) {
        Write-Output ("   - " + $FilePath)
    }
}

# Stop timer and calculate total time taken
$timer.Stop()
$totalTime = $timer.Elapsed.TotalSeconds

# Print summary of total duplicates, total affected files, total folders scanned, total files scanned, and total time taken (unless -NoSummary is specified)
if (-not $NoSummary) {
    Write-Output ("`nTotal duplicates: " + $totalDuplicates)
    Write-Output ("Total affected files: " + $totalFiles)
    Write-Output ("Total folders scanned: " + $totalFolders)
    Write-Output ("Total files scanned: " + $totalFilesScanned)
    Write-Output ("Total time taken: " + [math]::Round($totalTime, 2) + " seconds")
}
