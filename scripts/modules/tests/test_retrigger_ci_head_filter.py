"""Tests that offer_retrigger_ci only offers failed runs on the local HEAD commit.

Run from repository root::

    python3 -m unittest scripts.modules.tests.test_retrigger_ci_head_filter
"""

from __future__ import annotations

import unittest
from datetime import datetime, timezone
from unittest import mock

from scripts.modules import _retrigger_ci as rc

HEAD = "e403d95c" + "0" * 32
OLD = "cbc8a4f6" + "0" * 32


def _run(run_id: int, sha: str) -> dict:
    return {
        "databaseId": run_id,
        "headBranch": "main",
        "headSha": sha,
        "conclusion": "failure",
        "createdAt": datetime.now(timezone.utc).isoformat(),
    }


class OfferRetriggerHeadFilterTest(unittest.TestCase):
    def _offered(self, runs: list[dict], head: str | None) -> list[dict]:
        shown: list[dict] = []
        with mock.patch.object(rc, "get_failed_runs_safe", return_value=(True, runs)), \
                mock.patch.object(rc, "_current_branch", return_value="main"), \
                mock.patch.object(rc, "_head_sha", return_value=head), \
                mock.patch.object(rc, "print_warning"), \
                mock.patch.object(rc, "_display_failed_runs", side_effect=shown.extend), \
                mock.patch("builtins.input", side_effect=EOFError):
            rc.offer_retrigger_ci()
        return shown

    def test_older_sha_failure_dropped(self) -> None:
        self.assertEqual(self._offered([_run(1, OLD)], HEAD), [])

    def test_head_sha_failure_kept(self) -> None:
        shown = self._offered([_run(1, OLD), _run(2, HEAD)], HEAD)
        self.assertEqual([r["databaseId"] for r in shown], [2])

    def test_unreadable_head_keeps_all(self) -> None:
        shown = self._offered([_run(1, OLD)], None)
        self.assertEqual([r["databaseId"] for r in shown], [1])


if __name__ == "__main__":
    unittest.main()
