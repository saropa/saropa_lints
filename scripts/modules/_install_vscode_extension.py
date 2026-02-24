#!/usr/bin/env python3
"""
Install the Saropa Lints VS Code extension.

This script installs the VS Code extension that adds a status bar button
and editor title icon for running custom lints with a single click.

Version:   1.0
Author:    Saropa
Copyright: (c) 2025 Saropa

Platforms:
    - Windows
    - macOS
    - Linux

Usage:
    python scripts/install_vscode_extension.py

The extension adds:
    - Status bar button: Click "Lints" to run dart analyze
    - Editor title icon: Bug icon when viewing Dart files
    - Keyboard shortcut: Ctrl+Shift+B (same as build task)

Exit Codes:
    0 - Success
    1 - Extension source not found
    2 - VS Code extensions folder not found
    3 - Copy failed
    4 - User canceled
"""

from __future__ import annotations

import shutil
import sys
from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import NoReturn


SCRIPT_VERSION = "1.0"
EXTENSION_NAME = "saropa-lints-runner"
EXTENSION_VERSION = "1.0.0"


# =============================================================================
# EXIT CODES
# =============================================================================

class ExitCode(Enum):
    """Standard exit codes."""
    SUCCESS = 0
    SOURCE_NOT_FOUND = 1
    VSCODE_NOT_FOUND = 2
    COPY_FAILED = 3
    USER_CANCELLED = 4


# =============================================================================
# COLOR AND PRINTING
# =============================================================================

class Color(Enum):
    """ANSI color codes."""
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    RED = "\033[91m"
    CYAN = "\033[96m"
    MAGENTA = "\033[95m"
    WHITE = "\033[97m"
    RESET = "\033[0m"


def enable_ansi_support() -> None:
    """Enable ANSI escape sequence support on Windows."""
    if sys.platform == "win32":
        try:
            import ctypes
            from ctypes import wintypes

            kernel32 = ctypes.windll.kernel32

            # Constants
            STD_OUTPUT_HANDLE = -11
            ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004

            # Get stdout handle
            handle = kernel32.GetStdHandle(STD_OUTPUT_HANDLE)

            # Get current console mode
            mode = wintypes.DWORD()
            kernel32.GetConsoleMode(handle, ctypes.byref(mode))

            # Enable virtual terminal processing
            new_mode = mode.value | ENABLE_VIRTUAL_TERMINAL_PROCESSING
            kernel32.SetConsoleMode(handle, new_mode)
        except Exception:
            pass


# cspell: disable
def show_saropa_logo() -> None:
    """Display the Saropa 'S' logo in ASCII art."""
    logo = """
\033[38;5;208m                               ....\033[0m
\033[38;5;208m                       `-+shdmNMMMMNmdhs+-\033[0m
\033[38;5;209m                    -odMMMNyo/-..````.++:+o+/-\033[0m
\033[38;5;215m                 `/dMMMMMM/`          ``````````\033[0m
\033[38;5;220m                `dMMMMMMMMNdhhhdddmmmNmmddhs+-\033[0m
\033[38;5;226m                /MMMMMMMMMMMMMMMMMMMMMMMMMMMMMNh\\\033[0m
\033[38;5;190m              . :sdmNNNNMMMMMNNNMMMMMMMMMMMMMMMMm+\033[0m
\033[38;5;154m              o     `..~~~::~+==+~:/+sdNMMMMMMMMMMMo\033[0m
\033[38;5;118m              m                        .+NMMMMMMMMMN\033[0m
\033[38;5;123m              m+                         :MMMMMMMMMm\033[0m
\033[38;5;87m              /N:                        :MMMMMMMMM/\033[0m
\033[38;5;51m               oNs.                    `+NMMMMMMMMo\033[0m
\033[38;5;45m                :dNy/.              ./smMMMMMMMMm:\033[0m
\033[38;5;39m                 `/dMNmhyso+++oosydNNMMMMMMMMMd/\033[0m
\033[38;5;33m                    .odMMMMMMMMMMMMMMMMMMMMdo-\033[0m
\033[38;5;57m                       `-+shdNNMMMMNNdhs+-\033[0m
\033[38;5;57m                               ````\033[0m
"""
    print(logo)
    current_year = datetime.now().year
    copyright_year = f"2024-{current_year}" if current_year > 2024 else "2024"
    print(f"\033[38;5;195m(c) {copyright_year} Saropa. All rights reserved.\033[0m")
    print("\033[38;5;117mhttps://saropa.com\033[0m")
    print()
# cspell: enable


def print_colored(message: str, color: Color) -> None:
    """Print a message with ANSI color codes."""
    print(f"{color.value}{message}{Color.RESET.value}")


def print_header(text: str) -> None:
    """Print a section header."""
    print()
    print_colored("=" * 70, Color.CYAN)
    print_colored(f"  {text}", Color.CYAN)
    print_colored("=" * 70, Color.CYAN)
    print()


def print_success(text: str) -> None:
    """Print success message."""
    print_colored(f"  [OK] {text}", Color.GREEN)


