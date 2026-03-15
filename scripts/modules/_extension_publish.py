"""
VS Code extension package and publish for saropa_lints.

Syncs extension version with package version, compiles, packages .vsix,
and optionally publishes to VS Code Marketplace and Open VSX.
Steps are sequential by design (compile → package → publish); no parallelism.

Used by the unified publish.py workflow (package and extension are
intrinsically linked).

Version:   1.0
Author:    Saropa
Copyright: (c) 2025-2026 Saropa
"""

from __future__ import annotations

import os
import platform
import re
from pathlib import Path

from scripts.modules._utils import (
    print_colored,
    print_error,
    print_info,
    print_success,
    print_warning,
    run_command,
    Color,
)


def _extension_dir(project_dir: Path) -> Path:
    return project_dir / "extension"


def extension_exists(project_dir: Path) -> bool:
    """Return True if the extension directory exists with package.json."""
    ext = _extension_dir(project_dir)
    return ext.is_dir() and (ext / "package.json").is_file()


def copy_changelog_to_extension(project_dir: Path) -> bool:
    """Copy root CHANGELOG.md to extension/CHANGELOG.md for the .vsix (single source of truth).

    Returns True if copied, False if root CHANGELOG.md missing.
    """
    root_changelog = project_dir / "CHANGELOG.md"
    ext_changelog = _extension_dir(project_dir) / "CHANGELOG.md"
    if not root_changelog.is_file():
        return False
    ext_changelog.write_text(root_changelog.read_text(encoding="utf-8"), encoding="utf-8")
    return True


def set_extension_version(project_dir: Path, version: str) -> bool:
    """Set extension/package.json version to match the package version.

    Returns True if updated (or already matched), False on error.
    """
    pkg_path = _extension_dir(project_dir) / "package.json"
    if not pkg_path.exists():
        return False
    text = pkg_path.read_text(encoding="utf-8")
    # Match "version": "X.Y.Z" or "version": "X.Y.Z-pre.N"
    new_text, n = re.subn(
        r'"version"\s*:\s*"[^"]*"',
        f'"version": "{version}"',
        text,
        count=1,
    )
    if n == 0:
        return False
    pkg_path.write_text(new_text, encoding="utf-8")
    return True


def run_extension_compile(project_dir: Path) -> bool:
    """Run npm run compile in extension directory. Returns True on success."""
    ext_dir = _extension_dir(project_dir)
    r = run_command(
        ["npm", "run", "compile"],
        ext_dir,
        "Compile extension",
        capture_output=True,
        allow_failure=True,
    )
    if r.returncode != 0:
        if r.stderr:
            print_error(r.stderr.strip())
        if r.stdout:
            print_error(r.stdout.strip())
        return False
    return True


def run_extension_package(project_dir: Path) -> Path | None:
    """Package .vsix with vsce. Returns path to .vsix or None on failure."""
    ext_dir = _extension_dir(project_dir)
    r = run_command(
        ["npx", "@vscode/vsce", "package", "--no-dependencies"],
        ext_dir,
        "Package .vsix",
        capture_output=True,
        allow_failure=True,
    )
    if r.returncode != 0:
        if r.stderr:
            print_error(r.stderr.strip())
        if r.stdout:
            print_error(r.stdout.strip())
        return None
    vsix = next(ext_dir.glob("*.vsix"), None)
    return vsix


def install_extension(vsix_path: Path) -> bool:
    """Install .vsix into VS Code locally. Returns True on success."""
    r = run_command(
        ["code", "--install-extension", str(vsix_path)],
        vsix_path.parent,
        "Install extension locally",
        capture_output=True,
        allow_failure=True,
    )
    if r.returncode != 0:
        if r.stderr:
            print_error(r.stderr.strip())
        if r.stdout:
            print_error(r.stdout.strip())
        return False
    print_success(f"Installed {vsix_path.name} locally")
    return True


def publish_extension_to_marketplace(
    project_dir: Path, vsix_path: Path
) -> bool:
    """Publish .vsix to VS Code Marketplace via vsce. Returns True on success."""
    ext_dir = _extension_dir(project_dir)
    r = run_command(
        [
            "npx",
            "@vscode/vsce",
            "publish",
            "--packagePath",
            str(vsix_path),
        ],
        ext_dir,
        "Publish to VS Code Marketplace",
        capture_output=True,
        allow_failure=True,
    )
    if r.returncode != 0:
        if r.stderr:
            print_error(r.stderr.strip())
        if r.stdout:
            print_error(r.stdout.strip())
        return False
    return True


def _prompt_for_ovsx_pat() -> str:
    """Prompt user for OVSX_PAT when not set. Returns token or empty string to skip."""
    print_warning("OVSX_PAT environment variable not set.")
    print_info("Open VSX requires a Personal Access Token (PAT) to publish.")
    print_info("Get one at: https://open-vsx.org/user-settings/tokens")
    print()
    # Show platform-specific instructions for setting it permanently
    is_windows = platform.system() == "Windows"
    if is_windows:
        print_colored(
            "  To set permanently (PowerShell):",
            Color.DIM,
        )
        print_colored(
            '    [Environment]::SetEnvironmentVariable("OVSX_PAT", "your-token", "User")',
            Color.WHITE,
        )
        print_colored(
            "  Or for current session only:",
            Color.DIM,
        )
        print_colored(
            '    $env:OVSX_PAT = "your-token"',
            Color.WHITE,
        )
    else:
        print_colored(
            "  To set permanently, add to ~/.bashrc or ~/.zshrc:",
            Color.DIM,
        )
        print_colored(
            '    export OVSX_PAT="your-token"',
            Color.WHITE,
        )
    print()
    token = input("  Paste your Open VSX PAT now (or press Enter to skip): ").strip()
    if token:
        # Set for this process so subsequent calls work without re-prompting
        os.environ["OVSX_PAT"] = token
    return token


def publish_extension_to_ovsx(project_dir: Path, vsix_path: Path) -> bool:
    """Publish .vsix to Open VSX. Prompts for PAT if not set. Returns True on success or skip."""
    ovsx_pat = os.environ.get("OVSX_PAT", "").strip()
    if not ovsx_pat:
        ovsx_pat = _prompt_for_ovsx_pat()
        if not ovsx_pat:
            print_info("Skipping Open VSX publish.")
            return True
    ext_dir = _extension_dir(project_dir)
    r = run_command(
        ["npx", "ovsx", "publish", str(vsix_path), "-p", ovsx_pat],
        ext_dir,
        "Publish to Open VSX",
        capture_output=True,
        allow_failure=True,
    )
    if r.returncode != 0:
        if r.stderr:
            print_error(r.stderr.strip())
        if r.stdout:
            print_error(r.stdout.strip())
        return False
    return True


def package_extension(project_dir: Path, version: str) -> Path | None:
    """Sync version, copy root changelog, compile, and package .vsix. Returns path to .vsix or None."""
    if not set_extension_version(project_dir, version):
        print_warning("Could not set extension version in package.json")
    if not copy_changelog_to_extension(project_dir):
        print_warning("Root CHANGELOG.md not found; extension .vsix will have no changelog.")
    if not run_extension_compile(project_dir):
        return None
    vsix = run_extension_package(project_dir)
    if vsix:
        print_success(f"Packaged: {vsix.name}")
    return vsix


def publish_extension(project_dir: Path, vsix_path: Path) -> bool:
    """Publish to Marketplace then Open VSX (if OVSX_PAT set). Returns True if both succeed or skip."""
    if not publish_extension_to_marketplace(project_dir, vsix_path):
        return False
    return publish_extension_to_ovsx(project_dir, vsix_path)
