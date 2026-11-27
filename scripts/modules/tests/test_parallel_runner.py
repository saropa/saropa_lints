"""Tests for the parallel lane runner used by the publish pipeline.

Run from repository root::

    python -m unittest scripts.modules.tests.test_parallel_runner -v

Lanes run tiny Python one-liners; no dart, npm or git.
"""

from __future__ import annotations

import shutil
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from scripts.modules import _parallel
from scripts.modules._parallel import Cmd, Lane, run_group, run_lanes


class ParallelRunnerTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp(prefix="saropa-parallel-"))
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)

    def script(self, body: str, **kwargs) -> Cmd:
        # A script file avoids shell quoting differences under shell=True.
        path = self.tmp / f"s{len(list(self.tmp.glob('s*.py')))}.py"
        path.write_text(body, encoding="utf-8")
        return Cmd(["python", str(path)], self.tmp, **kwargs)

    def test_lanes_overlap_and_keep_output_separate(self):
        # Each lane waits for the other's marker, so a serial run would fail.
        body = (
            "import pathlib, sys, time\n"
            "pathlib.Path('{me}').write_text('x')\n"
            "for _ in range(200):\n"
            "    if pathlib.Path('{other}').exists():\n"
            "        print('{me}-done'); sys.exit(0)\n"
            "    time.sleep(0.05)\n"
            "sys.exit(1)\n"
        )
        a = Lane("a", [self.script(body.format(me="a", other="b"))])
        b = Lane("b", [self.script(body.format(me="b", other="a"))])
        self.assertEqual(run_lanes([a, b], self.tmp), [])
        self.assertEqual(a.output.strip(), "a-done")
        self.assertEqual(b.output.strip(), "b-done")

    def test_failed_command_stops_its_lane_only(self):
        bad = Lane("bad", [self.script("raise SystemExit(1)"),
                           self.script("open('after','w')")])
        good = Lane("good", [self.script("print('ok')")])
        self.assertEqual(run_lanes([bad, good], self.tmp), [bad])
        self.assertFalse((self.tmp / "after").exists())
        self.assertEqual(good.next_index, 1)

    def test_retry_resumes_at_the_failed_command(self):
        # The first command counts its runs; the second passes the second time.
        first = self.script("open('first','a').write('x')")
        second = self.script(
            "import pathlib, sys\n"
            "p = pathlib.Path('flag')\n"
            "if p.exists(): sys.exit(0)\n"
            "p.write_text('x'); sys.exit(1)\n"
        )
        lane = Lane("l", [first, second])
        with mock.patch.object(_parallel, "prompt_step_failure",
                               return_value="retry") as prompt:
            self.assertTrue(run_group("g", [lane], self.tmp))
        prompt.assert_called_once()
        self.assertEqual((self.tmp / "first").read_text(), "x")

    def test_abort_returns_false(self):
        lane = Lane("l", [self.script("raise SystemExit(1)")])
        with mock.patch.object(_parallel, "prompt_step_failure",
                               return_value="abort"):
            self.assertFalse(run_group("g", [lane], self.tmp))

    def test_accept_hook_and_allow_failure(self):
        warn = self.script("raise SystemExit(65)",
                           accept=lambda code, _out: code == 65)
        optional = self.script("raise SystemExit(1)", allow_failure=True)
        self.assertEqual(
            run_lanes([Lane("l", [warn, optional])], self.tmp), [])

    def test_timeout_fails_the_lane(self):
        slow = self.script("import time; time.sleep(60)", timeout=0.5)
        lane = Lane("slow", [slow])
        self.assertEqual(run_lanes([lane], self.tmp), [lane])


if __name__ == "__main__":
    unittest.main()
