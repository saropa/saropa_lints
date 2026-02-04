"""
Publish workflow step functions (steps 1-10).

Extracted from publish_to_pubdev.py to keep the main script
focused on orchestration.

Version:   1.0
Author:    Saropa
Copyright: (c) 2025-2026 Saropa
"""

from __future__ import annotations

import subprocess
from pathlib import Path

from scripts.modules._utils import (
    Color,
    clear_flutter_lock,
    command_exists,
    get_shell_mode,
    is_windows,
    print_colored,
    print_error,
    print_header,
    print_info,
    print_success,
    print_warning,
    run_command,
)
from scripts.modules._pubdev_lint import (
    check_pubdev_lint_issues,
    fix_doc_angle_brackets,
    fix_doc_references,
)
from scripts.modules._version_changelog import (
    validate_changelog_version,
)


def run_pre_publish_audits(project_dir: Path) -> bool:
    """Run all audits before publish. Returns True if publish can proceed.

    BLOCKING checks (fail = no publish):
      - Tier integrity: orphans, phantoms, multi-tier, misplaced opinionated
      - Duplicate rule names, class names, or aliases

    INFORMATIONAL checks (warn but don't block):
      - DX message quality
      - OWASP coverage gaps
      - ROADMAP sync
      - Quality metrics
    """
    from scripts.modules._tier_integrity import (
        check_tier_integrity,
        print_tier_integrity_report,
    )
    from scripts.modules._audit import run_full_audit

    rules_dir = project_dir / "lib" / "src" / "rules"
    tiers_path = project_dir / "lib" / "src" / "tiers.dart"

    # --- BLOCKING: Tier integrity ---
    tier_result = check_tier_integrity(rules_dir, tiers_path)
    print_tier_integrity_report(tier_result)

    if not tier_result.passed:
        print_error(
            f"Tier integrity FAILED with {tier_result.issues_count} issue(s)."
        )
        print_error("Fix tier assignments in lib/src/tiers.dart.")
        return False

    # --- BLOCKING + INFORMATIONAL: Full audit ---
    audit_result = run_full_audit(
        project_dir=project_dir,
        skip_dx=False,
        compact=True,
    )

    if audit_result.has_blocking_issues:
        print_error("Blocking audit issues found (duplicate rules).")
        return False

    print_success("All pre-publish audit checks passed.")
    return True


def check_prerequisites() -> bool:
    """Step 2: Check that required tools are available."""
    print_header("STEP 2: CHECKING PREREQUISITES")

    tools = [
        ("flutter", "Install from https://flutter.dev"),
        ("git", "Install from https://git-scm.com"),
        ("gh", "Install from https://cli.github.com"),
    ]

    all_found = True
    for tool, hint in tools:
        if command_exists(tool):
            print_success(f"{tool} found")
        else:
            print_error(f"{tool} not found. {hint}")
            all_found = False

    return all_found


def check_working_tree(project_dir: Path) -> tuple[bool, bool]:
    """Step 3: Check working tree status.

    Returns:
        (ok, has_uncommitted_changes)
    """
    print_header("STEP 3: CHECKING WORKING TREE")

    use_shell = get_shell_mode()
    result = subprocess.run(
        ["git", "status", "--porcelain"],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell,
    )

    if result.stdout.strip():
        print_warning("You have uncommitted changes:")
        print_colored(result.stdout, Color.YELLOW)
        print()
        response = (
            input(
                "  These changes will be included in the "
                "release commit. Continue? [y/N] "
            )
            .strip()
            .lower()
        )
        if not response.startswith("y"):
            return False, True
        return True, True

    print_success("Working tree is clean")
    return True, False


