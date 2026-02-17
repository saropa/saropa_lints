"""
Git operations for the publish workflow.

Handles branch detection, remote URL parsing, commit/push with retry,
tag creation, GitHub Actions publish trigger, and GitHub release creation.

Version:   1.0
Author:    Saropa
Copyright: (c) 2025-2026 Saropa
"""

from __future__ import annotations

import re
import subprocess
from pathlib import Path

from scripts.modules._utils import (
    Color,
    get_shell_mode,
    print_colored,
    print_error,
    print_header,
    print_info,
    print_success,
    print_warning,
    run_command,
)


def get_current_branch(project_dir: Path) -> str:
    """Get the current git branch name."""
    use_shell = get_shell_mode()
    result = subprocess.run(
        ["git", "rev-parse", "--abbrev-ref", "HEAD"],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell,
    )
    return result.stdout.strip() if result.returncode == 0 else "main"


def get_remote_url(project_dir: Path) -> str:
    """Get the git remote URL."""
    use_shell = get_shell_mode()
    result = subprocess.run(
        ["git", "remote", "get-url", "origin"],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell,
    )
    return result.stdout.strip() if result.returncode == 0 else ""


def extract_repo_path(remote_url: str) -> str:
    """Extract owner/repo from git remote URL."""
    match = re.search(r"github\.com[:/](.+?)(?:\.git)?$", remote_url)
    return match.group(1) if match else "owner/repo"


def tag_exists_on_remote(project_dir: Path, tag_name: str) -> bool:
    """Check if a git tag already exists on the remote."""
    use_shell = get_shell_mode()
    result = subprocess.run(
        ["git", "ls-remote", "--tags", "origin", tag_name],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell,
    )
    return bool(result.stdout.strip())


def git_commit_and_push(
    project_dir: Path, version: str, branch: str
) -> bool:
    """Step 12: Commit changes and push to remote."""
    print_header("STEP 12: COMMITTING CHANGES")

    tag_name = f"v{version}"
    use_shell = get_shell_mode()

    result = run_command(
        ["git", "add", "-A"], project_dir, "Staging changes"
    )
    if result.returncode != 0:
        return False

    result = subprocess.run(
        ["git", "status", "--porcelain"],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell,
    )

    if result.stdout.strip():
        result = run_command(
            ["git", "commit", "-m", f"Release {tag_name}"],
            project_dir,
            f"Committing: Release {tag_name}",
        )
        if result.returncode != 0:
            return False

        if not _push_with_retry(project_dir, branch):
            return False
    else:
        print_success("No changes to commit.")

    return True


def _push_with_retry(
    project_dir: Path, branch: str, max_retries: int = 2
) -> bool:
    """Push to remote, pulling and retrying if rejected."""
    use_shell = get_shell_mode()

    for attempt in range(max_retries + 1):
        print_info(f"Pushing to {branch}...")
        result = subprocess.run(
            ["git", "push", "origin", branch],
            cwd=project_dir,
            capture_output=True,
            text=True,
            shell=use_shell,
        )
        if result.returncode == 0:
            print_success(f"Pushed to {branch}")
            return True

        output = (result.stdout or "") + (result.stderr or "")
        if "rejected" in output and (
            "fetch first" in output or "non-fast-forward" in output
        ):
            if attempt < max_retries:
                print_warning(
                    "Push rejected - pulling and retrying..."
                )
                pull_result = subprocess.run(
                    ["git", "pull", "--rebase", "origin", branch],
                    cwd=project_dir,
                    capture_output=True,
                    text=True,
                    shell=use_shell,
                )
                if pull_result.returncode != 0:
                    print_error("Failed to pull remote changes.")
                    return False
                print_success("Rebased remote changes")
                continue
            print_error("Push failed after retries.")
            return False

        print_error(f"Push failed (exit code {result.returncode})")
        if output:
            print_colored(output, Color.RED)
        return False

    return False


def create_git_tag(project_dir: Path, version: str) -> bool:
    """Step 13: Create and push git tag."""
    print_header("STEP 13: CREATING GIT TAG")

    tag_name = f"v{version}"
    use_shell = get_shell_mode()

    # Check if tag exists locally
    result = subprocess.run(
        ["git", "tag", "-l", tag_name],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell,
    )
    if result.stdout.strip():
        print_warning(f"Tag {tag_name} already exists locally.")
    else:
        result = run_command(
            [
                "git", "tag", "-a", tag_name,
                "-m", f"Release {tag_name}",
            ],
            project_dir,
            f"Creating tag {tag_name}",
        )
        if result.returncode != 0:
            return False

    # Check if tag exists on remote — blocker if already published
    result = subprocess.run(
        ["git", "ls-remote", "--tags", "origin", tag_name],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell,
    )
    if result.stdout.strip():
        print_error(
            f"Tag {tag_name} already exists on remote. "
            f"This version has already been published."
        )
        return False
    else:
        result = run_command(
            ["git", "push", "origin", tag_name],
            project_dir,
            f"Pushing tag {tag_name}",
        )
        if result.returncode != 0:
            return False

    return True


