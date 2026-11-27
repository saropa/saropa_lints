"""Tests for release step 14: following the publish workflow.

Run from repository root::

    python -m unittest scripts.modules.tests.test_publish_ci_watch -v

No network, git or gh: every subprocess and prompt is faked.
"""

from __future__ import annotations

import json
import subprocess
import unittest
from pathlib import Path
from unittest import mock

from scripts.modules import _git_ops

MOD = "scripts.modules._git_ops"
ROOT = Path(".")
RUNNING = ("in_progress", "")
PASSED = ("completed", "success")
FAILED = ("completed", "failure")
UNREADABLE = ("unknown", "")


def done(returncode: int = 0, stdout: str = "") -> subprocess.CompletedProcess:
    return subprocess.CompletedProcess([], returncode, stdout, "")


class FollowRunTest(unittest.TestCase):
    """The run state, not the watch exit code, decides the outcome."""

    def follow(self, states, answers=(), unattended=False):
        # Exit 124 is what safe_run returns when the watch window expires.
        with mock.patch(f"{MOD}._query_run_state", side_effect=states), \
                mock.patch(f"{MOD}.safe_run", return_value=done(124)), \
                mock.patch(f"{MOD}.safe_input", side_effect=list(answers)), \
                mock.patch(f"{MOD}.is_non_interactive",
                           return_value=unattended), \
                mock.patch("time.sleep"):
            return _git_ops._follow_publish_run(ROOT, "1", "url")

    def test_timeout_then_enter_keeps_watching_to_success(self):
        self.assertEqual(self.follow([RUNNING, RUNNING, PASSED], [""]),
                         "success")

    def test_abort_while_running_is_stopped_not_failed(self):
        self.assertEqual(self.follow([RUNNING, RUNNING], ["a"]), "stopped")

    def test_only_a_completed_conclusion_is_failure(self):
        self.assertEqual(self.follow([UNREADABLE, FAILED]), "failed")

    def test_unattended_keeps_watching_without_prompting(self):
        states = [RUNNING, RUNNING, PASSED]
        self.assertEqual(self.follow(states, unattended=True), "success")


class StepTest(unittest.TestCase):
    """Menus offered by publish_to_pubdev_step."""

    def run_step(self, outcomes, answers=(), unattended=False):
        with mock.patch(f"{MOD}.get_remote_url", return_value=""), \
                mock.patch(f"{MOD}._find_workflow_run", return_value="1"), \
                mock.patch(f"{MOD}._follow_publish_run",
                           side_effect=outcomes), \
                mock.patch(f"{MOD}._report_workflow_failure"), \
                mock.patch(f"{MOD}.safe_input", side_effect=list(answers)), \
                mock.patch(f"{MOD}.is_non_interactive",
                           return_value=unattended), \
                mock.patch(f"{MOD}._offer_local_publish") as local:
            try:
                return _git_ops.publish_to_pubdev_step(ROOT, "1.2.3")
            finally:
                # No scenario here chooses local publish.
                local.assert_not_called()

    def test_check_again_continues_after_a_rerun(self):
        self.assertTrue(self.run_step(["failed", "success"], [""]))

    def test_abort_while_running_exits_with_no_further_prompt(self):
        with self.assertRaises(SystemExit):
            self.run_step(["stopped"])

    def test_unattended_failure_returns_false_without_local_publish(self):
        self.assertFalse(self.run_step(["failed"], unattended=True))


class FindRunTest(unittest.TestCase):
    """Only a run for this tag at the tagged commit counts."""

    def test_matches_tag_and_commit_including_failed_runs(self):
        runs = [
            {"databaseId": 1, "headBranch": "v9.9.9", "headSha": "abc"},
            {"databaseId": 2, "headBranch": "v1.2.3", "headSha": "old"},
            {"databaseId": 3, "headBranch": "v1.2.3", "headSha": "abc",
             "conclusion": "failure"},
        ]
        results = [done(stdout="abc\n"), done(stdout=json.dumps(runs))]
        with mock.patch(f"{MOD}.safe_run", side_effect=results):
            self.assertEqual(
                _git_ops._find_workflow_run(ROOT, "v1.2.3"), "3")


if __name__ == "__main__":
    unittest.main()
