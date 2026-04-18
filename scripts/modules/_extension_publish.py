"""
VS Code extension package, publish, and store verification for saropa_lints.

Syncs extension version with package version, compiles, packages .vsix,
publishes to VS Code Marketplace and Open VSX, and verifies store
propagation by polling the Marketplace and Open VSX APIs.

Used by the unified publish.py workflow (package and extension are
intrinsically linked).

Version:   2.0
Author:    Saropa
Copyright: (c) 2025-2026 Saropa
"""

from __future__ import annotations

import json
import os
import platform
import re
import time
import urllib.request
from pathlib import Path

from scripts.modules._utils import (
    print_colored,
    print_error,
    print_header,
    print_info,
    print_success,
    print_warning,
    run_command,
    Color,
)

# Publisher management page — shown after every publish attempt so the
# user can verify or manually upload the .vsix when PAT auth fails.
MARKETPLACE_MANAGE_URL = (
    "https://marketplace.visualstudio.com/manage/publishers/Saropa"
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


def run_extension_package(project_dir: Path, version: str) -> Path | None:
    """Package .vsix with vsce. Returns path to .vsix or None on failure.

    Removes stale .vsix files first so the glob cannot return an old
    version (root cause of 9.1.0/9.2.0 never reaching the Marketplace).
    """
    ext_dir = _extension_dir(project_dir)

    # Remove stale .vsix files so the post-package glob only finds the
    # newly created file.  Without this, next(glob("*.vsix")) could
    # return an older .vsix that sorts before the new one alphabetically.
    for old_vsix in ext_dir.glob("*.vsix"):
        old_vsix.unlink()

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

    # Use the expected filename so we never accidentally pick up the
    # wrong file even if something else created a .vsix.
    expected = ext_dir / f"saropa-lints-{version}.vsix"
    if expected.is_file():
        return expected

    # Fallback: grab whatever vsce created (name may differ).
    return next(ext_dir.glob("*.vsix"), None)


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
        # Guide the user to the management page and manual upload
        print_warning(
            "Marketplace publish failed (PAT expired or missing scope?)."
        )
        print_info(f"  Manage: {MARKETPLACE_MANAGE_URL}")
        print_info(
            f"  You can also upload the .vsix manually: {vsix_path.name}"
        )
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
    vsix = run_extension_package(project_dir, version)
    if vsix:
        print_success(f"Packaged: {vsix.name}")
    return vsix


def publish_extension(project_dir: Path, vsix_path: Path) -> bool:
    """Publish to Marketplace then Open VSX (if OVSX_PAT set). Returns True if both succeed or skip."""
    marketplace_ok = publish_extension_to_marketplace(project_dir, vsix_path)
    if marketplace_ok:
        print_info(f"  Manage: {MARKETPLACE_MANAGE_URL}")
    if not marketplace_ok:
        return False
    return publish_extension_to_ovsx(project_dir, vsix_path)


# =============================================================================
# EXTENSION IDENTITY AND STORE VERIFICATION
# =============================================================================


def get_extension_identity(project_dir: Path) -> tuple[str, str]:
    """Read publisher and name from extension/package.json.

    Returns:
        (publisher, name) or ('', '') if unavailable.
    """
    pkg_json = project_dir / "extension" / "package.json"
    if not pkg_json.is_file():
        return ("", "")
    try:
        data = json.loads(pkg_json.read_text(encoding="utf-8"))
        return (data.get("publisher", ""), data.get("name", ""))
    except (json.JSONDecodeError, OSError):
        return ("", "")


def _fetch_marketplace_latest_version(item_name: str) -> str | None:
    """Return latest Marketplace version for publisher.extension, or None on lookup failure."""
    url = (
        "https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery"
    )
    payload = {
        "filters": [
            {
                "criteria": [{"filterType": 7, "value": item_name}],
                "pageNumber": 1,
                "pageSize": 1,
                "sortBy": 0,
                "sortOrder": 0,
            }
        ],
        "assetTypes": [],
        "flags": 103,
    }
    body = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=body,
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json;api-version=7.2-preview.1",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            data = json.loads(response.read().decode("utf-8"))
        results = data.get("results", [])
        if not results:
            return None
        extensions = results[0].get("extensions", [])
        if not extensions:
            return None
        versions = extensions[0].get("versions", [])
        if not versions:
            return None
        return versions[0].get("version")
    except (
        OSError,
        ValueError,
        KeyError,
        TypeError,
    ):
        return None


def _fetch_open_vsx_latest_version(
    publisher: str, extension_name: str,
) -> str | None:
    """Return latest Open VSX version, or None on lookup failure."""
    url = f"https://open-vsx.org/api/{publisher}/{extension_name}"
    try:
        with urllib.request.urlopen(url, timeout=15) as response:
            data = json.loads(response.read().decode("utf-8"))
        version = data.get("version")
        return version if isinstance(version, str) else None
    except (
        OSError,
        ValueError,
        KeyError,
        TypeError,
    ):
        return None


def verify_extension_store_publication(
    publisher: str,
    extension_name: str,
    expected_version: str,
    interval_seconds: int = 30,
    timeout_seconds: int = 600,
) -> bool:
    """Poll Marketplace and Open VSX until both report expected version or timeout.

    Checks every *interval_seconds* for up to *timeout_seconds*. Returns True
    when both stores report *expected_version*, False on timeout.
    """
    print_header("FINAL STEP: STORE PUBLICATION VERIFICATION")
    print_info(
        "Checking Marketplace and Open VSX every "
        f"{interval_seconds}s for up to {timeout_seconds // 60} minutes..."
    )
    item_name = f"{publisher}.{extension_name}"
    attempts = (timeout_seconds // interval_seconds) + 1

    last_marketplace = "unknown"
    last_openvsx = "unknown"
    for attempt in range(1, attempts + 1):
        marketplace_version = _fetch_marketplace_latest_version(item_name)
        open_vsx_version = _fetch_open_vsx_latest_version(
            publisher, extension_name,
        )
        last_marketplace = marketplace_version or "unavailable"
        last_openvsx = open_vsx_version or "unavailable"

        marketplace_ok = marketplace_version == expected_version
        open_vsx_ok = open_vsx_version == expected_version

        if marketplace_ok and open_vsx_ok:
            print_success(
                f"Store propagation complete: Marketplace={marketplace_version}, "
                f"Open VSX={open_vsx_version}"
            )
            return True

        print_info(
            f"Attempt {attempt}/{attempts}: Marketplace={last_marketplace}, "
            f"Open VSX={last_openvsx}"
        )
        if attempt < attempts:
            time.sleep(interval_seconds)

    print_warning(
        "Store propagation not confirmed within 10 minutes. "
        f"Last seen versions: Marketplace={last_marketplace}, "
        f"Open VSX={last_openvsx}."
    )
    return False
