"""Tests for the moving major tag (``v16``) pushed in release step 13.

Run from repository root::

    python -m unittest discover -s scripts/modules/tests -t . -v

Actions consumers write ``uses: saropa/saropa_lints@v16``, so every stable
release moves ``v16`` to itself. These run against a real repository with a
real bare ``origin``, because what matters is where git leaves the tag.
Also pins the publish workflow's tag filter, which must not treat that
moving tag as a release.
"""

from __future__ import annotations

import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

from scripts.modules._git_ops import _move_major_version_tag

REPO_ROOT = Path(__file__).resolve().parents[3]


def git(cwd: Path, *args: str) -> str:
    return subprocess.run(
        ["git", *args], cwd=cwd, check=True, capture_output=True, text=True
    ).stdout.strip()


class TestMoveMajorVersionTag(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp(prefix="saropa-majortag-"))
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.remote = self.tmp / "remote.git"
        git(self.tmp, "init", "-q", "--bare", str(self.remote))
        self.repo = self.tmp / "work"
        self.repo.mkdir()
        git(self.repo, "init", "-q", "--initial-branch=main")
        git(self.repo, "config", "user.email", "t@example.com")
        git(self.repo, "config", "user.name", "T")
        git(self.repo, "config", "commit.gpgsign", "false")
        git(self.repo, "config", "tag.gpgsign", "false")
        git(self.repo, "remote", "add", "origin", str(self.remote))
        self.commit("one")

    def commit(self, message: str) -> str:
        (self.repo / "f.txt").write_text(message, encoding="utf-8")
        git(self.repo, "add", ".")
        git(self.repo, "commit", "-q", "-m", message)
        return git(self.repo, "rev-parse", "HEAD")

    def release(self, version: str) -> str:
        sha = git(self.repo, "rev-parse", "HEAD")
        git(self.repo, "tag", "-a", f"v{version}", "-m", f"Release v{version}")
        git(self.repo, "push", "-q", "origin", f"v{version}")
        return sha

    def remote_tag_commit(self, tag: str) -> str | None:
        result = subprocess.run(
            ["git", "rev-parse", "--verify", "--quiet", f"refs/tags/{tag}^{{commit}}"],
            cwd=self.remote, capture_output=True, text=True,
        )
        return result.stdout.strip() or None

    def test_points_the_major_tag_at_a_stable_release(self) -> None:
        sha = self.release("16.3.0")
        self.assertTrue(_move_major_version_tag(self.repo, "16.3.0"))
        self.assertEqual(self.remote_tag_commit("v16"), sha)

    def test_moves_it_on_the_next_release(self) -> None:
        self.release("16.3.0")
        _move_major_version_tag(self.repo, "16.3.0")
        sha = self.commit("two")
        self.release("16.4.0")
        self.assertTrue(_move_major_version_tag(self.repo, "16.4.0"))
        self.assertEqual(self.remote_tag_commit("v16"), sha)

    def test_leaves_it_alone_for_a_pre_release(self) -> None:
        stable = self.release("16.3.0")
        _move_major_version_tag(self.repo, "16.3.0")
        self.commit("beta")
        self.release("16.4.0-beta.1")
        self.assertTrue(_move_major_version_tag(self.repo, "16.4.0-beta.1"))
        self.assertEqual(self.remote_tag_commit("v16"), stable)

    def test_targets_the_release_commit_not_head(self) -> None:
        sha = self.release("16.3.0")
        self.commit("after the release")
        self.assertTrue(_move_major_version_tag(self.repo, "16.3.0"))
        self.assertEqual(self.remote_tag_commit("v16"), sha)

    def test_a_failed_push_warns_but_does_not_fail_the_release(self) -> None:
        self.release("16.3.0")
        git(self.repo, "remote", "set-url", "origin", str(self.tmp / "missing.git"))
        self.assertTrue(_move_major_version_tag(self.repo, "16.3.0"))


def github_tag_filter_to_regex(pattern: str) -> re.Pattern[str]:
    """GitHub's filter syntax: `*` = any run of non-`/`, `+` = one or more
    of the preceding character or class, `[...]` = a class, `.` literal."""
    out = ""
    i = 0
    while i < len(pattern):
        c = pattern[i]
        if c == "[":
            j = pattern.index("]", i)
            out += pattern[i : j + 1]
            i = j + 1
            continue
        if c == "*":
            out += "[^/]*"
        elif c == "+":
            out += "+"
        else:
            out += re.escape(c)
        i += 1
    return re.compile(f"^{out}$")


class TestPublishTagFilter(unittest.TestCase):
    def filters(self) -> list[re.Pattern[str]]:
        text = (REPO_ROOT / ".github" / "workflows" / "publish.yml").read_text(encoding="utf-8")
        block = text.split("tags:", 1)[1].split("\njobs:", 1)[0]
        patterns = re.findall(r"^\s*-\s*'([^']+)'", block, re.MULTILINE)
        self.assertTrue(patterns, "no tag filters found")
        return [github_tag_filter_to_regex(p) for p in patterns]

    def triggers(self, tag: str) -> bool:
        return any(f.match(tag) for f in self.filters())

    def test_exact_releases_trigger_publish(self) -> None:
        for tag in ("v16.3.0", "v1.5.3", "v16.4.0-beta.1", "v16.0.0-beta.10"):
            with self.subTest(tag=tag):
                self.assertTrue(self.triggers(tag))

    def test_the_moving_major_tag_does_not(self) -> None:
        for tag in ("v16", "v7"):
            with self.subTest(tag=tag):
                self.assertFalse(self.triggers(tag))


if __name__ == "__main__":
    unittest.main()
