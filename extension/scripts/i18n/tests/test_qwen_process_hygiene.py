"""Tests for the Qwen engine's Ollama process hygiene.

Run from the repo root::

    python extension/scripts/i18n/tests/test_qwen_process_hygiene.py

NOTHING here starts, contacts, or kills a real process. Every OS boundary is
mocked: ``subprocess.run``, ``os.killpg``/``os.kill``, the process-table
snapshot, and the HTTP endpoint probe. The suite pins the contract of the fix
for the orphaned-``llama-server`` leak
(``bugs/infra_translation_engine_orphans_llama_server_processes.md``):

  * every kill path terminates a TREE, on both Windows and POSIX,
  * the orphan sweep terminates only hosts whose parent is gone,
  * the safety guards refuse to touch a daemon this run did not start, and
    refuse to sweep while a daemon is still serving.

The kill-command shape is asserted literally (``/T`` present, ``/F`` only on the
escalation) because that single missing flag WAS the bug — a test that only
checked "some kill happened" would have passed against the broken code.
"""

from __future__ import annotations

import os
import signal
import sys
import unittest
from unittest import mock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import qwen_engine as qe  # noqa: E402 — path injected above


# Stand-in for signal.SIGKILL, which does not exist on Windows where this
# suite also runs. Only its identity matters — the OS call is mocked.
_FAKE_SIGKILL = 9


def _proc(pid: int, ppid: int, name: str, gb: float = 1.0) -> qe._ProcInfo:
    """Build one snapshot row without touching the real process table."""
    return qe._ProcInfo(pid=pid, ppid=ppid, name=name, commit_bytes=int(gb * 1024**3))


class TestWindowsKillShape(unittest.TestCase):
    """The Windows kill must pass /T; without it llama-server.exe is stranded."""

    def _run_win(self, *, dies_gracefully: bool):
        # Liveness is scripted rather than probed so the escalation branch is
        # reachable without a real process.
        gone = iter([dies_gracefully] * 40)
        with mock.patch.object(qe.sys, "platform", "win32"), \
                mock.patch.object(qe.subprocess, "run") as run, \
                mock.patch.object(qe, "_wait_pid_gone",
                                  side_effect=lambda *_a, **_k: next(gone, True)):
            qe._terminate_tree(4321)
        return [call.args[0] for call in run.call_args_list]

    def test_graceful_tree_kill_comes_first_and_carries_slash_t(self) -> None:
        cmds = self._run_win(dies_gracefully=True)
        self.assertEqual(cmds, [["taskkill", "/PID", "4321", "/T"]])
        # /F must NOT be in the first attempt: a force kill is what denies the
        # daemon the chance to shut its own model host down.
        self.assertNotIn("/F", cmds[0])

    def test_force_escalation_still_walks_the_tree(self) -> None:
        cmds = self._run_win(dies_gracefully=False)
        self.assertEqual(len(cmds), 2)
        self.assertEqual(cmds[1], ["taskkill", "/PID", "4321", "/T", "/F"])
        # The regression guard: /F alone (the old code) leaves the child behind.
        self.assertIn("/T", cmds[1])

    def test_global_image_kill_when_opted_in_uses_tree_flag(self) -> None:
        with mock.patch.object(qe.sys, "platform", "win32"), \
                mock.patch.dict(qe.os.environ, {"SAROPA_QWEN_ALLOW_GLOBAL_KILL": "1"}), \
                mock.patch.object(qe, "sweep_orphan_model_hosts", return_value=0), \
                mock.patch.object(qe.subprocess, "run") as run:
            self.assertTrue(qe._kill_all_ollama())
        self.assertEqual(run.call_args_list[0].args[0],
                         ["taskkill", "/IM", "ollama.exe", "/T", "/F"])


