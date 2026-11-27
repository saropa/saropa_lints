"""
The publish pipeline's two parallel groups.

Only read-only checks run together. Everything that rewrites sources (auto
fixes, format, version sync, badges, dependency resolution) happens before a
group starts, and nothing irreversible starts until the whole group passed.

Group 1 (before the version prompt): dart analyze | delta tests.
Group 2 (after the version bump):    dart analyze | dart doc |
                                     dry run -> rule catalog -> compile -> vsix

The dry run and the extension build share one lane because packaging writes
files under the project root and extension/, which the dry run enumerates.

Set SAROPA_SERIAL_STEPS=1 to run the same lanes one at a time.

Version:   1.0
Author:    Saropa
Copyright: (c) 2026 Saropa
"""

from __future__ import annotations

import os
import shutil
from datetime import datetime
from pathlib import Path

from scripts.modules._extension_publish import (
    extension_exists,
    extension_vsix_path,
    prepare_extension_package,
    vsce_package_cmd,
)
from scripts.modules._parallel import Cmd, Lane, run_group
from scripts.modules._publish_steps import (
    _auto_tune_concurrency,
    _available_ram_gb,
    _dart_test_env,
    _extract_dart_doc_summary,
    _find_delta_test_files,
    _is_mid_publish_stale_plugin,
    _log_transient_failure_reason,
    _print_dart_doc_summary,
    _try_fix_stale_plugin_cache,
    run_analysis,
    run_pub_get,
    run_tests,
)
from scripts.modules._pubdev_lint import (
    check_pubdev_lint_issues,
    fix_doc_angle_brackets,
    fix_doc_references,
)
from scripts.modules._utils import (
    LONG_TIMEOUT_S,
    clear_flutter_lock,
    is_windows,
    print_header,
    print_info,
    print_warning,
)

# Below this much free memory, concurrent dart processes are run one at a time.
_MIN_PARALLEL_RAM_GB = 4.0


def _max_parallel() -> int | None:
    """None = all lanes at once; 1 when asked for, or memory is short."""
    if os.environ.get("SAROPA_SERIAL_STEPS", "").strip() == "1":
        return 1
    free = _available_ram_gb()
    if free is not None and free < _MIN_PARALLEL_RAM_GB:
        print_warning(f"Only {free:.1f} GB RAM free; running steps one at a time.")
        return 1
    return None


def _log_dir(project_dir: Path) -> Path:
    """Same dated reports folder the other publish logs use."""
    return project_dir / "reports" / datetime.now().strftime("%Y%m%d")


def _analyze_lane(project_dir: Path) -> Lane:
    """dart analyze, keeping the mid-publish and stale-plugin-cache handling."""

    def accept(code: int, output: str) -> bool:
        # An unpublished plugin pin on a release commit is expected, not a lint.
        return code == 0 or _is_mid_publish_stale_plugin(project_dir, output)

    cmd = Cmd(["dart", "analyze", "--fatal-infos"], project_dir, accept=accept)
    return Lane(
        "analyze", [cmd],
        on_failure=lambda out: _try_fix_stale_plugin_cache(project_dir, out),
    )


def _delta_test_lane(project_dir: Path, files: list[str]) -> Lane:
    """The same delta test command run_tests uses, prepared up front."""
    clear_flutter_lock()
    # Stale kernels would hide tag changes (see run_tests).
    shutil.rmtree(project_dir / ".dart_tool" / "test", ignore_errors=True)
    env = _dart_test_env(project_dir)
    # The probe runs dart test itself, so it must finish before the group.
    jobs = _auto_tune_concurrency(project_dir, env) or min(os.cpu_count() or 8, 8)
    cmd = Cmd(
        ["dart", "test", "-j", str(jobs), "-x", "slow", *files],
        project_dir, env=env, timeout=LONG_TIMEOUT_S,
    )
    lane = Lane("tests", [cmd])

    def transient(_output: str) -> bool:
        # VM crashes and Windows file locks are re-run once, as before.
        reason = _log_transient_failure_reason(lane.log_path)
        if reason:
            print_warning(f"Transient test failure, retrying: {reason}")
        return bool(reason)

    lane.on_failure = transient
    return lane


