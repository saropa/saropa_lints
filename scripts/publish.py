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
      python scripts/publish.py --dry-run
      python scripts/publish.py --mode audit_only --log-file publish.log
      python scripts/publish.py --mode dry_run --log-file /tmp/ci.log

Flags:
    --dry-run             Shorthand for --mode dry_run
    --mode <name>         Run a specific mode non-interactively:
                            full, audit[_only], fix_docs, skip_audit,
                            analyze[_only], extension[_only],
                            publish_existing_vsix, ci_fallback,
                            pubdev_only, dry_run
    --log-file <path>     Mirror all output (ANSI-stripped) to a plain-text file
    --log-append          Append to log file instead of overwriting
    --auto-retry <n>      Auto-retry failed steps up to n times before aborting
                            (also prompted interactively at startup)
    --output-level <lvl>  Console verbosity: silent, warnings, normal, verbose

When --mode or --log-file is given (or stdin is not a TTY), the script
runs non-interactively: prompts auto-answer with safe defaults and
step failures auto-abort instead of waiting for user input.

Modes: full publish / audit only / fix docs / skip audit / analyze only / extension only / dry run / pub.dev only
1
See scripts/README.md for the full architecture and module map.

Extension localization: US English is the canonical maintainable source
(``extension/package.nls.json``, ``extension/src/i18n/locales/en.json``).
Publish only AUDITS locale coverage (``generate_locales.py --mode audit``);
it never machine-translates. Closing gaps is an explicit, separate step —
edit ``dictionaries.py`` or run the translator yourself with
``python extension/scripts/i18n/generate_locales.py`` (from repo root,
after editing English). The US spelling audit skips
``extension/scripts/i18n/`` so foreign-language strings in translation
tables do not false-positive as British English.

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
    "modules/_code_comment_metrics.py",
    "modules/_comment_coverage_report.py",
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
    close_log_file,
    enable_ansi_support,
    get_auto_retry_limit,
    get_project_dir,
    print_header,
    print_info,
    safe_input,
    set_auto_retry_limit,
    set_log_file,
    set_non_interactive,
    set_output_level,
    show_saropa_logo,
)
from scripts.modules._timing import StepTimer
from scripts.modules._publish_workflow import (
    build_publish_context,
    check_orphaned_version_bump,
    print_package_banner,
    run_analyze_only,
    run_ci_fallback_mode,
    run_dry_run_mode,
    run_extension_only_mode,
    run_fix_docs_mode,
    run_full_publish,
    run_pubdev_only_mode,
    run_publish_existing_vsix_mode,
    validate_pubspec_changelog,
)

# Single source of truth for publish modes.
# Each entry: (internal_key, menu_label, cli_aliases)
# Menu number is derived from list position (1-indexed).
_MODE_TABLE: list[tuple[str, str, list[str]]] = [
    ("full",
     "Full publish (audit \u2192 format \u2192 analysis \u2192 tests \u2192 version \u2192 release)",
     []),
    ("audit_only",
     "Audit only (tier integrity, DX checks; no publish)",
     ["audit"]),
    ("fix_docs",
     "Fix doc comments (angle brackets, refs; then exit)",
     []),
    ("full_skip_audit",
     "Publish without audit (skip audit; format \u2192 analysis \u2192 tests \u2192 release)",
     ["skip_audit"]),
    ("analyze_only",
     "Analyze only (run dart analyze, write log; then exit)",
     ["analyze"]),
    ("extension_only",
     "Extension only (package .vsix, optionally publish to Marketplace/Open VSX)",
     ["extension"]),
    ("publish_existing_vsix",
     "Publish existing .vsix (skip packaging; newest in project root)",
     []),
    ("ci_fallback",
     "CI fallback playbook (manual publish URLs, commands, upload files)",
     []),
    ("pubdev_only",
     "Pub.dev only (full publish pipeline, skip extension entirely)",
     []),
    ("dry_run",
     "Dry run (audit + format + analyze + tests; no commit/tag/publish)",
     []),
]