class TestPosixKillShape(unittest.TestCase):
    """POSIX's equivalent of /T is signalling the process GROUP."""

    def test_group_signalled_term_then_kill(self) -> None:
        # Never dies, so both escalation steps are exercised. os.killpg and
        # SIGKILL are POSIX-only names, so they are created for the duration
        # of the test — this suite also runs on Windows.
        with mock.patch.object(qe.sys, "platform", "linux"), \
                mock.patch.object(qe.signal, "SIGKILL", _FAKE_SIGKILL, create=True), \
                mock.patch.object(qe.os, "killpg", create=True) as killpg, \
                mock.patch.object(qe, "_wait_pid_gone", return_value=False), \
                mock.patch.object(qe, "_pid_alive", return_value=False):
            qe._terminate_tree(777)
        self.assertEqual(
            [c.args for c in killpg.call_args_list],
            [(777, signal.SIGTERM), (777, _FAKE_SIGKILL)],
        )

    def test_falls_back_to_bare_pid_when_not_a_group_leader(self) -> None:
        # A PID that leads no group still has to be reachable; the fallback must
        # target the same PID rather than silently doing nothing.
        with mock.patch.object(qe.sys, "platform", "linux"), \
                mock.patch.object(qe.signal, "SIGKILL", _FAKE_SIGKILL, create=True), \
                mock.patch.object(qe.os, "killpg", create=True,
                                  side_effect=ProcessLookupError), \
                mock.patch.object(qe.os, "kill", create=True) as kill, \
                mock.patch.object(qe, "_wait_pid_gone", return_value=True):
            qe._terminate_tree(888)
        self.assertEqual(kill.call_args.args, (888, signal.SIGTERM))


class TestOrphanDetection(unittest.TestCase):
    """Parent liveness is the ONLY thing that makes a model host killable."""

    SNAPSHOT = [
        _proc(100, 4, "ollama.exe"),            # a live daemon
        _proc(101, 100, "llama-server.exe", 9.5),   # its child — parent ALIVE
        _proc(102, 999, "llama-server.exe", 15.8),  # orphan — parent 999 is gone
        _proc(103, 4, "code.exe"),              # unrelated
    ]

    def test_only_parentless_hosts_are_orphans(self) -> None:
        with mock.patch.object(qe, "_snapshot_processes", return_value=self.SNAPSHOT):
            orphans = qe.find_orphan_model_hosts()
        self.assertEqual([p.pid for p in orphans], [102])

    def test_snapshot_failure_is_unknown_not_empty(self) -> None:
        # None must not collapse to "nothing to kill" — a caller that cannot see
        # the process table has no business terminating anything.
        with mock.patch.object(qe, "_snapshot_processes", return_value=None):
            self.assertIsNone(qe.find_orphan_model_hosts())

    def test_legacy_host_image_name_recognized(self) -> None:
        snap = [_proc(200, 4, "ollama.exe"), _proc(201, 555, "ollama_llama_server.exe")]
        with mock.patch.object(qe, "_snapshot_processes", return_value=snap):
            self.assertEqual([p.pid for p in qe.find_orphan_model_hosts()], [201])

    def test_description_reports_total_memory(self) -> None:
        text = qe._describe_orphans([_proc(1, 9, "llama-server.exe", 9.5),
                                     _proc(2, 9, "llama-server.exe", 15.8)])
        self.assertIn("25.3 GB", text)
        self.assertIn("PID 1", text)


