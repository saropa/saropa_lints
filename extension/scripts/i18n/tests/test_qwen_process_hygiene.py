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


def _liveness(dead: set[int] | None = None, unknown: set[int] | None = None):
    """Patch the single-PID probe so orphan confirmation never touches the OS.

    Orphan detection now requires a POSITIVE "this parent is gone" answer, so
    every test that expects an orphan has to name the PID that is confirmed
    dead. Anything unnamed reports alive, which is the safe default and matches
    what a real machine says about a parent that is still in the snapshot.
    """
    dead = dead or set()
    unknown = unknown or set()

    def probe(pid: int) -> bool | None:
        if pid in unknown:
            return None
        return False if pid in dead else True

    return mock.patch.object(qe, "_pid_liveness", side_effect=probe)


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
        with mock.patch.object(qe, "_snapshot_processes", return_value=self.SNAPSHOT), \
                _liveness(dead={999}):
            orphans = qe.find_orphan_model_hosts()
        self.assertEqual([p.pid for p in orphans], [102])

    def test_snapshot_failure_is_unknown_not_empty(self) -> None:
        # None must not collapse to "nothing to kill" — a caller that cannot see
        # the process table has no business terminating anything.
        with mock.patch.object(qe, "_snapshot_processes", return_value=None):
            self.assertIsNone(qe.find_orphan_model_hosts())

    def test_legacy_host_image_name_recognized(self) -> None:
        snap = [_proc(200, 4, "ollama.exe"), _proc(201, 555, "ollama_llama_server.exe")]
        with mock.patch.object(qe, "_snapshot_processes", return_value=snap), \
                _liveness(dead={555}):
            self.assertEqual([p.pid for p in qe.find_orphan_model_hosts()], [201])

    def test_description_reports_total_memory(self) -> None:
        text = qe._describe_orphans([_proc(1, 9, "llama-server.exe", 9.5),
                                     _proc(2, 9, "llama-server.exe", 15.8)])
        self.assertIn("25.3 GB", text)
        self.assertIn("PID 1", text)


class TestOrphanConfirmationCannotMisfire(unittest.TestCase):
    """The three directions in which orphan detection must never be wrong.

    Nobody has ever run this path against a real orphan, so its defensibility
    rests entirely on these cases. Each one is a way the OS can lie to us, and
    each must resolve toward leaving the process alone.
    """

    def test_reused_parent_pid_makes_a_dead_parent_look_alive_only(self) -> None:
        # PID reuse is the classic hazard. The dangerous direction would be a
        # recycled PID making a LIVE parent look dead, which would nominate a
        # serving daemon's model host for termination. It cannot happen: reuse
        # only ever puts a PID back INTO the live set, and both the snapshot
        # test and the confirmation probe read presence as "alive".
        snap = [
            _proc(500, 4, "code.exe"),  # PID 500 recycled by an unrelated app
            _proc(501, 500, "llama-server.exe", 12.0),  # host whose parent died
        ]
        with mock.patch.object(qe, "_snapshot_processes", return_value=snap), \
                _liveness():
            self.assertEqual(qe.find_orphan_model_hosts(), [])

    def test_a_host_whose_parent_is_alive_is_never_a_candidate(self) -> None:
        # PID 101's parent (100) is in the snapshot, so it must be excluded
        # before the probe is even consulted.
        with mock.patch.object(qe, "_snapshot_processes",
                               return_value=TestOrphanDetection.SNAPSHOT), \
                _liveness(dead={999}) as probe:
            orphans = qe.find_orphan_model_hosts()
        self.assertNotIn(101, [p.pid for p in orphans])
        # Only the nominated candidate's parent is probed; the live daemon's
        # child never reaches the probe at all.
        self.assertEqual([c.args[0] for c in probe.mock_calls if c.args], [999])

    def test_dropped_snapshot_row_cannot_promote_a_live_parent_to_orphan(self) -> None:
        # The real hazard behind this hardening: the Windows parser silently
        # skips any row it cannot parse, and `ps` output can be truncated. Here
        # the daemon's row is missing from the snapshot, so PID 101 LOOKS
        # parentless — but its parent is alive, and the probe says so.
        snap = [_proc(101, 100, "llama-server.exe", 9.5)]  # parent row dropped
        with mock.patch.object(qe, "_snapshot_processes", return_value=snap), \
                _liveness():
            self.assertEqual(qe.find_orphan_model_hosts(), [])

    def test_unknowable_parent_liveness_is_not_permission_to_kill(self) -> None:
        # A probe that could not answer (tasklist missing, syscall blocked) must
        # read as "leave it alone", never as "confirmed dead".
        snap = [_proc(601, 600, "llama-server.exe", 9.5)]
        with mock.patch.object(qe, "_snapshot_processes", return_value=snap), \
                _liveness(unknown={600}):
            self.assertEqual(qe.find_orphan_model_hosts(), [])

    def test_unreadable_parent_pid_field_is_not_permission_to_kill(self) -> None:
        # A Windows row whose ParentProcessId is null degrades to ppid 0. That
        # is an absence of information, not evidence of a dead parent.
        snap = [_proc(701, 0, "llama-server.exe", 9.5)]
        with mock.patch.object(qe, "_snapshot_processes", return_value=snap):
            self.assertEqual(qe.find_orphan_model_hosts(), [])

    def test_nonpositive_pids_are_never_probed_or_confirmed(self) -> None:
        # os.kill treats 0 and negatives as process-GROUP selectors, so they
        # must not reach the probe at all.
        for pid in (0, -1, -100):
            with self.subTest(pid=pid):
                self.assertIsNone(qe._pid_liveness(pid))
                self.assertFalse(qe._parent_confirmed_gone(pid))


