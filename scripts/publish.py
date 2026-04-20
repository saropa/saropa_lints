#!/usr/bin/env python3
"""
Publish saropa_lints package to pub.dev and create GitHub release.

Single entry point for the complete release workflow (package to pub.dev
and VS Code extension). Delegates all logic to scripts/modules/:

    _publish_workflow.py  — pipeline orchestration (audit → release → extension)
    _version_changelog.py — version prompting, sync, and changelog management
    _extension_publish.py — extension packaging, publishing, store verification
    _publish_steps.py     — low-level step implementations (format, test, analyze)
    _git_ops.py           — git commit, tag, push, GitHub release
    _timing.py            — step timing and summary reporting

Run:  python scripts/publish.py
Modes: full publish / audit only / fix docs / skip audit / analyze only / extension only

See scripts/README.md for the full architecture and module map.

Version:   5.0
Author:    Saropa
Copyright: (c) 2025-2026 Saropa

Exit Codes:
    0  - Success
    1  - Prerequisites failed
    2  - Working tree check failed
    3  - Tests failed
    4  - Analysis failed
    5  - Changelog validation failed
    6  - Pre-publish validation failed
    7  - Publish failed
    8  - Git operations failed
    9  - GitHub release failed
    10 - User canceled
    11 - Audit failed (tier integrity or duplicates)
"""

from __future__ import annotations

import sys
from pathlib import Path

# Allow running as `python scripts/publish.py` from project root (add parent to path)
_scripts_parent = str(Path(__file__).resolve().parent.parent)
if _scripts_parent not in sys.path:
    sys.path.insert(0, _scripts_parent)


SCRIPT_VERSION = "5.0"

# Modules under scripts/modules/ that must exist before any of them are imported
_REQUIRED_MODULES = [
    "modules/__init__.py",
    "modules/_utils.py",
    "modules/_audit_checks.py",
    "modules/_audit_dx.py",
    "modules/_audit.py",
    "modules/_tier_integrity.py",
    "modules/_git_ops.py",
    "modules/_pubdev_lint.py",
    "modules/_publish_steps.py",
    "modules/_publish_workflow.py",
    "modules/_rule_metrics.py",
    "modules/_version_changelog.py",
    "modules/_us_spelling.py",
    "modules/_timing.py",
    "modules/_roadmap_implemented.py",
    "modules/_duplicated_messages.py",
    "modules/_extension_publish.py",
]


def check_modules_exist() -> bool:
    """Verify all required module files exist before importing.

    Runs BEFORE any module imports so the user gets a clear
    error message instead of a Python ImportError traceback.
    Uses ASCII-only output since enable_ansi_support() hasn't run yet.

    Returns:
        True if all modules found, False otherwise.
    """
    # Reconfigure stdout to UTF-8 early (Windows cp1252 can't print Unicode)
    try:
        sys.stdout.reconfigure(encoding="utf-8")  # type: ignore[attr-defined]
    except (AttributeError, OSError):
        pass  # Not available or not writable — fall back to system encoding

    scripts_dir = Path(__file__).resolve().parent
    missing: list[str] = []

    for module_rel in _REQUIRED_MODULES:
        module_path = scripts_dir / module_rel
        if not module_path.exists():
            missing.append(module_rel)

    if missing:
        for m in missing:
            print(f"  [MISSING] Module MISSING: {m}")
        print()
        print("  ERROR: Required modules are missing from scripts/modules/.")
        print("  Ensure the following files exist:")
        for m in missing:
            print(f"    scripts/{m}")
        return False

    return True


# Early gate: check modules before importing anything from them
if not check_modules_exist():
    sys.exit(1)

# All modules verified — safe to import
from scripts.modules._utils import (
    OutputLevel,
    enable_ansi_support,
    get_project_dir,
    print_header,
    set_output_level,
    show_saropa_logo,
)
from scripts.modules._timing import StepTimer
from scripts.modules._publish_workflow import (
    build_publish_context,
    print_package_banner,
    run_analyze_only,
    run_extension_only_mode,
    run_fix_docs_mode,
    run_full_publish,
    validate_pubspec_changelog,
)


def _prompt_publish_mode() -> str:
    """Ask user for run mode via interactive menu (1-6)."""
    print_header("PUBLISH OPTIONS")
    print(
        "  1) Full publish (audit \u2192 format \u2192 analysis \u2192 tests \u2192 version \u2192 release)"
    )
    print("  2) Audit only (tier integrity, DX checks; no publish)")
    print("  3) Fix doc comments (angle brackets, refs; then exit)")
    print("  4) Publish without audit (skip audit; format \u2192 analysis \u2192 tests \u2192 release)")
    print("  5) Analyze only (run dart analyze, write log; then exit)")
    print("  6) Extension only (package .vsix, optionally publish to Marketplace/Open VSX)")
    try:
        raw = input("  Choice [1]: ").strip() or "1"
        n = int(raw)
        if n == 2:
            return "audit_only"
        if n == 3:
            return "fix_docs"
        if n == 4:
            return "full_skip_audit"
        if n == 5:
            return "analyze_only"
        if n == 6:
            return "extension_only"
    except (ValueError, EOFError, KeyboardInterrupt):
        pass
    return "full"


def main(
    mode: str | None = None,
    output_level: OutputLevel | None = None,
) -> int:
    """Run publish workflow. Returns exit code (0 = success).

    Args:
        mode: 'full' | 'audit_only' | 'fix_docs' | 'full_skip_audit' | 'analyze_only' | 'extension_only'.
              If None, prompts the user interactively (after displaying the logo so
              the Saropa brand always appears first — see "logo ALWAYS first" rule).
        output_level: Verbosity level (defaults to VERBOSE).
    """
    # Terminal setup + logo MUST happen before any prompt so the Saropa logo
    # is the first thing the user sees when running the script.
    enable_ansi_support()
    set_output_level(output_level or OutputLevel.VERBOSE)
    show_saropa_logo()

    # Prompt for mode AFTER the logo is displayed (previously prompted before logo).
    if mode is None:
        mode = _prompt_publish_mode()

    project_dir = get_project_dir()
    pubspec_path = project_dir / "pubspec.yaml"
    changelog_path = project_dir / "CHANGELOG.md"
    validate_pubspec_changelog(pubspec_path, changelog_path)

    # Early exits for alternative modes
    for handler in (
        lambda: run_analyze_only(mode, project_dir),
        lambda: run_extension_only_mode(mode, project_dir, pubspec_path),
        lambda: run_fix_docs_mode(mode, project_dir),
    ):
        code = handler()
        if code is not None:
            return code

    # Build context and run full pipeline
    ctx = build_publish_context(project_dir, pubspec_path, changelog_path)
    print_package_banner(ctx, SCRIPT_VERSION)
    timer = StepTimer()
    return run_full_publish(ctx, mode, timer)


if __name__ == "__main__":
    # main() now displays the logo before prompting for mode, so call it directly.
    sys.exit(main())