class TestSweepSafety(unittest.TestCase):
    def test_sweep_terminates_only_the_orphan(self) -> None:
        with mock.patch.object(qe, "_endpoint_up", return_value=False), \
                mock.patch.object(qe, "_snapshot_processes",
                                  return_value=TestOrphanDetection.SNAPSHOT), \
                mock.patch.object(qe, "_terminate_tree", return_value=True) as term:
            self.assertEqual(qe.sweep_orphan_model_hosts(), 1)
        self.assertEqual([c.args[0] for c in term.call_args_list], [102])

    def test_sweep_refuses_while_a_daemon_is_serving(self) -> None:
        # A responding endpoint means a live client may be mid-request. Killing
        # a serving daemon's host is exactly the incident this code prevents.
        with mock.patch.object(qe, "_endpoint_up", return_value=True), \
                mock.patch.object(qe, "_terminate_tree") as term:
            self.assertEqual(qe.sweep_orphan_model_hosts(), 0)
        term.assert_not_called()

    def test_sweep_kills_nothing_when_the_process_table_is_unreadable(self) -> None:
        with mock.patch.object(qe, "_endpoint_up", return_value=False), \
                mock.patch.object(qe, "_snapshot_processes", return_value=None), \
                mock.patch.object(qe, "_terminate_tree") as term:
            self.assertEqual(qe.sweep_orphan_model_hosts(), 0)
        term.assert_not_called()


class TestMachineWideKillIsOptIn(unittest.TestCase):
    def test_no_kill_without_the_opt_in(self) -> None:
        # The default must never reach the OS: the daemon on the port may belong
        # to another client, and killing it caused the original 37 GB incident.
        with mock.patch.dict(qe.os.environ, {}, clear=False), \
                mock.patch.object(qe.subprocess, "run") as run:
            qe.os.environ.pop("SAROPA_QWEN_ALLOW_GLOBAL_KILL", None)
            self.assertFalse(qe._kill_all_ollama())
        run.assert_not_called()

    def test_ambiguous_flag_values_read_as_no(self) -> None:
        for value in ("", "0", "false", "maybe"):
            with self.subTest(value=value):
                with mock.patch.dict(
                    qe.os.environ, {"SAROPA_QWEN_ALLOW_GLOBAL_KILL": value}
                ):
                    self.assertFalse(qe._env_flag("SAROPA_QWEN_ALLOW_GLOBAL_KILL"))


class TestPreflight(unittest.TestCase):
    def test_refuses_to_start_and_reports_memory(self) -> None:
        with mock.patch.dict(qe.os.environ, {}, clear=False), \
                mock.patch.object(qe, "_snapshot_processes",
                                  return_value=TestOrphanDetection.SNAPSHOT):
            qe.os.environ.pop("SAROPA_QWEN_REAP_ORPHANS", None)
            ok, detail = qe.preflight_orphan_check()
        self.assertFalse(ok)
        self.assertIn("15.8 GB", detail)
        self.assertIn("SAROPA_QWEN_REAP_ORPHANS", detail)

    def test_clean_machine_passes(self) -> None:
        with mock.patch.object(qe, "_snapshot_processes", return_value=[]):
            ok, _ = qe.preflight_orphan_check()
        self.assertTrue(ok)

    def test_unreadable_process_table_does_not_block_a_run(self) -> None:
        with mock.patch.object(qe, "_snapshot_processes", return_value=None):
            ok, detail = qe.preflight_orphan_check()
        self.assertTrue(ok)
        self.assertIn("skipped", detail)

    def test_opt_in_reaps_and_proceeds(self) -> None:
        # Snapshot is taken three times here: detect, sweep, re-check.
        snaps = iter([TestOrphanDetection.SNAPSHOT,
                      TestOrphanDetection.SNAPSHOT, []])
        with mock.patch.dict(qe.os.environ, {"SAROPA_QWEN_REAP_ORPHANS": "1"}), \
                mock.patch.object(qe, "_snapshot_processes",
                                  side_effect=lambda: next(snaps)), \
                mock.patch.object(qe, "_endpoint_up", return_value=False), \
                mock.patch.object(qe, "_terminate_tree", return_value=True) as term:
            ok, detail = qe.preflight_orphan_check()
        self.assertTrue(ok)
        self.assertEqual([c.args[0] for c in term.call_args_list], [102])
        self.assertIn("reaped 1", detail)


