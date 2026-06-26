"""
VS Code extension package, publish, and store verification for saropa_lints.

Syncs extension version with package version, compiles, packages .vsix,
publishes to VS Code Marketplace and Open VSX, and verifies store
propagation by polling the Marketplace and Open VSX APIs.

Used by the unified publish.py workflow (package and extension are
intrinsically linked).

Before compiling the extension, optionally regenerates
``package.nls.<locale>.json`` and runtime locale JSON from the English
sources (dictionary-based; best-effort, non-blocking on failure).

Version:   2.2
Author:    Saropa
Copyright: (c) 2025-2026 Saropa
"""

from __future__ import annotations

import json
import os
import sys
import platform
import re
import time
import urllib.request
from pathlib import Path
from typing import NamedTuple


class StorePublicationResult(NamedTuple):
    """Per-store result from verify_extension_store_publication.

    Each field is True only if that store reports the expected version
    within the polling window. Separate booleans let the caller issue
    targeted warnings (e.g. Marketplace failed but Open VSX succeeded,
    which is the exact scenario that prompted this split — PAT or upload
    silently failing on Marketplace while Open VSX publishes fine).
    """

    marketplace_ok: bool
    open_vsx_ok: bool

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


def extension_vsix_path(project_dir: Path, version: str) -> Path:
    """Path to the packaged VSIX for this version (saropa-lints-x.y.z.vsix)."""
    return _extension_dir(project_dir) / f"saropa-lints-{version}.vsix"


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


def copy_readme_to_extension(project_dir: Path) -> bool:
    """Copy root README.md to extension/README.md for the .vsix (single source of truth).

    The package and the extension are one product; the Marketplace listing
    renders the same README as pub.dev. extension/README.md is gitignored and
    regenerated here so the two listings cannot drift apart.

    Returns True if copied, False if root README.md missing.
    """
    root_readme = project_dir / "README.md"
    ext_readme = _extension_dir(project_dir) / "README.md"
    if not root_readme.is_file():
        return False
    ext_readme.write_text(root_readme.read_text(encoding="utf-8"), encoding="utf-8")
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


def audit_extension_locales(project_dir: Path) -> bool | None:
    """Audit (never translate) extension locale coverage before packaging.

    Publish must not run any machine-translation job — that is an explicit,
    separate operation. This runs ``generate_locales.py --mode audit``, which
    reads the curated dictionaries + existing MT cache only (zero network calls),
    writes the gaps + low-quality report to file, and translates nothing. With
    ``--fail-on-missing`` it exits non-zero when any locale still has a gap, so the
    caller can prompt the operator instead of silently shipping English.

    Returns:
        True when the audit found no gaps, False when gaps remain (or the audit
        errored), None if ``generate_locales.py`` is not present (no extension i18n).
    """
    i18n_dir = _extension_dir(project_dir) / "scripts" / "i18n"
    gen = i18n_dir / "generate_locales.py"
    if not gen.is_file():
        return None
    r = run_command(
        # --mode audit => no translation, no locale-file rewrite, just the report.
        # --fail-on-missing turns a residual gap into a non-zero exit so the caller
        # treats False as a gate failure and prompts rather than shipping English.
        [sys.executable, str(gen), "--mode", "audit", "--fail-on-missing"],
        i18n_dir,
        "Audit extension locale coverage (no translation)",
        capture_output=True,
        allow_failure=True,
    )
    if r.returncode != 0:
        if r.stderr:
            print_warning(r.stderr.strip())
        if r.stdout:
            print_warning(r.stdout.strip())
        return False
    # Success path: --fail-on-missing returned 0, so every locale is fully
    # covered. The full per-locale table + coverage matrix is pure noise on a
    # clean audit; echoing all ~80 lines buries the result. Surface only the
    # one-line confirmation and the report path so the operator can open it if
    # they want detail. (Gaps/low-quality lines only appear on the failure
    # branch above, where they ARE shown as warnings.)
    if r.stdout:
        for line in r.stdout.splitlines():
            stripped = line.strip()
            if "fully translated" in stripped or stripped.endswith(
                "_i18n_translation_audit.md"
            ):
                print_info(f"  {stripped}")
    return True


