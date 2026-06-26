"""Regression tests for the VS Code Marketplace stored-credential fallback.

Run from repository root::

    python -m unittest discover -s scripts/modules/tests -t . -v

Pins the fix for the 14.2.2 Marketplace miss (2026-06-25): the publish script
gated the Marketplace step on the ``VSCE_PAT`` environment variable and skipped
when it was empty, even though vsce held a valid stored ``vsce login``
credential for the publisher (Microsoft Entra browser login — vsce 3.x needs no
PAT). The result was a silent skip — pub.dev, Open VSX, the git tag, and the
GitHub release all advanced to 14.2.2 while the Marketplace stayed on 14.2.1.

The decisive property: with no ``VSCE_PAT`` set but a stored login present, the
function must ATTEMPT the publish (call ``vsce publish``), not skip. The sibling
saropa_workspace publish script, which calls ``vsce publish`` directly, already
publishes that way; this test pins the lints script to the same behavior.
"""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

# The module under test prints status glyphs (e.g. the info "i" U+2139) via
# print_info/print_error. publish.py reconfigures stdout to UTF-8 at startup;
# `python -m unittest` does not, so on a Windows cp1252 console those prints
# raise UnicodeEncodeError. Reconfigure here so the tests exercise real logic
# instead of failing on console encoding.
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8")  # type: ignore[attr-defined]
    except (AttributeError, OSError):
        pass


def _completed(returncode: int) -> subprocess.CompletedProcess:
    """Minimal CompletedProcess stand-in for a mocked run_command result."""
    return subprocess.CompletedProcess(args=[], returncode=returncode, stdout="", stderr="")


class TestReadExtensionPublisher(unittest.TestCase):
    """Pin publisher extraction from extension/package.json."""

    def setUp(self) -> None:
        from scripts.modules._extension_publish import _read_extension_publisher

        self._fn = _read_extension_publisher
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        (self.root / "extension").mkdir()

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def _write_pkg(self, payload: dict | str) -> None:
        body = payload if isinstance(payload, str) else json.dumps(payload)
        (self.root / "extension" / "package.json").write_text(body, encoding="utf-8")

    def test_reads_publisher_field(self) -> None:
        self._write_pkg({"name": "saropa-lints", "publisher": "saropa"})
        self.assertEqual(self._fn(self.root), "saropa")

    def test_missing_file_returns_empty(self) -> None:
        # No package.json -> empty string, never a crash (publish must degrade,
        # not throw, when the manifest is absent).
        self.assertEqual(self._fn(self.root), "")

    def test_malformed_json_returns_empty(self) -> None:
        self._write_pkg("{ not valid json")
        self.assertEqual(self._fn(self.root), "")

    def test_missing_publisher_key_returns_empty(self) -> None:
        self._write_pkg({"name": "saropa-lints"})
        self.assertEqual(self._fn(self.root), "")


class TestMarketplacePublishFallback(unittest.TestCase):
    """Pin: no VSCE_PAT but a stored login -> publish is attempted, not skipped."""

    def setUp(self) -> None:
        import scripts.modules._extension_publish as mod

        self._mod = mod
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        (self.root / "extension").mkdir()
        (self.root / "extension" / "package.json").write_text(
            json.dumps({"name": "saropa-lints", "publisher": "saropa"}),
            encoding="utf-8",
        )
        self.vsix = self.root / "extension" / "saropa-lints-9.9.9.vsix"
        self.vsix.write_text("", encoding="utf-8")

    def tearDown(self) -> None:
        self._tmp.cleanup()

    @staticmethod
    def _is_publish_cmd(cmd: list[str]) -> bool:
        return "publish" in cmd and "verify-pat" not in cmd

    @staticmethod
    def _is_verify_cmd(cmd: list[str]) -> bool:
        return "verify-pat" in cmd

    def test_logged_in_without_env_var_attempts_publish(self) -> None:
        # The regression: env var absent, stored login valid -> must call
        # `vsce publish`. The old code returned early ("Skipping") here.
        calls: list[list[str]] = []

        def fake_run(cmd, *args, **kwargs):
            calls.append(cmd)
            # verify-pat succeeds (logged in); publish succeeds.
            return _completed(0)

        with mock.patch.dict(self._mod.os.environ, {}, clear=False) as _env:
            self._mod.os.environ.pop("VSCE_PAT", None)
            with mock.patch.object(self._mod, "run_command", side_effect=fake_run):
                # If this path ever reached the PAT prompt, the test would hang
                # on input(); patch it to prove it is NOT consulted.
                with mock.patch.object(
                    self._mod, "_prompt_for_vsce_pat", return_value=""
                ) as prompt:
                    ok = self._mod.publish_extension_to_marketplace(self.root, self.vsix)

        self.assertTrue(ok)
        self.assertFalse(prompt.called, "stored login must skip the PAT prompt")
        self.assertTrue(
            any(self._is_publish_cmd(c) for c in calls),
            msg="a `vsce publish` command must be issued, not skipped",
        )

    def test_no_env_var_and_no_login_and_no_pat_skips(self) -> None:
        # Genuinely unauthenticated and the user declines the prompt -> skip
        # (return True) without ever issuing a publish command.
        calls: list[list[str]] = []

        def fake_run(cmd, *args, **kwargs):
            calls.append(cmd)
            # verify-pat fails (not logged in).
            return _completed(1)

        with mock.patch.dict(self._mod.os.environ, {}, clear=False):
            self._mod.os.environ.pop("VSCE_PAT", None)
            with mock.patch.object(self._mod, "run_command", side_effect=fake_run):
                with mock.patch.object(
                    self._mod, "_prompt_for_vsce_pat", return_value=""
                ):
                    ok = self._mod.publish_extension_to_marketplace(self.root, self.vsix)

        self.assertTrue(ok)
        self.assertFalse(
            any(self._is_publish_cmd(c) for c in calls),
            msg="with no auth and a declined prompt, publish must not run",
        )


if __name__ == "__main__":
    unittest.main()
