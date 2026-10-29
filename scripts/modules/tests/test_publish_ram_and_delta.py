"""Tests for macOS vm_stat parsing and uncommitted-delta test mapping."""

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


class TestDeltaUncommitted(unittest.TestCase):
    def _root(self, d: str) -> Path:
        root = Path(d)
        (root / "test" / "rules" / "core").mkdir(parents=True)
        (root / "test" / "rules" / "core" / "foo_rules_test.dart").write_text("")
        (root / "test" / "integrity").mkdir()
        (root / "test" / "integrity" / "x_test.dart").write_text("")
        (root / "test" / "config").mkdir()
        (root / "test" / "config" / "c_test.dart").write_text("")
        return root

    def _delta(self, root: Path, head: str, staged: str = "") -> list[str]:
        from scripts.modules import _publish_steps as ps

        def fake_run(cmd, **kw):
            out = staged if "--cached" in cmd else head
            return subprocess.CompletedProcess(cmd, 0, stdout=out, stderr="")

        with mock.patch.object(ps, "safe_run", side_effect=fake_run), \
                mock.patch.dict(ps.os.environ, {"SAROPA_FULL_TESTS": ""}):
            return ps._find_delta_test_files(root)

    def test_uncommitted_rule_maps_to_tests(self) -> None:
        with tempfile.TemporaryDirectory() as d:
            got = self._delta(self._root(d), "lib/src/rules/core/foo_rules.dart\n")
            self.assertIn("test/rules/core/foo_rules_test.dart", got)
            self.assertIn("test/integrity/x_test.dart", got)

    def test_no_since_tag_union(self) -> None:
        from scripts.modules import _publish_steps as ps

        self.assertFalse(hasattr(ps, "_changed_since_last_tag"))
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(self._delta(self._root(d), ""), [])

    def test_broad_impact_runs_integrity_and_config_only(self) -> None:
        with tempfile.TemporaryDirectory() as d:
            got = self._delta(self._root(d), "lib/src/tiers.dart\n")
            self.assertEqual(
                got, ["test/config/c_test.dart", "test/integrity/x_test.dart"]
            )

    def test_full_tests_env_returns_empty_delta(self) -> None:
        from scripts.modules import _publish_steps as ps

        with mock.patch.dict(ps.os.environ, {"SAROPA_FULL_TESTS": "1"}):
            self.assertEqual(ps._find_delta_test_files(Path(".")), [])


class TestRunTestsDeltaOnly(unittest.TestCase):
    def _run(self, full: str, delta: list[str]):
        from scripts.modules import _publish_steps as ps

        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / "test").mkdir()
            with mock.patch.object(ps, "clear_flutter_lock"), \
                    mock.patch.object(ps, "_dart_test_env", return_value={}), \
                    mock.patch.object(ps, "_auto_tune_concurrency", return_value=2), \
                    mock.patch.object(ps, "_find_delta_test_files", return_value=delta), \
                    mock.patch.object(ps, "_generate_aggregate_targets", return_value=[]), \
                    mock.patch.object(ps, "_run_test_pass", return_value=True) as rp, \
                    mock.patch.dict(ps.os.environ, {"SAROPA_FULL_TESTS": full}):
                ok = ps.run_tests(root)
        return ok, rp

    def test_clean_tree_skips_without_full_fallback(self) -> None:
        ok, rp = self._run("", [])
        self.assertTrue(ok)
        rp.assert_not_called()

    def test_full_tests_runs_full_suite(self) -> None:
        ok, rp = self._run("1", [])
        self.assertTrue(ok)
        rp.assert_called_once()
        self.assertEqual(rp.call_args.kwargs["label"], "fast")

    def test_delta_runs_with_slow_excluded(self) -> None:
        ok, rp = self._run("", ["test/a_test.dart"])
        self.assertTrue(ok)
        self.assertEqual(rp.call_args.kwargs["label"], "delta")
        self.assertEqual(rp.call_args.kwargs["extra_args"][:2], ["-x", "slow"])


if __name__ == "__main__":
    unittest.main()