def print_warning(text: str) -> None:
    """Print warning message."""
    print_colored(f"  [!] {text}", Color.YELLOW)


def print_error(text: str) -> None:
    """Print error message."""
    print_colored(f"  [X] {text}", Color.RED)


def print_info(text: str) -> None:
    """Print info message."""
    print_colored(f"  [>] {text}", Color.MAGENTA)


def exit_with_error(message: str, code: ExitCode) -> NoReturn:
    """Print error and exit."""
    print_error(message)
    sys.exit(code.value)


# =============================================================================
# PLATFORM DETECTION
# =============================================================================

def is_windows() -> bool:
    """Check if running on Windows."""
    return sys.platform == "win32"


def is_macos() -> bool:
    """Check if running on macOS."""
    return sys.platform == "darwin"


def is_linux() -> bool:
    """Check if running on Linux."""
    return sys.platform.startswith("linux")


def get_platform_name() -> str:
    """Get human-readable platform name."""
    if is_windows():
        return "Windows"
    elif is_macos():
        return "macOS"
    elif is_linux():
        return "Linux"
    return "Unknown"


# =============================================================================
# VS CODE EXTENSION PATHS
# =============================================================================

def get_vscode_extensions_dir() -> Path | None:
    """
    Get the VS Code extensions directory for the current platform.

    Returns None if the directory cannot be determined or doesn't exist.
    """
    home = Path.home()

    if is_windows():
        # Windows: %USERPROFILE%\.vscode\extensions
        extensions_dir = home / ".vscode" / "extensions"
    elif is_macos():
        # macOS: ~/.vscode/extensions
        extensions_dir = home / ".vscode" / "extensions"
    elif is_linux():
        # Linux: ~/.vscode/extensions
        extensions_dir = home / ".vscode" / "extensions"
    else:
        return None

    # Check if .vscode directory exists (indicates VS Code is installed)
    vscode_dir = extensions_dir.parent
    if not vscode_dir.exists():
        return None

    return extensions_dir


def get_vscode_insiders_extensions_dir() -> Path | None:
    """Get VS Code Insiders extensions directory."""
    home = Path.home()

    if is_windows():
        extensions_dir = home / ".vscode-insiders" / "extensions"
    else:
        extensions_dir = home / ".vscode-insiders" / "extensions"

    if not extensions_dir.parent.exists():
        return None

    return extensions_dir


# =============================================================================
# INSTALLATION
# =============================================================================

def find_extension_source(script_dir: Path) -> Path | None:
    """Find the extension source directory."""
    project_dir = script_dir.parent
    extension_dir = project_dir / "vscode-saropa-lints"

    if extension_dir.exists() and (extension_dir / "package.json").exists():
        return extension_dir

    return None


def install_extension(source_dir: Path, extensions_dir: Path) -> bool:
    """
    Install the extension by copying to VS Code extensions directory.

    Returns True on success, False on failure.
    """
    target_dir = extensions_dir / EXTENSION_NAME

    # Check if already installed
    if target_dir.exists():
        print_warning(f"Extension already exists at: {target_dir}")
        response = input("  Overwrite existing installation? [y/N] ").strip().lower()
        if not response.startswith("y"):
            print_info("Installation canceled")
            return False

        # Remove existing installation
        print_info("Removing existing installation...")
        try:
            shutil.rmtree(target_dir)
            print_success("Removed existing installation")
        except Exception as e:
            print_error(f"Failed to remove existing installation: {e}")
            return False

    # Create extensions directory if needed
    if not extensions_dir.exists():
        print_info(f"Creating extensions directory: {extensions_dir}")
        try:
            extensions_dir.mkdir(parents=True, exist_ok=True)
        except Exception as e:
            print_error(f"Failed to create extensions directory: {e}")
            return False

    # Remove duplicate menu entry from package.json before copying
    pkg_path = source_dir / "package.json"
    if pkg_path.exists():
        try:
            import json
            with open(pkg_path, "r", encoding="utf-8") as f:
                pkg = json.load(f)
            menus = pkg.get("contributes", {}).get("menus", {})
            if "editor/title/run" in menus:
                del menus["editor/title/run"]
                pkg["contributes"]["menus"] = menus
                with open(pkg_path, "w", encoding="utf-8") as f:
                    json.dump(pkg, f, indent=2)
                print_success("Removed duplicate 'editor/title/run' menu from package.json")
        except Exception as e:
            print_warning(f"Could not clean up package.json: {e}")

    # Copy extension
    print_info(f"Copying extension to: {target_dir}")
    try:
        shutil.copytree(source_dir, target_dir)
        print_success("Extension files copied successfully")
        return True
    except Exception as e:
        print_error(f"Failed to copy extension: {e}")
        return False