def run_analysis_and_tests(project_dir: Path) -> bool:
    """Steps 6 and 7: analysis and delta tests together.

    The full suite (--full-tests) stays sequential: it generates aggregate test
    files inside test/, which would change under a running analyzer.
    """
    if os.environ.get("SAROPA_FULL_TESTS", "").strip() == "1":
        return run_analysis(project_dir) and run_tests(project_dir)

    print_header("STEPS 6-7: ANALYSIS AND TESTS (PARALLEL)")
    # Doc auto-fix rewrites sources, so it runs before anything reads them.
    if check_pubdev_lint_issues(project_dir):
        fix_doc_angle_brackets(project_dir)
        fix_doc_references(project_dir)

    lanes = [_analyze_lane(project_dir)]
    files = _find_delta_test_files(project_dir)
    if files:
        print_info(f"Delta: {len(files)} test file(s) affected by changes")
        lanes.append(_delta_test_lane(project_dir, files))
    else:
        print_info("No uncommitted changes to test.")
    return run_group(
        "Analysis and tests", lanes, _log_dir(project_dir), _max_parallel(),
    )


def _doc_accept(code: int, output: str) -> bool:
    """Surface dart doc's warning count; the exit code decides success."""
    summary, warnings, _errors = _extract_dart_doc_summary(output)
    _print_dart_doc_summary(summary, warnings)
    return code == 0


def _dry_run_accept(code: int, output: str) -> bool:
    """Mirror pre_publish_validation: 65 is warnings only."""
    lowered = output.lower()
    if code not in (0, 65):
        # Windows reports a harmless invalid "nul" path as a failure.
        return is_windows() and "nul" in lowered and "path is invalid" in lowered
    for line in output.splitlines():
        # Show pub.dev's own pre-release caveat before the irreversible steps.
        if "pre-release" in line.lower() or "prerelease" in line.lower():
            print_warning(f"dart pub publish: {line.strip()}")
    return True


def _release_lane(project_dir: Path, version: str, package: bool) -> Lane:
    """Dry run, then (optionally) build the .vsix, strictly in that order."""
    cmds = [Cmd(["dart", "pub", "publish", "--dry-run"], project_dir,
                accept=_dry_run_accept)]
    if package:
        extension = project_dir / "extension"
        cmds += [
            # A stale catalog still ships, as in the sequential path.
            Cmd(["dart", "run", "saropa_lints:generate_rule_catalog"],
                project_dir, allow_failure=True),
            Cmd(["npm", "run", "compile"], extension),
            Cmd(vsce_package_cmd(project_dir, version), extension),
        ]
    return Lane("dry-run-and-vsix" if package else "dry-run", cmds)


def run_release_checks(
    project_dir: Path, version: str, with_extension: bool,
) -> bool:
    """Docs, dry run, final analysis gate and .vsix build, in parallel.

    Returns False if anything failed and was not retried to success; the
    caller must not commit, tag or publish in that case.
    """
    print_header("STEPS 10-11: DOCS, DRY RUN, CI GATE, PACKAGE (PARALLEL)")
    # The version bump changed pubspec.yaml. Resolve once here so the parallel
    # dart processes do not all rewrite .dart_tool at the same moment.
    if not run_pub_get(project_dir):
        return False
    package = with_extension and extension_exists(project_dir)
    # Locale audit (never translates) can prompt and writes into extension/.
    if package and not prepare_extension_package(project_dir, version):
        return False

    lanes = [
        _analyze_lane(project_dir),
        Lane("docs", [Cmd(["dart", "doc"], project_dir, accept=_doc_accept)]),
        _release_lane(project_dir, version, package),
    ]
    if not run_group(
        "Release checks", lanes, _log_dir(project_dir), _max_parallel(),
    ):
        return False
    if package and not extension_vsix_path(project_dir, version).is_file():
        print_warning("vsce reported success but the .vsix is missing.")
        return False
    return True
