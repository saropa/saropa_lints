#Requires -Version 7
<#
.SYNOPSIS
+  Scans a Flutter project's Dart files to identify potentially unused methods and methods with duplicate names.

 .DESCRIPTION
+  This script analyzes Dart files in a specified directory (typically a Flutter project's 'lib' folder)
+  to find methods that are defined but not called elsewhere in the project. It also identifies methods
+  that have the same name but are defined in multiple locations. It generates log files
+  listing unused methods, used methods, and methods with duplicate names along with their file locations.
+
+  This script relies on pattern matching and doesn't have a deep understanding of the Dart code's
+  semantics. There might still be edge cases where it misses usages or incorrectly identifies them.

.NOTES
  Version:   1.7
  Author:    Saropa
  Copyright: © 2024 Saropa. All rights reserved.
  Website:   https://saropa.com
  Email:     dev.tools@saropa.com
#>

# Function to display the Saropa "S" logo in ASCII art
function Show-SaropaLogo {
  Write-Host "
`r`n`r`n`r`n
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
" -ForegroundColor Green

  # Copyright notice with color, indentation, and email
  $coloredCopyright = @"
  $([char]0x1b)[38;5;195m© 2024 Saropa. All rights reserved.
  $([char]0x1b)[38;5;117mhttps://saropa.com
"@
  Write-Host $coloredCopyright

  # Clickable email address for compatible terminals
  $email = "dev.tools@saropa.com"
  $esc = [char]27
  Write-Host "$esc]8;;mailto:$email$esc\Email $email$esc]8;;$esc\"
}
# Function to display the Saropa "S" logo in ASCII art without color
function Get-SaropaLogoUncolored {
  return "
`r`n`r`n`r`n
                              ....
                     `-+shdmNMMMMNmdhs+-
                  -odMMMNyo/-..````.++:+o+/-
               `/dMMMMMM/`               ``````````
              `dMMMMMMMMNdhhhdddmmmNmmddhs+-
              /MMMMMMMMMMMMMMMMMMMMMMMMMMMMMNh/
            . :sdmNNNNMMMMMNNNMMMMMMMMMMMMMMMMm+
            o     `..~~~::~+==+~:/+sdNMMMMMMMMMMMo
            m                        .+NMMMMMMMMMN
            m+                         :MMMMMMMMMm
            /N:                        :MMMMMMMMM/
             oNs.                    `+NMMMMMMMMo
              :dNy/.              ./smMMMMMMMMm:
               `/dMNmhyso+++oosydNNMMMMMMMMMd/
                  .odMMMMMMMMMMMMMMMMMMMMdo-
                     `-+shdNNMMMMNNdhs+-
                             ````
`r`n`r`n`r`n
"
}

# Copyright notice (uncolored, for log files)
$uncoloredCopyright = @"
© 2024 Saropa. All rights reserved.
https://saropa.com
mailto:dev.tools@saropa.com
"@

# Display ASCII art logo with color
Show-SaropaLogo

# Add extra blank lines after the logo
Write-Output "`r`n`r`n"

# Display introductory sentence
Write-Output "Starting Saropa analysis of Flutter project to identify potentially unused methods..."
Write-Output ""

####################################################################################################
# --- Configuration ---
####################################################################################################
$logDestinationPath = $PSScriptRoot # Log files will be created in the same directory as the script.
$minimumMethodNameLength = 4        # Method names shorter than this will be ignored.
$ignoreTestFolder = $true          # Set to $true to ignore the 'test' folder.

# Array of folders to ignore (add more if needed)
$foldersToIgnore = @(
  ".crashlytics", ".dart_tool", ".dev", ".github", ".idea", ".vs", ".vscode"
)

# Array of common keywords, types, and method names to exclude (sorted alphabetically)
# (Merged from both scripts and duplicates removed)
$flutterKeywordDictionary = @(
  "abstract", "addListener", "addStatusListener", "animate", "animateBack", "animateForward", "animateTo", "Animation",
  "AnimationController", "AppBar", "assert", "async", "asyncExpand", "await", "bool", "bottom", "break", "build", "builder",
  "case", "cast", "catch", "Center", "ChangeNotifier", "children", "class", "clear", "Column", "compareTo", "computeDryLayout",
  "const", "constructor", "Container", "contains", "continue", "copyWith", "createElement", "createState", "debugPrint",
  "default", "didChangeAppLifecycleState", "didChangeDependencies", "didChangeLocales", "didChangeMetrics", "didChangePlatformBrightness",
  "didChangeTextScaleFactor", "didHaveMemoryPressure", "didPopRoute", "didPushRoute", "didUnmount", "didUpdateWidget",
  "dispose", "double", "dynamic", "elementAt", "else", "enum", "every", "Expanded",
  "expand", "export", "extends", "factory", "false", "final", "finally", "first", "firstWhere", "Flexible",
  "FloatingActionButton", "fold", "followedBy", "forEach", "Form", "FormField", "Function", "Future", "GestureDetector",
  "GlobalKey", "GridView", "group", "handleEvent", "hashCode", "height", "hide", "horizontal", "Icon", "Image",
  "implements", "import", "indexOf", "initState", "insert", "insertAll", "int", "Iterable", "is", "isEmpty", "isNotEmpty",
  "iterator", "join", "label", "last", "lastIndexOf", "lastWhere", "layout", "left", "length", "library",
  "List", "ListView", "load", "lookup", "MainAxisAlignment", "mainAxisSize", "Map", "map", "markNeedsLayout",
  "markNeedsPaint", "markNeedsRebuild", "markNeedsSemanticsUpdate", "matchAsPrefix", "MediaQuery", "mixin", "mount",
  "Navigator", "noSuchMethod", "none", "null", "ofType", "only", "onEnter", "onExit", "onFocusChange", "onHover",
  "onKey", "onLongPress", "onPanCancel", "onPanDown", "onPanEnd", "onPanStart", "onPanUpdate", "onPointerCancel",
  "onPointerDown", "onPointerHover", "onPointerMove", "onPointerSignal", "onPointerUp", "onScaleCancel", "onScaleEnd",
  "onScaleStart", "onScaleUpdate", "onTap", "onTapCancel", "onTapDown", "onTapUp", "operator", "options", "orElse",
  "other", "package", "Padding", "paint", "part", "performLayout", "performResize", "pop", "print", "Provider",
  "push", "pushNamed", "pushReplacement", "pushReplacementNamed", "reassemble", "reduce", "remove", "removeAll",
  "removeAt", "removeFirst", "removeLast", "removeListener", "removeRange", "removeStatusListener", "removeWhere",
  "render", "replaceFirstMapped", "replaceLastMapped", "replaceMapped", "replaceRange", "replaceAll", "replaceAllMapped",
  "replaceWhere", "replaceWith", "retainWhere", "return", "reversed", "right", "Row", "runAsync", "Scaffold",
  "schedule", "setAction", "setState", "Set", "shuffle", "SingleChildScrollView", "SizedBox", "sleep", "sort",
  "stack", "start", "startsWith", "State", "StatefulWidget", "static", "StatelessWidget", "Stream", "String",
  "substring", "super", "switch", "sync", "take", "test", "Text", "Theme", "this", "throw", "Ticker",
  "timeout", "Timer", "toList", "top", "toString", "transform", "true", "try", "Tween", "typedef",
  "typeId", "unawaited", "unique", "unknown", "update", "updateShouldNotify", "uri", "values", "vertical",
  "visitAncestorElements", "visitChildElements", "void", "wait", "whenComplete", "where", "whereType", "while", "with",
  "width", "wrap", "write", "writeAll", "writeln", "yield", "yieldEach", "zero"
)

# Display configuration
Write-Output "Configuration:"
Write-Output ("    - Log Destination Path: {0}" -f $logDestinationPath)
Write-Output ("    - Minimum Method Name Length: {0}" -f $minimumMethodNameLength)
Write-Output ("    - Ignore Test Folder: {0}" -f $ignoreTestFolder)
Write-Output ("    - Additional Folders to Ignore: {0}" -f ($foldersToIgnore -join ", "))
Write-Output ("    - The script will only analyze Dart files in the 'lib' directory.")
Write-Output ("    - Generated '.g.dart' files will be ignored.")
Write-Output ("    - Methods starting with an underscore '_' are considered private and ignored.")
Write-Output ("    - Excluding $($flutterKeywordDictionary.Count) Flutter keywords/method names.")
Write-Output ""
Write-Output "Report:"

# Start time for runtime calculation
$startTime = Get-Date
Write-Output ("    - Start Time: {0}" -f $startTime)

####################################################################################################
# --- Setup ---
####################################################################################################

# Get the directory where the script is located
$scriptDir = $PSScriptRoot

# Set the working directory to the parent directory of the script's directory
$workingDir = Split-Path -Path $scriptDir -Parent

# Define the directory to scan
$directory = "$workingDir\lib"

# --- File Filtering ---

# Build the exclusion filter for folders
$excludeFilter = ($foldersToIgnore | ForEach-Object { "*$_" }) -join ","

# Get all Dart files, excluding test folder and other specified folders
if ($ignoreTestFolder) {
  $dartFiles = Get-ChildItem -Path $directory -Recurse -Filter *.dart -Exclude "*test*", $excludeFilter |
  Where-Object { $_.FullName -notlike "*.g.dart" }
  Write-Output "    - Ignoring 'test' folder"
}
else {
  $dartFiles = Get-ChildItem -Path $directory -Recurse -Filter *.dart -Exclude $excludeFilter |
  Where-Object { $_.FullName -notlike "*.g.dart" }
}

Write-Output "    - Found $($dartFiles.Count) Dart files to analyze."

# Initialize a hashtable to track method usage
$methodUsage = @{}

# First pass: Extract all method names
$methodNames = @{} # Hashtable to store method names and their defining file

# Hashtable to store duplicate method names and their file paths
$DuplicateMethodNames = @{}

# Sort Dart files before processing
$sortedDartFiles = $dartFiles | Sort-Object Name

# Regex to identify class, enum, mixin, and extension blocks
$classBlockRegex = [regex]'^\s*(?:abstract\s+)?(?:class|enum|mixin|extension)\s+(\w+)'

# Improved regex to better identify method definitions, now also capturing @override
$methodRegex = [regex]'(?m)^\s*(@override\s+)?\s*(?:static\s+)?(?:[\w.<> ]+\s+)?([\w]+)\s*(\([^)]*\)|)\s*(async\s*)?({\s*|\=\>\s*)'

# Regex to find @saropaAnalysisIgnore annotations (case-insensitive)
$ignoreAnnotationRegex = [regex]'(?i)@saropaAnalysisIgnore'

# Create a dictionary to store file paths and their extracted methods (for the debug log)
$debugLogFileData = @{}

# Create the log files with a timestamp
$timestamp = Get-Date -Format "yyyyMMddHHmmss"

# Log files will now be created in the root directory, not the script directory
$filePrefix = "$workingDir\Saropa-Flutter-Method-Analysis-$timestamp"

# lots of good outputs to review manually
$reportLogFile = "$filePrefix.unused.log"
$usedLogFile = "$filePrefix.used.log"
$localCandidatesLogFile = "$filePrefix.localizable.log"
$duplicateMethodsLogFile = "$filePrefix.duplicates.log"
$debugLogFile = "$filePrefix.debug.log"
$warningLogFile = "$filePrefix.warnings.log" # File to store all warnings

####################################################################################################
# --- First Pass ---
####################################################################################################
$pass1Index = 0
$totalFiles = $sortedDartFiles.Count
Write-Output "`r`nStarting Pass 1: Extracting method names and identifying duplicates from $totalFiles files..."

# Redirect warnings to file and console. This ensures that the script continues execution even if warnings occur.
$WarningPreference = "Continue"

#  This is the crucial part. It tells PowerShell to "tee" the warnings, meaning to output them both to the console (standard behavior) and to a file.
$WarningAction = "Tee"

# This specifies the file where the warnings will be saved.
$WarningFile = $warningLogFile

foreach ($file in $sortedDartFiles) {
  # Initialize an empty array for the current file's debug data
  $debugLogFileData[$file.FullName] = @{}

  # Read the entire file content line by line
  $fileContent = Get-Content -Path $file.FullName
  $lineNumber = 1

  $insideClassBlock = $false
  $ignoreNextMethod = $false # Flag to indicate if the next method should be ignored

  foreach ($line in $fileContent) {
    # Check for @saropaAnalysisIgnore annotation
    if ($line -match $ignoreAnnotationRegex) {
      $ignoreNextMethod = $true
    }

    # Check if entering or exiting a class, enum, mixin, or extension block
    if ($line -match $classBlockRegex) {
      $insideClassBlock = $true
    }
    elseif ($insideClassBlock -and $line -match '^\}') {
      $insideClassBlock = $false
    }

    # Process method extraction only if inside a class, enum, mixin, or extension block
    if ($insideClassBlock) {
      $regexMatches = $methodRegex.Matches($line)
      if ($regexMatches.Count -gt 0) {
        $isOverride = $regexMatches[0].Groups[1].Value -ne ''  # Check if @override is present
        $methodName = $regexMatches[0].Groups[2].Value
        $isIgnored = $false

        # --- Exclusion Checks ---
        # Exclude methods shorter than the minimum length
        if ($methodName.Length -lt $minimumMethodNameLength) {
          $isIgnored = $true
        }

        # Exclude numeric method names
        if (!$isIgnored -and $methodName -match '^\d+$') {
          $isIgnored = $true
        }

        # Always exclude underscore methods
        if (!$isIgnored -and $methodName.StartsWith('_')) {
          $isIgnored = $true
        }

        # Exclude if in the keyword dictionary
        if (!$isIgnored -and ($flutterKeywordDictionary -contains $methodName)) {
          $isIgnored = $true
        }

        # Exclude if it's an override
        if ($isOverride) {
          $isIgnored = $true
        }

        # Check if the method should be ignored due to the annotation
        if ($ignoreNextMethod) {
          $isIgnored = $true
          $ignoreNextMethod = $false  # Reset the flag
        }

        # Add the method name and its defining file to the $methodNames hashtable
        if (!$isIgnored) {
          $methodNames[$methodName] = @{
            "File" = $file.FullName
            "Line" = $lineNumber
          }

          if ($DuplicateMethodNames.ContainsKey($methodName)) {
            # If the method name already exists, check if it's in a different file.
            $isDuplicateInDifferentFile = $true
            foreach ($existingLocation in $DuplicateMethodNames[$methodName]) {
              if ($existingLocation -like "$($file.FullName):*") {
                $isDuplicateInDifferentFile = $false
                break
              }
            }
            if ($isDuplicateInDifferentFile) {
              # Append the new file path and line number to the existing entry.
              $DuplicateMethodNames[$methodName] += ("{0}:{1}" -f $file.FullName, $lineNumber)
            }
          }
          else {
            # If the method name doesn't exist, add it to the hashtable.
            $DuplicateMethodNames[$methodName] = @("{0}:{1}" -f $file.FullName, $lineNumber)
          }
        }

        # Debugging: Log all extracted method names, counts, and file names to the debug log
        # Add an asterisk to indicate methods that would be ignored
        if ($isIgnored) {
          if ($debugLogFileData[$file.FullName].ContainsKey($methodName + "*")) {
            $debugLogFileData[$file.FullName][$methodName + "*"]++
          }
          else {
            $debugLogFileData[$file.FullName][$methodName + "*"] = 1
          }
        }
        else {
          if ($debugLogFileData[$file.FullName].ContainsKey($methodName)) {
            $debugLogFileData[$file.FullName][$methodName]++
          }
          else {
            $debugLogFileData[$file.FullName][$methodName] = 1
          }
        }
      }
    }
    $lineNumber++
  }

  # Update progress bar for the first pass
  $pass1Index++
  $progressPercent1 = [math]::Round(($pass1Index / $totalFiles) * 100, 2)
  $status1 = "  $([string]::Format("{0,5:F2}", $progressPercent1))% - $($file.Name)"

  Write-Progress -Activity "Pass 1 of 2: Extracting method names" -Status $status1 -PercentComplete $progressPercent1
}

####################################################################################################
# --- Second Pass ---
####################################################################################################
$pass2Index = 0
$totalMethods = $methodNames.Keys.Count
Write-Output "`r`nStarting Pass 2: Counting method usage for $totalMethods methods..."

foreach ($methodName in $methodNames.Keys | Sort-Object) {
  $usageCount = 0
  $definingFilePath = $methodNames[$methodName].File

  # Escape the method name for use in the regex pattern
  $escapedMethodName = [regex]::Escape($methodName)

  # More general regex to capture method calls, including extension methods
  $usageRegex = [regex]"(?:\bawait\s+)?(?:[\w<>,.]+\s*\.)?\b$escapedMethodName\s*(?:\(|)"

  foreach ($file in $sortedDartFiles) {
    # Check if the file exists before trying to read it
    if (Test-Path -Path $file.FullName) {
      # Read the file content
      $fileContent = Get-Content -Path $file.FullName -Raw

      # Remove comments before matching
      $fileContentWithoutComments = [regex]::Replace($fileContent, "//.*|/\*[\s\S]*?\*/", "")

      # Count usages in the current file
      $usageMatches = $usageRegex.Matches($fileContentWithoutComments)
      $usageCount += $usageMatches.Count
    }
    else {
      Write-Warning "File not found: $($file.FullName)" -WarningVariable +Warnings
    }
  }

  # Subtract 1 if the method/enum is used in its own definition
  if ($methodNames.ContainsKey($methodName)) {
    # Check if the file exists before trying to read it
    if (Test-Path -Path $methodNames[$methodName].File) {
      $definingFileContent = Get-Content -Path $methodNames[$methodName].File -Raw

      # Escape the method name before using it in the regex.
      $escapedMethodNameForDefinition = [regex]::Escape($methodName)
      # Check for method definition OR enum value definition
      # Updated regex using lookahead and lookbehind
      if ($definingFileContent -match "(?m)(?<![\w\.])(?:static\s+)?(?:[\w.<> ]+\s+)?$escapedMethodNameForDefinition\s*(?=(?:\(|{\s*|\=\>\s*))|enum\s+$escapedMethodNameForDefinition\s*(?=\{)") {
        if ($methodName -notmatch '^(?:operator|get|set)$') {
          $usageCount--
        }
      }
    }
    else {
      Write-Warning "File not found: $($file.FullName)" -WarningVariable +Warnings
    }
  }

  # Add method usage data to the $methodUsage hashtable
  $methodUsage[$methodName] = $usageCount

  # Update progress bar for the second pass (per method)
  $pass2Index++
  $progressPercent2 = [math]::Round(($pass2Index / $totalMethods) * 100, 2)
  $status2 = "  $([string]::Format("{0,5:F2}", $progressPercent2))% - $methodName"

  Write-Progress -Activity "Pass 2 of 2: Analyzing method usage" -Status $status2 -PercentComplete $progressPercent2
}

####################################################################################################
# --- Create Reports ---
####################################################################################################

# Sort methods by key (method name)
$sortedMethods = $methodUsage.GetEnumerator() | Sort-Object Key

# Filter methods based on usage and exclusions
$unusedMethods = @()
$usedMethods = @()
$localCandidates = @()

foreach ($entry in $sortedMethods) {
  $methodName = $entry.Key
  $filePath = $methodNames[$methodName].File
  $usageCount = $entry.Value

  # Check if the method is used
  if ($usageCount -gt 0) {
    $usedMethods += $entry
  }
  else {
    $unusedMethods += $entry
  }

  # Check if method is only used locally (within the defining file)
  if ($usageCount -gt 0) {
    $definingFilePath = $methodNames[$methodName].File

    # Check if the method is used in any file OTHER than the one it's defined in
    $usedInOtherFiles = $false
    foreach ($file in $sortedDartFiles) {
      if ($file.FullName -ne $definingFilePath) {
        # Check if the file exists before processing
        if (Test-Path -Path $file.FullName) {
          $fileContent = Get-Content -Path $file.FullName -Raw -Encoding UTF8
          $fileContentWithoutComments = [regex]::Replace($fileContent, "//.*|/\*[\s\S]*?\*/", "")
          $localUsageRegex = [regex]"(?:\bawait\s+)?(?:[\w\.]+\s*\.)?\b$([regex]::Escape($methodName))\s*\("
          $localUsages = $localUsageRegex.Matches($fileContentWithoutComments).Count
          if ($localUsages -gt 0) {
            $usedInOtherFiles = $true
            break
          }
        }
        else {
          Write-Warning "File not found: $($file.FullName)"
        }
      }
    }

    # If the method is NOT used in any other file, it's a local candidate
    if (-not $usedInOtherFiles) {
      $localCandidates += @{
        Method = $methodName
        File   = $filePath
        Line   = $methodNames[$methodName].Line
      }
    }
  }
}

# End time and runtime calculation
$endTime = Get-Date
$runTime = New-TimeSpan -Start $startTime -End $endTime
Write-Output ("End Time: {0}" -f $endTime)
Write-Output ("Run Time: {0}" -f $runTime)

# Summary
$summary = @"

Summary:
Unused methods count: $($unusedMethods.Count)
Used methods count: $($usedMethods.Count)
Total methods analyzed: $($methodNames.Count)
Run time: $($runTime.ToString())

================================================================================================

"@

# Write the summary to the report log file
Add-Content -Path $reportLogFile -Value $summary -Encoding UTF8

# Add copyright notice and uncolored ASCII art to log files
$logHeader = @"
$uncoloredCopyright
$(Get-SaropaLogoUncolored)
"@

# Function to create log file headers
function New-LogFileHeader {
  param(
    [string]$logFile,
    [string]$logTitle,
    [string]$summaryContent
  )

  Add-Content -Path $logFile -Value $logHeader -Encoding UTF8
  Add-Content -Path $logFile -Value "Summary of $logTitle`:" -Encoding UTF8
  Add-Content -Path $logFile -Value $summaryContent -Encoding UTF8
  Add-Content -Path $logFile -Value "####################################################################################################" -Encoding UTF8
  Add-Content -Path $logFile -Value "####################                               $logTitle                               ####################" -Encoding UTF8
  Add-Content -Path $logFile -Value "####################################################################################################`r`n" -Encoding UTF8
}

# Create headers for each log file
$unusedMethodsSummary = "Unused methods count: $($unusedMethods.Count)"
New-LogFileHeader -logFile $reportLogFile -logTitle "UNUSED METHODS REPORT" -summaryContent $unusedMethodsSummary

$usedMethodsSummary = "Used methods count: $($usedMethods.Count)"
New-LogFileHeader -logFile $usedLogFile -logTitle "USED METHODS" -summaryContent $usedMethodsSummary

$localCandidatesSummary = "Local candidates count: $($localCandidates.Count)"
New-LogFileHeader -logFile $localCandidatesLogFile -logTitle "LOCAL CANDIDATES" -summaryContent $localCandidatesSummary

$debugLogSummary = "Debug log of method extraction and usage analysis."
New-LogFileHeader -logFile $debugLogFile -logTitle "DEBUG LOG" -summaryContent $debugLogSummary

# Create header for duplicate methods log
$duplicateMethodsSummary = "Duplicate methods count: $($trueDuplicateMethods.Count)"
New-LogFileHeader -logFile $duplicateMethodsLogFile -logTitle "DUPLICATE METHODS" -summaryContent $duplicateMethodsSummary

# Output methods grouped by file
$methodCategories = @{
  "UNUSED METHODS" = $unusedMethods
  "USED METHODS"   = $usedMethods
}

$logFiles = @{
  "UNUSED METHODS" = $reportLogFile
  "USED METHODS"   = $usedLogFile
}

foreach ($categoryName in $methodCategories.Keys) {
  $logFile = $logFiles[$categoryName]

  $methodsByCategory = $methodCategories[$categoryName]

  # Group methods by file
  $groupedMethods = $methodsByCategory | Group-Object { $methodNames[$_.Key].File } # Group by file path

  foreach ($fileGroup in $groupedMethods) {
    foreach ($entry in $fileGroup.Group) {
      $method = $entry.Key
      $count = $entry.Value
      $line = $methodNames[$method].Line
      $filePath = $fileGroup.Name

      # Updated format: File and line number on one line, method on the next
      Add-Content -Path $logFile -Value ("`r`nFile: {0}:{1}" -f $filePath, $line) -Encoding UTF8
      Add-Content -Path $logFile -Value ("  Usages: {0, -3} {1}" -f $count, $method) -Encoding UTF8
    }
    Add-Content -Path $logFile -Value "" -Encoding UTF8
  }
}

####################################################################################################
# --- Local Candidates Log ---
####################################################################################################

# Group local candidates by file and add a line break before each file name
$groupedLocalCandidates = $localCandidates | Group-Object File

foreach ($fileGroup in $groupedLocalCandidates) {
  # Add-Content -Path $localCandidatesLogFile "`r`nFile: $($fileGroup.Name)" -Encoding UTF8
  foreach ($entry in $fileGroup.Group) {
    # Updated format: File and line number on one line, method on the next
    Add-Content -Path $localCandidatesLogFile ("`r`nFile: {0}:{1}" -f $entry.File, $entry.Line) -Encoding UTF8
    Add-Content -Path $localCandidatesLogFile ("  {0}" -f $entry.Method) -Encoding UTF8
  }
}

####################################################################################################
# --- Duplicate Methods Log ---
####################################################################################################

# Filter out methods that only appear once (not duplicates)
$trueDuplicateMethods = $DuplicateMethodNames.GetEnumerator() | Where-Object { ($_.Value -split ', ').Count -gt 1 }

# Print out all duplicate method names and their file paths
foreach ($entry in $trueDuplicateMethods) {
  # Count the number of duplicates for this class name
  $count = ($entry.Value -split ', ').Count

  Add-Content -Path $duplicateMethodsLogFile -Value ("`nDuplicate method name: " + $entry.Key + " ($count)") -Encoding UTF8
  foreach ($filePath in ($entry.Value -split ', ')) {
    Add-Content -Path $duplicateMethodsLogFile -Value ("   - " + $filePath) -Encoding UTF8
  }
}

####################################################################################################
# --- Debug Log ---
####################################################################################################

# Write the grouped debug log data to the debug log file
foreach ($file in $debugLogFileData.Keys | Sort-Object) {
  $methodCounts = $debugLogFileData[$file]
  if ($methodCounts.Keys.Count -gt 0) {
    Add-Content -Path $debugLogFile "`r`nFile: $file" -Encoding UTF8
    foreach ($methodName in ($methodCounts.Keys | Sort-Object)) {
      $count = $methodCounts[$methodName]
      # Display method name with count, removing "Extracted Method:"
      Add-Content -Path $debugLogFile ("  {0} ({1})" -f $methodName, $count) -Encoding UTF8
    }
  }
}

# Check if there are any methods with non-zero usage before writing to the debug log
if ($methodUsage.GetEnumerator() | Where-Object { $_.Value -gt 0 }) {
  # Write the method usage details to the debug log file
  $debugLogContent = $methodUsage.GetEnumerator() | Sort-Object Key | ForEach-Object {
    $method = $_.Key

    # Check if the key exists in $methodNames before accessing its properties
    if ($methodNames.ContainsKey($method)) {
      $filePath = $methodNames[$method].File
      $lineNumber = $methodNames[$method].Line
      $usages = $_.Value

      # Create a relative path
      $relativePath = $filePath.Substring($workingDir.Length + 1)

      # Format the output for each method
      "{0,-40} {1,-10} Line: {2,-5} {3}" -f $method, $usages, $lineNumber, $relativePath
    }
    else {
      # Handle the case where the key is not found (optional: log an error or warning)
      Write-Warning "Method '$method' not found in method definitions." -WarningVariable +Warnings
      "{0,-40} {1,-10} Line: N/A     File: N/A" -f $method, $_.Value
    }
  }

  # Add headers to the debug log
  $debugLogHeaders = "{0,-40} {1,-10} {2,-5} {3}" -f "Method", "Usages", "Line", "File"
  $debugLogContent = $debugLogHeaders, $debugLogContent

  # Add the list of processed file paths to the debug log
  Add-Content -Path $debugLogFile "`r`nProcessed File Paths:" -Encoding UTF8
  $debugLogFilePaths | Add-Content -Path $debugLogFile -Encoding UTF8

  Write-Output "Debug log created at: $debugLogFile"
}

# Add header for warning log
$warningLogSummary = "Log of warnings encountered during analysis."
New-LogFileHeader -logFile $warningLogFile -logTitle "WARNING LOG" -summaryContent $warningLogSummary

Write-Output "Log file created at: $reportLogFile"
Write-Output "Used methods log file created at: $usedLogFile"
Write-Output "Local candidates log file created at: $localCandidatesLogFile"
Write-Output "Duplicate methods log file created at: $duplicateMethodsLogFile"
Write-Output "Warning log file created at: $warningLogFile"

Write-Output "Analysis complete!"

# Play a completion sound
[System.Media.SystemSounds]::Exclamation.Play()


# # Ask the user if they want to open the log files
# if ((Read-Host "Open log files now? (y/n)") -eq 'y') {
#   # Use notepad.exe to open the files (more reliable)
#   & notepad.exe $reportLogFile
#   & notepad.exe $usedLogFile
#   & notepad.exe $localCandidatesLogFile
#   & notepad.exe $debugLogFile
#   & notepad.exe $duplicateMethodsLogFile
#   & notepad.exe $warningLogFile
# }
