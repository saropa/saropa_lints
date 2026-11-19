"""run_command / safe_run must never hang silently."""
import subprocess
import sys
import time
import unittest
from pathlib import Path

from scripts.modules import _utils
from scripts.modules._utils import run_command, safe_run

CWD = Path(".")


class SafeRunTests(unittest.TestCase):
    def test_stdin_is_devnull_so_prompt_fails_fast(self):
        start = time.monotonic()
        r = safe_run(
            [sys.executable, "-c", "import sys; print(repr(sys.stdin.read()))"],
            capture_output=True, text=True, timeout=20,
        )
        self.assertEqual(r.returncode, 0)
        self.assertEqual(r.stdout.strip(), "''")
        self.assertLess(time.monotonic() - start, 15)

    def test_timeout_kills_and_reports(self):
        code = "import time; print('last line', flush=True); time.sleep(60)"
        start = time.monotonic()
        r = safe_run(
            [sys.executable, "-c", code],
            capture_output=True, text=True, timeout=2,
        )
        self.assertEqual(r.returncode, 124)
        self.assertLess(time.monotonic() - start, 20)
        self.assertIn("TIMEOUT", r.stderr)
        self.assertIn("time.sleep", r.stderr)

    def test_timeout_kills_grandchildren_holding_pipe(self):
        code = (
            "import subprocess,sys,time;"
            "subprocess.Popen([sys.executable,'-c','import time;time.sleep(60)']);"
            "time.sleep(60)"
        )
        start = time.monotonic()
        r = safe_run([sys.executable, "-c", code],
                     capture_output=True, text=True, timeout=2)
        self.assertEqual(r.returncode, 124)
        self.assertLess(time.monotonic() - start, 20)

    def test_heartbeat_printed(self):
        lines = []
        orig = _utils.print_info
        _utils.print_info = lines.append
        try:
            safe_run([sys.executable, "-c", "import time; time.sleep(2.5)"],
                     capture_output=True, text=True, timeout=30,
                     heartbeat=1, label="sleeper")
        finally:
            _utils.print_info = orig
        self.assertTrue(any("still running: sleeper" in l for l in lines))

    def test_tty_keeps_stdin_inherited(self):
        r = safe_run([sys.executable, "-c", "pass"], tty=True, timeout=20)
        self.assertEqual(r.returncode, 0)

    def test_env_hardened(self):
        r = safe_run(
            [sys.executable, "-c",
             "import os;print(os.environ['GIT_TERMINAL_PROMPT'],"
             "os.environ['npm_config_yes'])"],
            capture_output=True, text=True, timeout=20)
        self.assertEqual(r.stdout.split(), ["0", "true"])


class RunCommandTests(unittest.TestCase):
    def test_timeout_returns_nonzero_with_diagnostics(self):
        r = run_command(
            [sys.executable, "-c", "import time; time.sleep(60)"],
            CWD, "sleeper", capture_output=True, allow_failure=True, timeout=2,
        )
        self.assertEqual(r.returncode, 124)

    def test_default_timeouts(self):
        self.assertEqual(_utils._default_timeout(["git", "status"]), 120)
        self.assertGreaterEqual(_utils._default_timeout(["dart", "test"]), 1800)
        self.assertGreaterEqual(_utils._default_timeout(["npx", "x"]), 600)


if __name__ == "__main__":
    unittest.main()