def _find_workflow_run(
    project_dir: Path, tag_name: str,
) -> str | None:
    """Poll GitHub Actions until the publish workflow run appears.

    GitHub may take several seconds to queue the workflow after a
    tag push. Retries every 5 seconds for up to 60 seconds.

    Returns the run's database ID as a string, or None.
    """
    import json
    import time

    use_shell = get_shell_mode()
    max_wait = 60
    interval = 5

    for elapsed in range(0, max_wait + 1, interval):
        if elapsed > 0:
            print_info(
                f"  Waiting for workflow to appear "
                f"({elapsed}s / {max_wait}s)..."
            )
            time.sleep(interval)

        result = subprocess.run(
            [
                "gh", "run", "list",
                "--workflow=publish.yml",
                f"--branch={tag_name}",
                "--limit=1",
                "--json=databaseId,status,conclusion",
            ],
            cwd=project_dir,
            capture_output=True,
            text=True,
            shell=use_shell,
        )
        if result.returncode != 0:
            continue

        try:
            runs = json.loads(result.stdout)
        except json.JSONDecodeError:
            continue

        if runs:
            return str(runs[0]["databaseId"])

    return None


def _report_workflow_failure(
    project_dir: Path, run_id: str, repo_path: str,
) -> None:
    """Print details about a failed GitHub Actions workflow run."""
    import json

    use_shell = get_shell_mode()
    print_error("GitHub Actions publish workflow FAILED!")
    print_colored(
        f"  View logs: gh run view {run_id} --log",
        Color.DIM,
    )
    print_colored(
        f"  URL: https://github.com/{repo_path}"
        f"/actions/runs/{run_id}",
        Color.DIM,
    )

    log_result = subprocess.run(
        ["gh", "run", "view", run_id, "--json=jobs"],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell,
    )
    if log_result.returncode == 0:
        try:
            data = json.loads(log_result.stdout)
            for job in data.get("jobs", []):
                for step in job.get("steps", []):
                    if step.get("conclusion") == "failure":
                        print_error(
                            f"  Failed step: {step['name']}"
                        )
        except (json.JSONDecodeError, KeyError):
            pass


def publish_to_pubdev_step(
    project_dir: Path, version: str,
) -> bool:
    """Step 14: Wait for GitHub Actions publish workflow.

    Polls until the workflow run appears, then watches it to
    completion. Returns True only when the workflow succeeds.
    """
    print_header("STEP 14: PUBLISHING TO PUB.DEV VIA GITHUB ACTIONS")

    tag_name = f"v{version}"
    use_shell = get_shell_mode()
    remote_url = get_remote_url(project_dir)
    repo_path = extract_repo_path(remote_url)

    print_info(
        "Tag push triggered GitHub Actions publish workflow."
    )
    print_colored(
        f"  Waiting for workflow to appear...",
        Color.CYAN,
    )
    print_colored(
        f"  Monitor: https://github.com/{repo_path}/actions",
        Color.DIM,
    )
    print()

    run_id = _find_workflow_run(project_dir, tag_name)
    if not run_id:
        print_warning(
            f"No publish workflow found for tag {tag_name} "
            f"after 60s. Check GitHub Actions manually."
        )
        return False

    print_info(f"Watching workflow run {run_id}...")
    watch_result = subprocess.run(
        ["gh", "run", "watch", run_id, "--exit-status"],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell,
        timeout=300,
    )

    if watch_result.returncode == 0:
        print_success(
            "GitHub Actions publish workflow succeeded!"
        )
        return True

    _report_workflow_failure(project_dir, run_id, repo_path)
    return False


def create_github_release(
    project_dir: Path, version: str, release_notes: str
) -> tuple[bool, str | None]:
    """Step 15: Create GitHub release."""
    print_header("STEP 15: CREATING GITHUB RELEASE")

    tag_name = f"v{version}"
    use_shell = get_shell_mode()

    # Check if release exists
    result = subprocess.run(
        ["gh", "release", "view", tag_name],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell,
    )
    if result.returncode == 0:
        return False, (
            f"Release {tag_name} already exists. "
            f"This version has already been published."
        )

    result = subprocess.run(
        [
            "gh", "release", "create", tag_name,
            "--title", f"Release {tag_name}",
            "--notes", release_notes,
        ],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell,
    )

    if result.returncode == 0:
        print_success(f"Created GitHub release {tag_name}")
        return True, None

    error_output = (result.stderr or "") + (result.stdout or "")
    if any(
        s in error_output.lower()
        for s in ["401", "bad credentials", "authentication"]
    ):
        return False, (
            "GitHub CLI auth failed. Clear GITHUB_TOKEN env var "
            "and run: gh auth status"
        )
    return False, (
        f"Release failed (exit code {result.returncode})"
        f"{': ' + error_output.strip() if error_output.strip() else ''}"
    )


def post_publish_commit(
    project_dir: Path, next_version: str, branch: str
) -> bool:
    """Commit and push the post-publish version bump.

    Stages only pubspec.yaml and CHANGELOG.md — never uses
    'git add -A' to avoid picking up unrelated changes.
    """
    use_shell = get_shell_mode()

    result = subprocess.run(
        ["git", "add", "pubspec.yaml", "CHANGELOG.md"],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell,
    )
    if result.returncode != 0:
        return False

    result = subprocess.run(
        ["git", "commit", "-m", f"chore: bump version to {next_version}"],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell,
    )
    if result.returncode != 0:
        print_warning("Could not commit version bump.")
        return False

    return _push_with_retry(project_dir, branch)