# Build the CLI alias lookup from the single mode table
_VALID_MODES: dict[str, str] = {}
for _key, _, _aliases in _MODE_TABLE:
    _VALID_MODES[_key] = _key
    for _alias in _aliases:
        _VALID_MODES[_alias] = _key


def _prompt_publish_mode() -> str:
    """Ask user for run mode via interactive menu.

    Menu items are generated from _MODE_TABLE so adding a mode
    in one place updates both the CLI --mode flag and this menu.
    """
    print_header("PUBLISH OPTIONS")
    for i, (_, label, _) in enumerate(_MODE_TABLE, 1):
        print(f"  {i}) {label}")
    try:
        raw = safe_input("  Choice [1]: ", "1").strip() or "1"
        n = int(raw)
        if 1 <= n <= len(_MODE_TABLE):
            return _MODE_TABLE[n - 1][0]
    except (ValueError, EOFError, KeyboardInterrupt):
        pass
    return "full"


def main(
    mode: str | None = None,
    output_level: OutputLevel | None = None,
) -> int:
    """Run publish workflow. Returns exit code (0 = success).

    Args:
        mode: 'full' | 'audit_only' | 'fix_docs' | 'full_skip_audit' | 'analyze_only' | 'dry_run' | 'extension_only' | 'publish_existing_vsix' | 'ci_fallback' | 'pubdev_only'.
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

    # Auto-retry: only prompt for modes that run pipeline steps with
    # failure paths. Quick modes (audit, fix_docs, analyze) exit early
    # and never hit prompt_step_failure, so asking is noise.
    _RETRY_WORTHY_MODES = {
        "full", "full_skip_audit", "dry_run",
        "extension_only", "pubdev_only", "publish_existing_vsix",
    }
    if mode in _RETRY_WORTHY_MODES and get_auto_retry_limit() == 0:
        raw_retry = safe_input(
            "  Auto-retry failed steps? Enter count [0]: ", "0"
        ).strip()
        try:
            retry_n = int(raw_retry)
            if retry_n > 0:
                set_auto_retry_limit(retry_n)
                print_info(f"Auto-retry set to {retry_n}")
        except ValueError:
            pass

    project_dir = get_project_dir()
    pubspec_path = project_dir / "pubspec.yaml"
    changelog_path = project_dir / "CHANGELOG.md"
    validate_pubspec_changelog(pubspec_path, changelog_path)

    # Detect orphaned version bumps from aborted publishes — pubspec is
    # ahead of the last git tag with no matching tag on remote. Offers to
    # reset versions so the next publish starts clean instead of fighting
    # stale state through the entire pipeline.
    check_orphaned_version_bump(project_dir, pubspec_path, changelog_path)

    # Created here (not after the early-exit loop) so dry_run mode — an
    # early-exit mode — can still report step timings for the checks it runs.
    timer = StepTimer()

    # Early exits for alternative modes
    for handler in (
        lambda: run_analyze_only(mode, project_dir),
        lambda: run_dry_run_mode(mode, project_dir, timer),
        lambda: run_ci_fallback_mode(mode, project_dir, pubspec_path),
        lambda: run_extension_only_mode(mode, project_dir, pubspec_path),
        lambda: run_publish_existing_vsix_mode(mode, project_dir),
        lambda: run_fix_docs_mode(mode, project_dir),
        lambda: run_pubdev_only_mode(mode, project_dir, pubspec_path, changelog_path, timer),
    ):
        code = handler()
        if code is not None:
            return code

    # Build context and run full pipeline
    ctx = build_publish_context(project_dir, pubspec_path, changelog_path)
    print_package_banner(ctx, SCRIPT_VERSION)
    return run_full_publish(ctx, mode, timer)


# Valid --output-level names (maps to OutputLevel enum)
_OUTPUT_LEVELS = {
    "silent": OutputLevel.SILENT,
    "warnings": OutputLevel.WARNINGS_ONLY,
    "warnings_only": OutputLevel.WARNINGS_ONLY,
    "normal": OutputLevel.NORMAL,
    "verbose": OutputLevel.VERBOSE,
}


class _ParsedArgs:
    """Parsed CLI arguments for the publish script."""

    __slots__ = ("mode", "log_path", "log_append", "auto_retry", "output_level")

    def __init__(self) -> None:
        self.mode: str | None = None
        self.log_path: Path | None = None
        self.log_append: bool = False
        self.auto_retry: int = 0
        self.output_level: OutputLevel | None = None


def _parse_args(argv: list[str]) -> _ParsedArgs:
    """Parse CLI arguments into a structured result.

    Supports:
        --dry-run               Shorthand for --mode dry_run
        --mode <name>           Set publish mode (see _VALID_MODES)
        --log-file <path>       Tee all output (ANSI-stripped) to a file
        --log-append            Append to log file instead of overwriting
        --auto-retry <n>        Auto-retry failed steps up to n times
        --output-level <level>  Set console verbosity:
                                  silent, warnings, normal, verbose

    When --mode or --log-file is given, the script also enables
    non-interactive mode (prompts auto-answer with defaults).
    """
    result = _ParsedArgs()
    i = 0
    while i < len(argv):
        arg = argv[i]
        if arg == "--dry-run":
            result.mode = "dry_run"
        elif arg == "--log-append":
            result.log_append = True
        elif arg == "--mode":
            if i + 1 >= len(argv):
                print("  ERROR: --mode requires a value")
                print(f"  Valid modes: {', '.join(sorted(_VALID_MODES))}")
                sys.exit(1)
            i += 1
            raw = argv[i].lower().replace("-", "_")
            if raw not in _VALID_MODES:
                print(f"  ERROR: Unknown mode '{argv[i]}'")
                print(f"  Valid modes: {', '.join(sorted(_VALID_MODES))}")
                sys.exit(1)
            result.mode = _VALID_MODES[raw]
        elif arg == "--log-file":
            if i + 1 >= len(argv):
                print("  ERROR: --log-file requires a file path")
                sys.exit(1)
            i += 1
            result.log_path = Path(argv[i])
        elif arg == "--auto-retry":
            if i + 1 >= len(argv):
                print("  ERROR: --auto-retry requires a number")
                sys.exit(1)
            i += 1
            try:
                result.auto_retry = int(argv[i])
            except ValueError:
                print(f"  ERROR: --auto-retry value must be a number, got '{argv[i]}'")
                sys.exit(1)
        elif arg == "--output-level":
            if i + 1 >= len(argv):
                print("  ERROR: --output-level requires a value")
                print(f"  Valid levels: {', '.join(sorted(_OUTPUT_LEVELS))}")
                sys.exit(1)
            i += 1
            raw_level = argv[i].lower().replace("-", "_")
            if raw_level not in _OUTPUT_LEVELS:
                print(f"  ERROR: Unknown output level '{argv[i]}'")
                print(f"  Valid levels: {', '.join(sorted(_OUTPUT_LEVELS))}")
                sys.exit(1)
            result.output_level = _OUTPUT_LEVELS[raw_level]
        i += 1
    return result


if __name__ == "__main__":
    args = _parse_args(sys.argv[1:])

    # Enable non-interactive mode when a log file or explicit mode is given,
    # or when stdin is not a terminal (piped / remote execution)
    if args.log_path or args.mode or not sys.stdin.isatty():
        set_non_interactive(True)
        print_info("Running in non-interactive mode (prompts auto-answered)")

    # Set auto-retry before any pipeline steps run
    if args.auto_retry > 0:
        set_auto_retry_limit(args.auto_retry)
        print_info(f"Auto-retry limit: {args.auto_retry}")

    # Open the log file before any output so the logo is captured
    if args.log_path:
        set_log_file(args.log_path, append=args.log_append)
        print_info(f"Logging to {args.log_path.resolve()}")

    try:
        sys.exit(main(mode=args.mode, output_level=args.output_level))
    finally:
        # Ensure the log file is flushed and closed on any exit path
        close_log_file()