def _prompt_locale_coverage_failure() -> str:
    """Ask user what to do after the locale coverage AUDIT found gaps.

    Returns 'ignore' | 'retry' | 'abort'. Default (empty input) is Retry — the
    typical recovery is to close gaps (edit dictionaries.py, or run the translator
    separately — publish never translates) and re-audit without aborting the whole
    publish. Ctrl+C / EOF falls through to Abort so the user can always bail hard.
    """
    print_warning("Extension locale coverage AUDIT found gaps. Choose an action:")
    print_colored("  [R]etry the audit (after closing gaps; publish does not translate)  [default]", Color.CYAN)
    print_colored("  [I]gnore and continue (ship with missing translations)", Color.CYAN)
    print_colored("  [A]bort (stop publish)", Color.CYAN)
    try:
        raw = input("  Choice [R/i/a]: ").strip().lower() or "r"
        if raw.startswith("i"):
            return "ignore"
        if raw.startswith("a"):
            return "abort"
        return "retry"
    except (EOFError, KeyboardInterrupt):
        return "abort"


def regenerate_rule_catalog(project_dir: Path) -> bool:
    """Regenerate the bundled rule-metadata catalog the extension ships.

    The extension bundles ``extension/media/rules_catalog.json`` (rule name ->
    type/status/security metadata) so the live-diagnostics path can drive the
    Issues-panel metadata filters and hotspot review without a stale export. The
    catalog is byte-derived from the rule definitions, so it must be regenerated
    at package time — otherwise a rule added or retuned since the last manual run
    would ship a stale catalog and the filters would mis-bucket it. Mirrors the
    locale coverage gate's "regenerate generated assets before packaging" role.

    Non-fatal: a generation failure prints a warning and lets the (committed)
    catalog ship, rather than aborting the whole publish over a tooling hiccup.
    """
    r = run_command(
        ["dart", "run", "saropa_lints:generate_rule_catalog"],
        project_dir,
        "Regenerate rule catalog",
        capture_output=True,
        allow_failure=True,
    )
    if r.returncode != 0:
        print_warning(
            "Could not regenerate rules_catalog.json — shipping the committed "
            "catalog. Run `dart run saropa_lints:generate_rule_catalog` manually."
        )
        if r.stderr:
            print_warning(r.stderr.strip())
        return False
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


def _prompt_for_vsce_pat() -> str:
    """Prompt user for VSCE_PAT when not set. Returns token or empty string to skip.

    Mirrors _prompt_for_ovsx_pat. Without this, a missing/expired Marketplace
    token made `vsce publish` fail with an opaque error (under capture_output it
    cannot fall back to vsce's own interactive prompt), and the caller could only
    print a generic "PAT expired or missing scope?" guess.
    """
    print_warning("VSCE_PAT environment variable not set.")
    print_info("The VS Code Marketplace requires a Personal Access Token (PAT) to publish.")
    print_info("Create one in Azure DevOps (the Marketplace uses Azure DevOps for auth):")
    print_info("  1. Sign in at https://dev.azure.com with the account that owns the Saropa publisher.")
    print_info("  2. User settings (top-right avatar) -> Personal Access Tokens -> New Token.")
    print_info("  3. Organization: All accessible organizations. Scopes: Marketplace -> Manage.")
    print_info("  4. Create, then copy the token (it is shown only once).")
    print_info(f"  Publisher page: {MARKETPLACE_MANAGE_URL}")
    print()
    # Show platform-specific instructions for setting it permanently
    is_windows = platform.system() == "Windows"
    if is_windows:
        print_colored(
            "  To set permanently (PowerShell):",
            Color.DIM,
        )
        print_colored(
            '    [Environment]::SetEnvironmentVariable("VSCE_PAT", "your-token", "User")',
            Color.WHITE,
        )
        print_colored(
            "  Or for current session only:",
            Color.DIM,
        )
        print_colored(
            '    $env:VSCE_PAT = "your-token"',
            Color.WHITE,
        )
    else:
        print_colored(
            "  To set permanently, add to ~/.bashrc or ~/.zshrc:",
            Color.DIM,
        )
        print_colored(
            '    export VSCE_PAT="your-token"',
            Color.WHITE,
        )
    print()
    token = input("  Paste your Marketplace PAT now (or press Enter to skip): ").strip()
    if token:
        # Set for this process so vsce (which reads VSCE_PAT) picks it up.
        os.environ["VSCE_PAT"] = token
    return token