class TestPidLivenessTriState(unittest.TestCase):
    """A failed liveness query must be "unknown", never "dead"."""

    def _win_probe(self, **run_kwargs):
        with mock.patch.object(qe.sys, "platform", "win32"), \
                mock.patch.object(qe.subprocess, "run", **run_kwargs):
            return qe._pid_liveness(4321)

    def test_tasklist_failure_is_unknown(self) -> None:
        # Non-zero exit means we learned nothing. Reading that as "gone" is what
        # would let a broken tool authorize killing a live daemon's child.
        self.assertIsNone(self._win_probe(
            return_value=mock.Mock(returncode=1, stdout="")))

    def test_tasklist_missing_or_timed_out_is_unknown(self) -> None:
        for exc in (FileNotFoundError(), OSError(),
                    qe.subprocess.TimeoutExpired("tasklist", 10)):
            with self.subTest(exc=type(exc).__name__):
                self.assertIsNone(self._win_probe(side_effect=exc))

    def test_no_matching_task_is_confirmed_gone(self) -> None:
        self.assertIs(self._win_probe(return_value=mock.Mock(
            returncode=0,
            stdout="INFO: No tasks are running which match the specified criteria.",
        )), False)

    def test_matching_csv_row_is_alive(self) -> None:
        self.assertIs(self._win_probe(return_value=mock.Mock(
            returncode=0,
            stdout='"llama-server.exe","4321","Console","1","9,961,472 K"',
        )), True)

    def test_digits_in_another_column_do_not_fake_a_match(self) -> None:
        # The old substring test would call PID 42 alive off the "1,242 K" in a
        # memory column. Matching the quoted PID field closes that.
        with mock.patch.object(qe.sys, "platform", "win32"), \
                mock.patch.object(qe.subprocess, "run", return_value=mock.Mock(
                    returncode=0,
                    stdout='"code.exe","9999","Console","1","1,242 K"')):
            self.assertIs(qe._pid_liveness(42), False)

    def test_posix_unexpected_oserror_is_unknown(self) -> None:
        with mock.patch.object(qe.sys, "platform", "linux"), \
                mock.patch.object(qe.os, "kill", side_effect=OSError):
            self.assertIsNone(qe._pid_liveness(4321))

    def test_posix_permission_error_means_alive(self) -> None:
        with mock.patch.object(qe.sys, "platform", "linux"), \
                mock.patch.object(qe.os, "kill", side_effect=PermissionError):
            self.assertIs(qe._pid_liveness(4321), True)

    def test_wait_loop_treats_unknown_as_still_running(self) -> None:
        # _pid_alive gates only how long we keep polling, so unknown must keep
        # us waiting rather than declare a kill successful without evidence.
        with mock.patch.object(qe, "_pid_liveness", return_value=None):
            self.assertTrue(qe._pid_alive(4321))