def display_extension_info(source_dir: Path) -> None:
    """Display extension information."""
    print_colored("  Extension Information:", Color.WHITE)
    print_colored(f"      Name:    {EXTENSION_NAME}", Color.CYAN)
    print_colored(f"      Version: {EXTENSION_VERSION}", Color.CYAN)
    print()

    print_colored("  Features:", Color.WHITE)
    print_colored("      - Status bar button: Click 'Lints' to run dart analyze", Color.CYAN)
    print_colored("      - Editor title icon: Bug icon when viewing Dart files", Color.CYAN)
    print_colored("      - Keyboard shortcut: Ctrl+Shift+B (Cmd+Shift+B on Mac)", Color.CYAN)
    print()


def display_post_install_instructions() -> None:
    """Display post-installation instructions."""
    print()
    print_colored("  Next Steps:", Color.WHITE)
    print_colored("      1. Restart VS Code (or reload the window)", Color.CYAN)
    print_colored("      2. Open a Dart/Flutter project with saropa_lints", Color.CYAN)
    print_colored("      3. Look for the 'Lints' button in the status bar", Color.CYAN)
    print()
    print_colored("  Keyboard Shortcut:", Color.WHITE)
    if is_macos():
        print_colored("      Cmd+Shift+B - Run Saropa Lints", Color.CYAN)
    else:
        print_colored("      Ctrl+Shift+B - Run Saropa Lints", Color.CYAN)
    print()


# =============================================================================
# MAIN
# =============================================================================

def main() -> int:
    """Main entry point."""
    enable_ansi_support()
    show_saropa_logo()
    print_colored(f"  VS Code Extension Installer v{SCRIPT_VERSION}", Color.MAGENTA)
    print()

    # Find script and project directories
    script_dir = Path(__file__).parent

    print_header("VS CODE EXTENSION INSTALLER")

    # Step 1: Find extension source
    print_header("STEP 1: LOCATING EXTENSION SOURCE")

    source_dir = find_extension_source(script_dir)
    if source_dir is None:
        exit_with_error(
            "Extension source not found. Expected at: vscode-saropa-lints/",
            ExitCode.SOURCE_NOT_FOUND
        )

    print_success(f"Found extension at: {source_dir}")
    print()
    display_extension_info(source_dir)

    # Step 2: Find VS Code extensions directory
    print_header("STEP 2: DETECTING VS CODE INSTALLATION")

    print_info(f"Platform: {get_platform_name()}")

    extensions_dir = get_vscode_extensions_dir()
    insiders_dir = get_vscode_insiders_extensions_dir()

    # Cleanup: Remove existing extension from both standard and Insiders
    def cleanup_extension(ext_dir: Path | None, name: str) -> None:
        if ext_dir:
            target = ext_dir / EXTENSION_NAME
            if target.exists():
                print_info(f"Removing existing {name} extension at: {target}")
                try:
                    shutil.rmtree(target)
                    print_success(f"Removed {name} extension")
                except Exception as e:
                    print_warning(f"Failed to remove {name} extension: {e}")

    cleanup_extension(extensions_dir, "VS Code")
    cleanup_extension(insiders_dir, "VS Code Insiders")

    # Determine which VS Code to install to
    target_dir = None
    vscode_variant = None

    if extensions_dir and insiders_dir:
        # Both installed - ask user
        print_success("Found VS Code")
        print_success("Found VS Code Insiders")
        print()
        print_colored("  Which VS Code installation?", Color.WHITE)
        print_colored("      1. VS Code (standard)", Color.CYAN)
        print_colored("      2. VS Code Insiders", Color.CYAN)
        print()
        response = input("  Select [1/2]: ").strip()
        if response == "2":
            target_dir = insiders_dir
            vscode_variant = "VS Code Insiders"
        else:
            target_dir = extensions_dir
            vscode_variant = "VS Code"
    elif extensions_dir:
        target_dir = extensions_dir
        vscode_variant = "VS Code"
        print_success(f"Found {vscode_variant}")
    elif insiders_dir:
        target_dir = insiders_dir
        vscode_variant = "VS Code Insiders"
        print_success(f"Found {vscode_variant}")
    else:
        print_error("VS Code installation not found")
        print()
        print_colored("  Expected extensions directory at:", Color.WHITE)
        if is_windows():
            print_colored("      %USERPROFILE%\\.vscode\\extensions", Color.CYAN)
        else:
            print_colored("      ~/.vscode/extensions", Color.CYAN)
        print()
        print_colored("  Make sure VS Code is installed and has been run at least once.", Color.YELLOW)
        exit_with_error("VS Code not found", ExitCode.VSCODE_NOT_FOUND)

    print_info(f"Target: {target_dir}")

    # Step 3: Install extension
    print_header("STEP 3: INSTALLING EXTENSION")

    if not install_extension(source_dir, target_dir):
        exit_with_error("Installation failed", ExitCode.COPY_FAILED)

    # Success!
    print()
    print_colored("=" * 70, Color.GREEN)
    print_colored(f"  EXTENSION INSTALLED SUCCESSFULLY!", Color.GREEN)
    print_colored("=" * 70, Color.GREEN)

    display_post_install_instructions()

    return ExitCode.SUCCESS.value


if __name__ == "__main__":
    sys.exit(main())
