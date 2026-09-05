#!/usr/bin/env python3
"""Verify fixtures for FileType.test-gated rules live at isTestPath-matching paths.

Rules with ``applicableFileTypes => {FileType.test}`` only fire on paths that
``ProjectFile.isTestPath()`` recognizes: files ending in ``_test.dart``, or
paths containing ``/test/``, ``/test_driver/``, or ``/integration_test/``.
A fixture at a non-matching path (e.g. ``example/lib/testing_best_practices/``)
is silently never exercised by the native custom_lint plugin, giving a false
sense of coverage.

Run from repository root::

    python scripts/check_fixture_filetype_match.py          # audit only
    python scripts/check_fixture_filetype_match.py --fix    # relocate via git mv

Also called by the publish pipeline (``run_pre_publish_audits``) via
``collect_mismatched_fixtures()`` — a misplaced fixture blocks publish.

Exit codes:
    0 - all FileType.test fixtures are at matching paths (or have no fixture)
    1 - one or more fixtures are at non-matching paths (or --fix partially failed)
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# Regex to find rule classes that declare applicableFileTypes => {FileType.test}.
# Matches the pattern across the class body to find the LintCode name.
_APPLICABLE_TEST = re.compile(
    r"applicableFileTypes\s*=>\s*\{FileType\.test\}"
)

# Regex to extract the LintCode name string from a rule class.
# Looks for: LintCode('rule_name', ... ) or LintCode(\n  'rule_name', ...)
_LINT_CODE_NAME = re.compile(
    r"LintCode\(\s*['\"]([a-z][a-z0-9_]*)['\"]"
)

# Mirrors ProjectFile.isTestPath() from project_context_project_file.dart.
_TEST_PATH_SEGMENTS = ("/test/", "/test_driver/", "/integration_test/")


def _is_test_path(path_str: str) -> bool:
    """Check if a path would be recognized by isTestPath (forward-slash normalized)."""
    normalized = path_str.replace("\\", "/")
    if normalized.endswith("_test.dart"):
        return True
    return any(seg in normalized for seg in _TEST_PATH_SEGMENTS)


def _extract_test_rules(dart_file: Path) -> list[str]:
    """Extract rule names from classes with applicableFileTypes => {FileType.test}.

    Uses brace-depth tracking to isolate top-level class bodies instead of
    regex splitting, so 'class' inside strings, comments, or nested scopes
    does not cause misparsing.
    """
    text = dart_file.read_text(encoding="utf-8", errors="replace")
    rules: list[str] = []

    # Phase 1: find each top-level class body by tracking brace depth.
    # Each entry is (start_offset, end_offset) of the class body braces.
    class_bodies: list[str] = []
    # Match top-level "class Foo ... {" declarations (not inside braces).
    for m in re.finditer(r"^class\s+\w+", text, re.MULTILINE):
        # Find the opening brace for this class.
        open_brace = text.find("{", m.end())
        if open_brace == -1:
            continue
        # Walk forward tracking brace depth to find the matching close.
        depth = 1
        pos = open_brace + 1
        in_single_line_comment = False
        in_block_comment = False
        in_single_string = False
        in_double_string = False
        while pos < len(text) and depth > 0:
            ch = text[pos]
            # Handle escape sequences inside strings.
            if (in_single_string or in_double_string) and ch == "\\":
                pos += 2
                continue
            # String state tracking.
            if not in_single_line_comment and not in_block_comment:
                if ch == "'" and not in_double_string:
                    in_single_string = not in_single_string
                elif ch == '"' and not in_single_string:
                    in_double_string = not in_double_string
            # Skip content inside strings entirely.
            if in_single_string or in_double_string:
                pos += 1
                continue
            # Comment tracking.
            if not in_block_comment and ch == "/" and pos + 1 < len(text):
                next_ch = text[pos + 1]
                if next_ch == "/":
                    in_single_line_comment = True
                    pos += 2
                    continue
                if next_ch == "*":
                    in_block_comment = True
                    pos += 2
                    continue
            if in_single_line_comment:
                if ch == "\n":
                    in_single_line_comment = False
                pos += 1
                continue
            if in_block_comment:
                if ch == "*" and pos + 1 < len(text) and text[pos + 1] == "/":
                    in_block_comment = False
                    pos += 2
                    continue
                pos += 1
                continue
            # Brace depth for class body.
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
            pos += 1
        class_bodies.append(text[open_brace:pos])

    # Phase 2: check each class body for the FileType.test pattern and LintCode.
    for body in class_bodies:
        if not _APPLICABLE_TEST.search(body):
            continue
        code_match = _LINT_CODE_NAME.search(body)
        if code_match:
            rules.append(code_match.group(1))

    return rules


def _find_fixture(rule_name: str, fixture_dirs: list[Path]) -> Path | None:
    """Find a fixture file for the given rule name in any fixture directory."""
    fixture_filename = f"{rule_name}_fixture.dart"
    for d in fixture_dirs:
        candidate = d / fixture_filename
        if candidate.exists():
            return candidate
    return None


def _compute_fix_target(rule_name: str, fixture_posix: str) -> str:
    """Compute the correct isTestPath-matching location for a misplaced fixture.

    Package-specific fixtures stay under example_packages/ so they keep their
    dependency context; all others go under example/lib/test/.
    """
    if "example_packages" in fixture_posix:
        return f"example_packages/lib/test/{rule_name}_fixture.dart"
    return f"example/lib/test/{rule_name}_fixture.dart"


def collect_mismatched_fixtures(
    project_dir: Path | str | None = None,
) -> list[tuple[str, str, str]]:
    """Return (rule_name, current_path, fix_target) for each misplaced fixture.

    Called by the publish pipeline to surface fixture-path violations as an
    audit check. Returns an empty list when everything is correct.
    """
    root = Path(project_dir) if project_dir else Path(".")
    rules_dir = root / "lib" / "src" / "rules"
    if not rules_dir.is_dir():
        return []

    # Collect all fixture directories under example/ and example_packages/.
    fixture_dirs: list[Path] = []
    for example_root in [root / "example", root / "example_packages"]:
        if example_root.is_dir():
            for subdir in sorted(example_root.rglob("*")):
                if subdir.is_dir():
                    fixture_dirs.append(subdir)
            fixture_dirs.append(example_root)

    # Scan all Dart rule files for FileType.test-gated rules.
    test_rules: list[tuple[str, Path]] = []
    for dart_file in sorted(rules_dir.rglob("*.dart")):
        for rule_name in _extract_test_rules(dart_file):
            test_rules.append((rule_name, dart_file))

    # Check each rule's fixture path against isTestPath().
    result: list[tuple[str, str, str]] = []
    for rule_name, _source_file in test_rules:
        fixture = _find_fixture(rule_name, fixture_dirs)
        if fixture is None:
            continue
        fixture_posix = fixture.as_posix()
        if not _is_test_path(fixture_posix):
            fix_target = _compute_fix_target(rule_name, fixture_posix)
            result.append((rule_name, fixture_posix, fix_target))

    return result


def _fix_mismatched(mismatched: list[tuple[str, str, str]]) -> int:
    """Move misplaced fixtures to isTestPath-matching locations via git mv.

    Returns the number of fixtures successfully moved.
    """
    import subprocess

    moved = 0
    for rule_name, old_path, new_path in mismatched:
        new_parent = Path(new_path).parent
        new_parent.mkdir(parents=True, exist_ok=True)
        # Use git mv to preserve history tracking.
        result = subprocess.run(
            ["git", "mv", old_path, new_path],
            capture_output=True,
            text=True,
        )
        if result.returncode == 0:
            print(f"  moved: {old_path} -> {new_path}")
            moved += 1
        else:
            print(f"  FAILED ({rule_name}): {result.stderr.strip()}")
    return moved


def main() -> int:
    """Check that FileType.test rule fixtures live at isTestPath-matching paths.

    With --fix: relocate misplaced fixtures via ``git mv``.
    """
    do_fix = "--fix" in sys.argv

    rules_dir = Path("lib/src/rules")
    if not rules_dir.is_dir():
        print(f"ERROR: {rules_dir} not found — run from repository root.",
              file=sys.stderr)
        return 1

    # Collect all fixture directories under example/ and example_packages/.
    fixture_dirs: list[Path] = []
    for example_root in [Path("example"), Path("example_packages")]:
        if example_root.is_dir():
            for subdir in sorted(example_root.rglob("*")):
                if subdir.is_dir():
                    fixture_dirs.append(subdir)
            fixture_dirs.append(example_root)

    # Scan all Dart rule files for FileType.test-gated rules.
    test_rules: list[tuple[str, Path]] = []
    for dart_file in sorted(rules_dir.rglob("*.dart")):
        for rule_name in _extract_test_rules(dart_file):
            test_rules.append((rule_name, dart_file))

    if not test_rules:
        print("No FileType.test-gated rules found.")
        return 0

    # Check each rule's fixture path.
    mismatched_details: list[str] = []
    mismatched_tuples: list[tuple[str, str, str]] = []
    no_fixture: list[str] = []
    ok_count = 0

    for rule_name, source_file in test_rules:
        fixture = _find_fixture(rule_name, fixture_dirs)
        if fixture is None:
            no_fixture.append(rule_name)
            continue

        fixture_posix = fixture.as_posix()
        if _is_test_path(fixture_posix):
            ok_count += 1
        else:
            fix_target = _compute_fix_target(rule_name, fixture_posix)
            mismatched_tuples.append((rule_name, fixture_posix, fix_target))
            mismatched_details.append(
                f"  {rule_name}\n"
                f"    fixture: {fixture_posix}\n"
                f"    source:  {source_file.as_posix()}\n"
                f"    fix:     move fixture to {fix_target}"
            )

    # Report results.
    print(f"FileType.test rules: {len(test_rules)} total, "
          f"{ok_count} fixtures at correct paths, "
          f"{len(no_fixture)} without fixtures, "
          f"{len(mismatched_details)} at wrong paths")

    if mismatched_details:
        if do_fix:
            # Relocate all misplaced fixtures via git mv.
            print(f"\nFixing {len(mismatched_tuples)} misplaced fixture(s):\n")
            moved = _fix_mismatched(mismatched_tuples)
            print(f"\nMoved {moved}/{len(mismatched_tuples)} fixtures.")
            # Re-check: any remaining failures after fix?
            remaining = len(mismatched_tuples) - moved
            if remaining:
                print(f"ERROR: {remaining} fixture(s) could not be moved.")
                return 1
            return 0

        print(f"\nERROR: {len(mismatched_details)} fixture(s) at paths that "
              f"don't match isTestPath():\n")
        for m in mismatched_details:
            print(m)
        print(
            "\nThe rule's applicableFileTypes => {FileType.test} means "
            "custom_lint skips files that don't match isTestPath(). "
            "Run with --fix to relocate them, or move fixtures manually to "
            "example/lib/test/ so the /test/ path segment triggers isTestPath()."
        )
        return 1

    if no_fixture:
        # Not an error — many rules don't have fixtures yet.
        print(f"\nInfo: {len(no_fixture)} rules without fixtures "
              f"(not an error):")
        for name in no_fixture[:10]:
            print(f"  {name}")
        if len(no_fixture) > 10:
            print(f"  ... and {len(no_fixture) - 10} more")

    return 0


if __name__ == "__main__":
    sys.exit(main())