def check_remote_sync(project_dir: Path, branch: str) -> bool:
    """Step 4: Check if local branch is in sync with remote."""
    print_header("STEP 4: CHECKING REMOTE SYNC")

    use_shell = get_shell_mode()

    # Fetch from remote
    print_info("Fetching from remote...")
    result = subprocess.run(
        ["git", "fetch", "origin", branch],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell,
    )
    if result.returncode != 0:
        print_warning("Could not fetch from remote. Proceeding anyway.")
        return True

    # Check if behind
    result = subprocess.run(
        ["git", "rev-list", "--count", f"HEAD..origin/{branch}"],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell,
    )
    if result.returncode == 0 and result.stdout.strip():
        behind_count = int(result.stdout.strip())
        if behind_count > 0:
            print_warning(
                f"Local branch is behind remote by {behind_count} commit(s)."
            )
            print_info(f"Pulling changes from origin/{branch}...")
            pull_result = subprocess.run(
                ["git", "pull", "origin", branch],
                cwd=project_dir,
                capture_output=True,
                text=True,
                shell=use_shell,
            )
            if pull_result.returncode != 0:
                print_error("Failed to pull changes from remote.")
                if pull_result.stderr:
                    print_colored(pull_result.stderr, Color.RED)
                return False
            print_success(f"Pulled {behind_count} commit(s) from remote")

    # Check if ahead
    result = subprocess.run(
        ["git", "rev-list", "--count", f"origin/{branch}..HEAD"],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell,
    )
    if result.returncode == 0 and result.stdout.strip():
        ahead_count = int(result.stdout.strip())
        if ahead_count > 0:
            print_warning(
                f"You have {ahead_count} unpushed commit(s) "
                f"that will be included."
            )
            print_success("Local branch is ahead of remote")
            return True

    print_success("Local branch is in sync with remote")
    return True


def run_tests(project_dir: Path) -> bool:
    """Step 5: Run flutter test and custom_lint tests."""
    print_header("STEP 5: RUNNING TESTS")

    clear_flutter_lock()

    test_dir = project_dir / "test"
    if test_dir.exists():
        result = run_command(
            ["flutter", "test"], project_dir, "Running unit tests"
        )
        if result.returncode != 0:
            return False
    else:
        print_warning("No test directory found, skipping unit tests")

    # Run custom_lint tests on example/
    example_dir = project_dir / "example"
    if example_dir.exists() and (example_dir / "pubspec.yaml").exists():
        print_info("Running custom_lint tests on example fixtures...")
        result = run_command(
            ["dart", "pub", "get"],
            example_dir,
            "Installing example dependencies",
        )
        if result.returncode != 0:
            print_warning("Could not install example deps, skipping")
            return True

        print_info("Running custom_lint tests...")
        print_colored("      $ dart run custom_lint", Color.WHITE)
        use_shell = get_shell_mode()
        result = subprocess.run(
            ["dart", "run", "custom_lint"],
            cwd=example_dir,
            capture_output=True,
            text=True,
            shell=use_shell,
        )
        output = result.stdout + result.stderr
        error_count = output.count(" • ERROR")
        warning_count = output.count(" • WARNING")
        info_count = output.count(" • INFO")
        total_count = error_count + warning_count + info_count

        if total_count > 0:
            print_success(
                f"Custom lint: {total_count} issues "
                f"({error_count}E, {warning_count}W, {info_count}I)"
            )
            print_colored(
                "      (Expected - fixture files trigger lints)", Color.WHITE
            )
        else:
            print_success("Custom lint tests completed: no issues found")

    return True


def run_format(project_dir: Path) -> bool:
    """Step 6: Run dart format."""
    print_header("STEP 6: FORMATTING CODE")

    use_shell = get_shell_mode()

    if is_windows():
        subprocess.run(
            ["git", "config", "core.autocrlf", "false"],
            cwd=project_dir,
            capture_output=True,
            shell=use_shell,
        )

    result = run_command(["dart", "format", "."], project_dir, "Formatting")
    if result.returncode != 0:
        if is_windows():
            subprocess.run(
                ["git", "config", "core.autocrlf", "true"],
                cwd=project_dir,
                capture_output=True,
                shell=use_shell,
            )
        return False

    subprocess.run(
        ["git", "add", "-A"],
        cwd=project_dir,
        capture_output=True,
        shell=use_shell,
    )

    if is_windows():
        subprocess.run(
            ["git", "config", "core.autocrlf", "true"],
            cwd=project_dir,
            capture_output=True,
            shell=use_shell,
        )

    print_success("Code formatted")
    return True