class TestShutdownOwnership(unittest.TestCase):
    """Teardown may only touch a daemon THIS run started."""

    def setUp(self) -> None:
        self._saved = qe._daemon_pid

    def tearDown(self) -> None:
        qe._daemon_pid = self._saved

    def test_never_touches_a_daemon_we_did_not_start(self) -> None:
        qe._daemon_pid = None
        with mock.patch.object(qe, "_terminate_tree") as term, \
                mock.patch.object(qe, "unload_model") as unload, \
                mock.patch.object(qe, "sweep_orphan_model_hosts") as sweep:
            qe.shutdown_engine(log=lambda _m: None)
        term.assert_not_called()
        unload.assert_not_called()
        sweep.assert_not_called()

    def test_owned_daemon_is_unloaded_then_tree_killed_then_swept(self) -> None:
        qe._daemon_pid = 5150
        order: list[str] = []
        with mock.patch.object(qe, "unload_model",
                               side_effect=lambda **_k: order.append("unload")), \
                mock.patch.object(qe, "_terminate_tree",
                                  side_effect=lambda *_a, **_k: order.append("tree")), \
                mock.patch.object(qe, "sweep_orphan_model_hosts",
                                  side_effect=lambda **_k: order.append("sweep")):
            qe.shutdown_engine(log=lambda _m: None)
        # Unload first frees the memory gracefully; the sweep last is the
        # backstop for a host the tree kill somehow missed.
        self.assertEqual(order, ["unload", "tree", "sweep"])

    def test_second_teardown_is_a_no_op(self) -> None:
        # atexit plus an explicit call must not kill a recycled PID twice.
        qe._daemon_pid = 6000
        with mock.patch.object(qe, "unload_model"), \
                mock.patch.object(qe, "_terminate_tree"), \
                mock.patch.object(qe, "sweep_orphan_model_hosts"):
            qe.shutdown_engine(log=lambda _m: None)
        with mock.patch.object(qe, "_terminate_tree") as term:
            qe.shutdown_engine(log=lambda _m: None)
        term.assert_not_called()


class TestKeepAlive(unittest.TestCase):
    def test_default_is_not_the_thirty_minute_residency(self) -> None:
        with mock.patch.dict(qe.os.environ, {}, clear=False):
            qe.os.environ.pop("SAROPA_QWEN_KEEP_ALIVE", None)
            self.assertEqual(qe._keep_alive(), "5m")

    def test_override_honored(self) -> None:
        with mock.patch.dict(qe.os.environ, {"SAROPA_QWEN_KEEP_ALIVE": "30s"}):
            self.assertEqual(qe._keep_alive(), "30s")


class TestSnapshotParsing(unittest.TestCase):
    def test_posix_ps_output_parsed_including_names_with_spaces(self) -> None:
        out = mock.Mock(returncode=0, stdout=(
            "  100     1  204800 ollama\n"
            "  101   100 9961472 llama-server\n"
            "bad line\n"
        ))
        with mock.patch.object(qe.subprocess, "run", return_value=out):
            procs = qe._snapshot_processes_posix()
        self.assertEqual([p.pid for p in procs], [100, 101])
        self.assertEqual(procs[1].commit_bytes, 9961472 * 1024)

    def test_windows_single_row_json_object_is_normalized_to_a_list(self) -> None:
        # ConvertTo-Json emits a bare object for a single match; treating that as
        # a dict of columns would silently drop the only orphan on the machine.
        out = mock.Mock(returncode=0, stdout=(
            '{"ProcessId":42,"ParentProcessId":7,'
            '"Name":"llama-server.exe","PageFileUsage":1048576}'
        ))
        with mock.patch.object(qe.shutil, "which", return_value="powershell.exe"), \
                mock.patch.object(qe.subprocess, "run", return_value=out):
            procs = qe._snapshot_processes_windows()
        self.assertEqual(len(procs), 1)
        self.assertEqual(procs[0].commit_bytes, 1048576 * 1024)


if __name__ == "__main__":
    unittest.main(verbosity=2)
