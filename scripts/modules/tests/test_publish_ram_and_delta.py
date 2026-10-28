"""Tests for macOS vm_stat parsing and tag-based delta test mapping."""

from __future__ import annotations

import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

VM_STAT = """Mach Virtual Memory Statistics: (page size of 16384 bytes)
Pages free:                               65536.
Pages active:                            100000.
Pages inactive:                           32768.
Pages speculative:                        16384.
"""


class TestParseVmStat(unittest.TestCase):
    def test_sums_free_inactive_speculative(self) -> None:
        from scripts.modules._publish_steps import _parse_vm_stat

        # (65536+32768+16384) pages * 16384 B = 1.75 GiB
        self.assertAlmostEqual(_parse_vm_stat(VM_STAT), 1.75)

    def test_unparseable_returns_none(self) -> None:
        from scripts.modules._publish_steps import _parse_vm_stat

        self.assertIsNone(_parse_vm_stat("garbage"))


class TestDeltaSinceTag(unittest.TestCase):
    def test_tag_diff_maps_rule_to_tests(self) -> None:
        from scripts.modules import _publish_steps as ps

        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / "test" / "rules" / "core").mkdir(parents=True)
            (root / "test" / "rules" / "core" / "foo_rules_test.dart").write_text("")
            (root / "test" / "integrity").mkdir()
            (root / "test" / "integrity" / "x_test.dart").write_text("")

            def fake_run(cmd, **kw):
                out = ""
                if cmd[:2] == ["git", "describe"]:
                    out = "v16.10.0\n"
                elif "v16.10.0..HEAD" in cmd:
                    out = "lib/src/rules/core/foo_rules.dart\n"
                return subprocess.CompletedProcess(cmd, 0, stdout=out, stderr="")

            with mock.patch.object(ps.subprocess, "run", side_effect=fake_run), \
                    mock.patch.dict(ps.os.environ, {"SAROPA_FULL_TESTS": ""}):
                got = ps._find_delta_test_files(root)
            self.assertIn("test/rules/core/foo_rules_test.dart", got)
            self.assertIn("test/integrity/x_test.dart", got)

    def test_full_tests_env_forces_full_suite(self) -> None:
        from scripts.modules import _publish_steps as ps

        with mock.patch.dict(ps.os.environ, {"SAROPA_FULL_TESTS": "1"}):
            self.assertEqual(ps._find_delta_test_files(Path(".")), [])


if __name__ == "__main__":
    unittest.main()