def run_analysis(project_dir: Path) -> bool:
    """Step 7: Run static analysis."""
    print_header("STEP 7: RUNNING STATIC ANALYSIS")

    print_info("Checking for pub.dev lint issues...")
    pubdev_issues = check_pubdev_lint_issues(project_dir)
    if pubdev_issues:
        print_warning(f"Found {len(pubdev_issues)} pub.dev lint issue(s):")
        for issue in pubdev_issues:
            print_colored(f"      {issue}", Color.YELLOW)

        # Auto-fix doc comment issues
        print_info("Auto-fixing doc comment issues...")
        fixed_brackets = fix_doc_angle_brackets(project_dir)
        fixed_refs = fix_doc_references(project_dir)
        total_fixed = fixed_brackets + fixed_refs

        if total_fixed:
            print_success(
                f"Auto-fixed {total_fixed} issue(s) "
                f"({fixed_brackets} angle bracket(s), "
                f"{fixed_refs} doc reference(s))."
            )

        # Re-check for remaining issues
        remaining = check_pubdev_lint_issues(project_dir)
        if remaining:
            print_error(
                f"{len(remaining)} unfixable pub.dev lint issue(s) remain:"
            )
            for issue in remaining:
                print_colored(f"      {issue}", Color.YELLOW)
            return False

        print_success("All pub.dev lint issues resolved")
    else:
        print_success("No pub.dev lint issues found")

    result = run_command(
        ["flutter", "analyze"], project_dir, "Analyzing code"
    )
    return result.returncode == 0


def validate_changelog(
    project_dir: Path, version: str
) -> tuple[bool, str]:
    """Step 9: Validate version in CHANGELOG and get release notes."""
    print_header("STEP 9: VALIDATING CHANGELOG")

    release_notes = validate_changelog_version(project_dir, version)
    if release_notes is None:
        print_error(f"Version {version} not found in CHANGELOG.md")
        return False, ""

    print_success(f"Found version {version} in CHANGELOG.md")

    if not release_notes:
        response = (
            input(f"  Use generic message 'Release {version}'? [y/N] ")
            .strip()
            .lower()
        )
        if not response.startswith("y"):
            return False, ""
        release_notes = f"Release {version}"
    else:
        print_colored("  Release notes preview:", Color.CYAN)
        for line in release_notes.split("\n")[:10]:
            print_colored(f"    {line}", Color.WHITE)
        if release_notes.count("\n") > 10:
            print_colored("    ...", Color.WHITE)

    return True, release_notes


def generate_docs(project_dir: Path) -> bool:
    """Step 10: Generate documentation."""
    print_header("STEP 10: GENERATING DOCUMENTATION")
    result = run_command(["dart", "doc"], project_dir, "Generating docs")
    return result.returncode == 0


def pre_publish_validation(project_dir: Path) -> bool:
    """Step 11: Run dart pub publish --dry-run."""
    print_header("STEP 11: PRE-PUBLISH VALIDATION")

    print_info("Running 'dart pub publish --dry-run'...")
    use_shell = get_shell_mode()
    result = subprocess.run(
        ["dart", "pub", "publish", "--dry-run"],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell,
    )

    if result.returncode in (0, 65):
        print_success("Package validated successfully")
        return True

    output = (result.stdout or "") + (result.stderr or "")
    if (
        is_windows()
        and "nul" in output.lower()
        and "path is invalid" in output.lower()
    ):
        print_success("Package validated successfully")
        return True

    print_error("Pre-publish validation failed!")
    print_colored(
        "\n======== pub.dev validation errors ========", Color.RED
    )
    if result.stdout:
        print(result.stdout)
    if result.stderr:
        print(result.stderr)
    print_colored("============================================\n", Color.RED)
    return False
