# Saropa Lints Runner

A simple VS Code extension that adds a button and keyboard shortcut to run Saropa custom lints.

## Features

- **Status bar button**: Click "Lints" in the status bar to run custom lints
- **Editor title button**: A search icon appears in the editor title bar when viewing Dart files
- **Keyboard shortcut**: `Ctrl+Shift+B` (or `Cmd+Shift+B` on Mac) runs the lints

## Installation

### Recommended: Use the installer script

From the saropa_lints package root:

```bash
python scripts/modules/_install_vscode_extension.py
```

The script will:
- Detect your VS Code installation (including VS Code Insiders)
- Copy the extension to the correct location
- Handle existing installations

Then restart VS Code.

### Alternative: Manual installation

Copy this folder to your VS Code extensions directory:

- **Windows**: `%USERPROFILE%\.vscode\extensions\saropa-lints-runner`
- **macOS/Linux**: `~/.vscode/extensions/saropa-lints-runner`

Then restart VS Code.

## Usage

1. Open a Dart/Flutter project that uses `saropa_lints`
2. Click the "Lints" button in the status bar, or press `Ctrl+Shift+B`
3. View results in the Problems panel (`Ctrl+Shift+M`)

## Requirements

- VS Code 1.74.0 or higher
- Dart SDK
- Project must have `custom_lint` in dev_dependencies