def _read_extension_publisher(project_dir: Path) -> str:
    """Return the `publisher` id from extension/package.json (e.g. "saropa").

    vsce authenticates per-publisher; the stored-credential check below needs
    the exact publisher id, which is distinct from the package `name`.
    """
    pkg = _extension_dir(project_dir) / "package.json"
    try:
        data = json.loads(pkg.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return ""
    publisher = data.get("publisher", "")
    return publisher if isinstance(publisher, str) else ""


def _has_stored_vsce_credential(publisher: str) -> bool:
    """Return True if vsce already holds a valid login for *publisher*.

    vsce authenticates from EITHER the VSCE_PAT env var OR a stored
    `vsce login` credential (a PAT or a Microsoft Entra browser login — vsce 3.x
    needs no PAT). `verify-pat` is read-only — it checks the stored
    credential without publishing — so we can tell whether a publish will
    succeed before attempting it. Without this fallback the script skipped
    every Marketplace publish on a machine that authenticates via `vsce login`
    (the sibling saropa_workspace publish script, which calls `vsce publish`
    directly, succeeds that way), silently leaving the Marketplace a version
    behind while Open VSX advanced.
    """
    if not publisher:
        return False
    # verify-pat queries the gallery; it does not package, so cwd is irrelevant.
    r = run_command(
        ["npx", "@vscode/vsce", "verify-pat", publisher],
        Path.cwd(),
        "Check stored VS Code Marketplace credential",
        capture_output=True,
        allow_failure=True,
    )
    return r.returncode == 0


def publish_extension_to_marketplace(
    project_dir: Path, vsix_path: Path
) -> bool:
    """Publish .vsix to VS Code Marketplace via vsce. Returns True on success or skip."""
    # vsce authenticates from the VSCE_PAT env var OR a stored `vsce login`
    # credential. Prefer the env var, but when it is absent fall through to a
    # stored credential rather than skipping — skipping on an empty env var
    # (while vsce was logged in) is exactly what left the Marketplace behind.
    vsce_pat = os.environ.get("VSCE_PAT", "").strip()
    if not vsce_pat:
        publisher = _read_extension_publisher(project_dir)
        if _has_stored_vsce_credential(publisher):
            print_info(
                f"VSCE_PAT not set; using the stored vsce login for '{publisher}'."
            )
        else:
            vsce_pat = _prompt_for_vsce_pat()
            if not vsce_pat:
                print_info("Skipping VS Code Marketplace publish.")
                return True
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
    """Sync version, copy root changelog + readme, compile, and package .vsix. Returns path to .vsix or None."""
    if not set_extension_version(project_dir, version):
        print_warning("Could not set extension version in package.json")
    if not copy_changelog_to_extension(project_dir):
        print_warning("Root CHANGELOG.md not found; extension .vsix will have no changelog.")
    if not copy_readme_to_extension(project_dir):
        print_warning("Root README.md not found; extension .vsix will have no README.")
    # Coverage gate: publish AUDITS locale coverage but never translates — a
    # translation run is an explicit, separate operation. The audit runs with
    # --fail-on-missing, so a non-zero exit means at least one locale still has
    # untranslated strings (or the i18n scripts errored). On failure, prompt
    # Retry / Ignore / Abort instead of hard-aborting — Retry re-audits after the
    # user closes gaps (dictionaries.py edit or a separate translation run),
    # Ignore ships despite gaps when intentional, Abort stops the publish.
    while True:
        audit = audit_extension_locales(project_dir)
        if audit is True:
            print_success("Extension locale audit clean — no missing translations.")
            break
        if audit is None:
            # No i18n scripts present; nothing to gate.
            break
        choice = _prompt_locale_coverage_failure()
        if choice == "retry":
            print_info("Re-running extension locale audit...")
            continue
        if choice == "ignore":
            print_warning(
                "Continuing with missing extension translations — bundle will ship "
                "with some English passthroughs."
            )
            break
        print_error("Publish aborted at extension locale coverage gate.")
        return None
    # Keep the bundled rule-metadata catalog current with the rule definitions
    # before compiling it into the .vsix (non-fatal — ships the committed catalog
    # on failure).
    regenerate_rule_catalog(project_dir)
    if not run_extension_compile(project_dir):
        return None
    vsix = run_extension_package(project_dir, version)
    if vsix:
        print_success(f"Packaged: {vsix.name}")
    return vsix


def publish_extension(project_dir: Path, vsix_path: Path) -> bool:
    """Publish to the VS Code Marketplace, then to Open VSX.

    Open VSX is always attempted after the Marketplace step. A failed
    Marketplace upload (expired vsce token, etc.) no longer blocks
    `npx ovsx publish`, so the registry at open-vsx.org can still receive
    the .vsix when OVSX_PAT is valid.

    Returns True when Marketplace succeeded and Open VSX either published
    or was skipped (user declined a PAT). Returns False if either required
    publish step failed.
    """
    marketplace_ok = publish_extension_to_marketplace(project_dir, vsix_path)
    if marketplace_ok:
        print_info(f"  Manage: {MARKETPLACE_MANAGE_URL}")
    else:
        print_warning(
            "VS Code Marketplace publish failed — still attempting Open VSX."
        )
    ovsx_ok = publish_extension_to_ovsx(project_dir, vsix_path)
    return marketplace_ok and ovsx_ok


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
    vsix_path: Path | None = None,
    interval_seconds: int = 30,
    timeout_seconds: int = 600,
) -> StorePublicationResult:
    """Poll Marketplace and Open VSX until both report expected version or timeout.

    Polls every *interval_seconds* for up to *timeout_seconds*. Returns a
    StorePublicationResult with per-store booleans so the caller can warn
    specifically about a Marketplace failure (the common case: a silent
    vsce publish that returned 0 but never actually propagated the new
    version because the PAT was expired or lacked scope).

    On failure, prints the MARKETPLACE_MANAGE_URL and manual-upload guidance
    so the user can open the page and drop the .vsix in themselves.
    """
    print_header("FINAL STEP: STORE PUBLICATION VERIFICATION")
    print_info(
        "Checking Marketplace and Open VSX every "
        f"{interval_seconds}s for up to {timeout_seconds // 60} minutes..."
    )
    item_name = f"{publisher}.{extension_name}"
    attempts = (timeout_seconds // interval_seconds) + 1

    # Track the most recent values we observed so the final summary can
    # report which version each store reported (or "unavailable" if the
    # API call failed entirely). Also track per-store success so we can
    # stop re-checking a store once it has propagated.
    last_marketplace = "unknown"
    last_openvsx = "unknown"
    marketplace_ok = False
    open_vsx_ok = False

    for attempt in range(1, attempts + 1):
        # Only re-query a store that hasn't yet reported the expected
        # version. Once it's confirmed we leave its last-seen value alone.
        if not marketplace_ok:
            marketplace_version = _fetch_marketplace_latest_version(item_name)
            last_marketplace = marketplace_version or "unavailable"
            marketplace_ok = marketplace_version == expected_version
        if not open_vsx_ok:
            open_vsx_version = _fetch_open_vsx_latest_version(
                publisher, extension_name,
            )
            last_openvsx = open_vsx_version or "unavailable"
            open_vsx_ok = open_vsx_version == expected_version

        if marketplace_ok and open_vsx_ok:
            print_success(
                f"Store propagation complete: Marketplace={last_marketplace}, "
                f"Open VSX={last_openvsx}"
            )
            return StorePublicationResult(
                marketplace_ok=True, open_vsx_ok=True,
            )

        print_info(
            f"Attempt {attempt}/{attempts}: Marketplace={last_marketplace}, "
            f"Open VSX={last_openvsx}"
        )
        if attempt < attempts:
            time.sleep(interval_seconds)

    # Timed out — emit per-store warnings so the user knows exactly which
    # store needs manual intervention. Marketplace failure is the loud one
    # because we've seen vsce return success while the Marketplace silently
    # drops the upload (expired PAT, missing "Marketplace > Manage" scope).
    if not marketplace_ok:
        print_warning(
            f"VS Code Marketplace still shows {last_marketplace} "
            f"(expected {expected_version}). The publish did not propagate."
        )
        print_info(
            f"  Open {MARKETPLACE_MANAGE_URL} and upload the .vsix manually."
        )
        if vsix_path and vsix_path.is_file():
            print_info(f"  File to upload: {vsix_path}")
    else:
        print_success(f"Marketplace OK: {last_marketplace}")

    if not open_vsx_ok:
        print_warning(
            f"Open VSX still shows {last_openvsx} "
            f"(expected {expected_version})."
        )
        print_info(
            f"  Manage: https://open-vsx.org/user-settings/extensions"
        )
    else:
        print_success(f"Open VSX OK: {last_openvsx}")

    return StorePublicationResult(
        marketplace_ok=marketplace_ok, open_vsx_ok=open_vsx_ok,
    )
