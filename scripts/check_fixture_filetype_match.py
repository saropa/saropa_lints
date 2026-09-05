#!/usr/bin/env python3
"""Verify fixtures for FileType.test-gated rules live at isTestPath-matching paths.

Rules with ``applicableFileTypes => {FileType.test}`` only fire on paths that
``ProjectFile.isTestPath()`` recognizes: files ending in ``_test.dart``, or
paths containing ``/test/``, ``/test_driver/``, or ``/integration_test/``.
A fixture at a non-matching path (e.g. ``example/lib/testing_best_practices/``)
is silently never exercised by the native custom_lint plugin, giving a false
sense of coverage.

Run from repository root::

    python scripts/check_fixture_filetype_match.py

Exit codes:
    0 - all FileType.test fixtures are at matching paths (or have no fixture)
    1 - one or more fixtures are at non-matching paths
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
    """Extract rule names from classes with applicableFileTypes => {FileType.test}."""
    text = dart_file.read_text(encoding="utf-8", errors="replace")
    rules: list[str] = []

    # Split into class blocks. Each class starts with "class <Name>" and ends
    # at the next top-level "class" or end of file. This is approximate but
    # sufficient for the consistent formatting in this codebase.
    class_blocks = re.split(r"\nclass\s+", text)

    for block in class_blocks:
        # Check if this class block declares FileType.test applicability.
        if not _APPLICABLE_TEST.search(block):
            continue

        # Find the LintCode name in this block.
        code_match = _LINT_CODE_NAME.search(block)
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


def main() -> int:
    """Check that FileType.test rule fixtures live at isTestPath-matching paths."""
    rules_dir = Path("lib/src/rules")
    if not rules_dir.is_dir():
        print(f"ERROR: {rules_dir} not found — run from repository root.",
              file=sys.stderr)
        return 1

    # Collect all fixture directories under example/ and example_packages/.
    fixture_dirs: list[Path] = []
    for example_root in [Path("example"), Path("example_packages")]:
        if example_root.is_dir():
            # Walk all subdirectories that could contain fixtures.
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
    mismatched: list[str] = []
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
            # Suggest correct target based on which example tree the fixture is in.
            if "example_packages" in fixture_posix:
                # Package-specific fixtures need their dependency context; suggest
                # a /test/ subdirectory within the same package subtree.
                parent = fixture.parent.as_posix()
                fix_target = f"{parent}/test/{rule_name}_fixture.dart"
            else:
                fix_target = f"example/lib/test/{rule_name}_fixture.dart"
            mismatched.append(
                f"  {rule_name}\n"
                f"    fixture: {fixture_posix}\n"
                f"    source:  {source_file.as_posix()}\n"
                f"    fix:     move fixture to {fix_target}"
            )

    # Report results.
    print(f"FileType.test rules: {len(test_rules)} total, "
          f"{ok_count} fixtures at correct paths, "
          f"{len(no_fixture)} without fixtures, "
          f"{len(mismatched)} at wrong paths")

    if mismatched:
        print(f"\nERROR: {len(mismatched)} fixture(s) at paths that don't "
              f"match isTestPath():\n")
        for m in mismatched:
            print(m)
        print(
            "\nThe rule's applicableFileTypes => {FileType.test} means "
            "custom_lint skips files that don't match isTestPath(). "
            "Move fixtures to example/lib/test/ so the /test/ path segment "
            "triggers isTestPath()."
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