class TestPortConflictReusesForeignDaemon(unittest.TestCase):
    """A daemon we did not start is usable; it is just not ours to kill.

    Refusing the run outright whenever our own spawn lost the port punished an
    operator who simply already had `ollama serve` running. The run may use that
    daemon; the safety property is that it must never be adopted, because
    adoption is what authorizes teardown.
    """

    def setUp(self) -> None:
        self._saved = qe._daemon_pid
        qe._daemon_pid = None

    def tearDown(self) -> None:
        qe._daemon_pid = self._saved

    def _ensure_ready(self, *, our_proc_exited: bool, endpoint_after: bool):
        # Endpoint sequence: down at the first probe so the spawn is attempted,
        # then up once so the "did it come up?" wait loop exits immediately,
        # then whatever the scenario says for every probe after that. The
        # scripted third state is what distinguishes "somebody else owns the
        # port" from "nothing is serving at all".
        probes = iter([False, True])
        proc = mock.Mock()
        proc.pid = 31337
        proc.poll.return_value = 1 if our_proc_exited else None
        with mock.patch.object(qe.shutil, "which", return_value="ollama"), \
                mock.patch.object(qe, "preflight_orphan_check",
                                  return_value=(True, "clean")), \
                mock.patch.object(
                    qe, "_endpoint_up",
                    side_effect=lambda *_a, **_k: next(probes, endpoint_after)), \
                mock.patch.object(qe, "_has_model", return_value=True), \
                mock.patch.object(qe.time, "sleep"), \
                mock.patch.object(qe.subprocess, "Popen", return_value=proc), \
                mock.patch.object(qe, "restart_ollama",
                                  return_value=False) as restart:
            ok, detail = qe._ensure_ready()
        return ok, detail, restart

    def test_existing_daemon_on_the_port_is_used_not_refused(self) -> None:
        ok, detail, restart = self._ensure_ready(
            our_proc_exited=True, endpoint_after=True)
        self.assertTrue(ok, detail)
        # No restart attempt: there is nothing wrong to recover from.
        restart.assert_not_called()

    def test_a_daemon_we_did_not_start_is_never_adopted(self) -> None:
        # The safety property. An unadopted PID cannot be reached by
        # shutdown_engine, so the operator's daemon survives the run.
        self._ensure_ready(our_proc_exited=True, endpoint_after=True)
        self.assertIsNone(qe._daemon_pid)

    def test_our_own_daemon_is_still_adopted(self) -> None:
        with mock.patch.object(qe, "_adopt_daemon") as adopt:
            ok, detail, _ = self._ensure_ready(
                our_proc_exited=False, endpoint_after=True)
        self.assertTrue(ok, detail)
        self.assertEqual(adopt.call_args.args, (31337,))

    def test_dead_spawn_with_a_dead_port_still_restarts(self) -> None:
        # The narrowing must not swallow the genuine failure case: nothing is
        # serving and our spawn died, so the restart path must still run.
        ok, _detail, restart = self._ensure_ready(
            our_proc_exited=True, endpoint_after=False)
        self.assertFalse(ok)
        restart.assert_called_once()


class TestSweepSafety(unittest.TestCase):
    def test_sweep_terminates_only_the_orphan(self) -> None:
        with mock.patch.object(qe, "_endpoint_up", return_value=False), \
                mock.patch.object(qe, "_snapshot_processes",
                                  return_value=TestOrphanDetection.SNAPSHOT), \
                _liveness(dead={999}), \
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
                                  return_value=TestOrphanDetection.SNAPSHOT), \
                _liveness(dead={999}):
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
                _liveness(dead={999}), \
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
