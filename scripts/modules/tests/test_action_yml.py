"""Tests for the bash inside the composite action (``action.yml``).

Run from repository root::

    python -m unittest discover -s scripts/modules/tests -t . -v

``action-selftest.yml`` exercises the action on a real runner, but it only
runs when CI does. These tests pull each step's ``run:`` script out of
``action.yml`` and execute it locally, the way GitHub does
(``bash --noprofile --norc -e -o pipefail``), with a fake ``dart`` on PATH
that records its arguments. They test the real text of the action, not a
copy of it, so an edit to ``action.yml`` is covered the moment it is made.

Standard library only: the block scalars are extracted by indentation
rather than with a YAML parser, which is enough for this file's regular
shape and fails loudly (``KeyError``) if a step is renamed.
"""

from __future__ import annotations

import os
import re
import shutil
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
ACTION_YML = REPO_ROOT / "action.yml"

STEP_VALIDATE = "Validate inputs"
STEP_AUDIT = "Run saropa_lints audit"
STEP_EVALUATE = "Evaluate result"
STEP_FETCH = "Fetch base ref for --since"


def extract_run_scripts(text: str) -> dict[str, str]:
    """Maps each composite step's ``name`` to its ``run: |`` script."""
    scripts: dict[str, str] = {}
    lines = text.split("\n")
    name = None
    i = 0
    while i < len(lines):
        line = lines[i]
        if line.startswith("    - name: "):
            name = line[len("    - name: "):].strip()
        elif line == "      run: |" and name is not None:
            body = []
            i += 1
            while i < len(lines) and (lines[i].strip() == "" or lines[i].startswith("        ")):
                body.append(lines[i][8:])
                i += 1
            scripts[name] = "\n".join(body).rstrip() + "\n"
            continue
        i += 1
    return scripts


# Defaults mirror the `default:` of each input in action.yml.
INPUT_DEFAULTS = {
    "MODE": "annotate",
    "COMMAND": "auto",
    "INSTALL_SDK": "auto",
    "MIN_SEVERITY": "",
    "MIN_IMPACT": "",
    "MAX_SEVERITY": "",
    "TIER": "",
    "RESOLVE": "false",
    "FAIL_ON": "",
    "FAIL_ON_IMPACT": "",
    "FAIL_ON_COUNT": "",
    "FAIL_ON_IMPACT_COUNT": "",
    "FAIL_ON_TIER": "",
    "SINCE": "",
    "BASELINE": "",
    "EXCLUDE_GLOBS": "",
    "INCLUDE_GLOBS": "",
    "SARIF_FILE": "saropa-lints.sarif",
    "WORKING_DIRECTORY": ".",
}

FAKE_DART = """#!/bin/sh
# Records each argument on its own line, writes SARIF when asked, and exits
# with the code the test chose.
: > "$FAKE_DART_LOG"
out=''
prev=''
for a in "$@"; do
  printf '%s\\n' "$a" >> "$FAKE_DART_LOG"
  [ "$prev" = "--output" ] && out="$a"
  prev="$a"
done
if [ -n "$out" ] && [ -z "${FAKE_DART_NO_OUTPUT:-}" ]; then
  results=''
  n=0
  while [ "$n" -lt "${FAKE_SARIF_RESULTS:-0}" ]; do
    [ -n "$results" ] && results="$results,"
    results="$results{\\"ruleId\\":\\"r$n\\"}"
    n=$((n + 1))
  done
  printf '{"version":"2.1.0","runs":[{"results":[%s]}]}' "$results" > "$out"
fi
exit "${FAKE_DART_EXIT:-0}"
"""


class ActionHarness(unittest.TestCase):
    """A temp workspace holding a Dart project and a fake ``dart``."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.scripts = extract_run_scripts(ACTION_YML.read_text(encoding="utf-8"))

    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp(prefix="saropa-action-"))
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.workspace = self.tmp / "ws"
        self.workspace.mkdir()
        (self.workspace / "pubspec.yaml").write_text(
            "name: demo\n\ndev_dependencies:\n  saropa_lints: ^16.3.0\n",
            encoding="utf-8",
        )
        bin_dir = self.tmp / "bin"
        bin_dir.mkdir()
        dart = bin_dir / "dart"
        dart.write_text(FAKE_DART, encoding="utf-8")
        dart.chmod(dart.stat().st_mode | stat.S_IXUSR)
        self.path = f"{bin_dir}{os.pathsep}{os.environ.get('PATH', '')}"
        self.dart_log = self.tmp / "dart.log"
        self.output_file = self.tmp / "github_output"

    def run_step(self, step: str, **env: str) -> subprocess.CompletedProcess:
        script = self.tmp / "step.sh"
        script.write_text(self.scripts[step], encoding="utf-8")
        self.output_file.write_text("", encoding="utf-8")
        full_env = {
            "PATH": self.path,
            "HOME": str(self.tmp),
            "GITHUB_OUTPUT": str(self.output_file),
            "FAKE_DART_LOG": str(self.dart_log),
            **INPUT_DEFAULTS,
            **env,
        }
        return subprocess.run(
            ["bash", "--noprofile", "--norc", "-e", "-o", "pipefail", str(script)],
            cwd=self.workspace,
            env=full_env,
            capture_output=True,
            text=True,
            timeout=60,
        )

    def outputs(self) -> dict[str, str]:
        result = {}
        for line in self.output_file.read_text(encoding="utf-8").splitlines():
            key, _, value = line.partition("=")
            result[key] = value
        return result

    def dart_args(self) -> list[str]:
        return self.dart_log.read_text(encoding="utf-8").splitlines()


class TestExtraction(unittest.TestCase):
    def test_finds_the_steps_under_test(self) -> None:
        scripts = extract_run_scripts(ACTION_YML.read_text(encoding="utf-8"))
        for step in (STEP_VALIDATE, STEP_AUDIT, STEP_EVALUATE):
            self.assertIn(step, scripts)
            self.assertIn("set -", scripts[step])


class TestValidateInputs(ActionHarness):
    def assert_rejected(self, fragment: str, **env: str) -> None:
        result = self.run_step(STEP_VALIDATE, **env)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn(fragment, result.stdout)

    def test_accepts_the_defaults(self) -> None:
        result = self.run_step(STEP_VALIDATE)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_accepts_gate_with_scan_inputs(self) -> None:
        result = self.run_step(
            STEP_VALIDATE,
            MODE="gate",
            TIER="recommended",
            FAIL_ON_TIER="essential",
            FAIL_ON="warning",
            FAIL_ON_COUNT="3",
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_rejects_an_unknown_mode(self) -> None:
        self.assert_rejected("mode must be", MODE="loud")

    def test_rejects_scan_for_a_sarif_mode(self) -> None:
        self.assert_rejected("cannot produce SARIF", MODE="annotate", COMMAND="scan")

    def test_rejects_a_scan_only_input_under_audit(self) -> None:
        # Silently running every rule while the team believes its tier applies
        # is the failure this check exists to prevent.
        self.assert_rejected("only apply to command 'scan': tier", MODE="annotate", TIER="essential")

    def test_rejects_an_audit_only_input_under_scan(self) -> None:
        self.assert_rejected("only apply to command 'audit': since", MODE="gate", SINCE="origin/main")

    def test_rejects_an_unknown_tier(self) -> None:
        self.assert_rejected("tier must be", MODE="gate", TIER="strict")

    def test_rejects_a_non_numeric_count(self) -> None:
        self.assert_rejected(
            "fail-on-count must be a non-negative integer", MODE="gate", FAIL_ON="error", FAIL_ON_COUNT="-1"
        )

    def test_rejects_a_count_without_its_threshold(self) -> None:
        # scan only counts findings against --fail-on; alone it is a no-op.
        self.assert_rejected("fail-on-count needs fail-on", MODE="gate", FAIL_ON_COUNT="3")
        self.assert_rejected(
            "fail-on-impact-count needs fail-on-impact", MODE="gate", FAIL_ON_IMPACT_COUNT="3"
        )

    def test_rejects_a_resolve_value_that_would_be_ignored(self) -> None:
        self.assert_rejected("resolve must be true or false", MODE="gate", RESOLVE="True")

    def test_rejects_a_directory_without_pubspec(self) -> None:
        (self.workspace / "docs").mkdir()
        self.assert_rejected("not a Dart project", WORKING_DIRECTORY="docs")


class TestRunAudit(ActionHarness):
    def test_gate_resolves_to_scan_with_its_flags(self) -> None:
        result = self.run_step(
            STEP_AUDIT, MODE="gate", TIER="recommended", FAIL_ON_TIER="essential", RESOLVE="true"
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        args = self.dart_args()
        self.assertEqual(args[:3], ["run", "saropa_lints", "scan"])
        self.assertIn("--resolve", args)
        self.assertEqual(args[args.index("--tier") + 1], "recommended")
        self.assertEqual(args[args.index("--fail-on-tier") + 1], "essential")
        self.assertNotIn("--format", args)

    def test_annotate_writes_sarif_and_counts_findings(self) -> None:
        if shutil.which("jq") is None:
            self.skipTest("jq not installed")
        result = self.run_step(STEP_AUDIT, FAKE_DART_EXIT="1", FAKE_SARIF_RESULTS="3")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        args = self.dart_args()
        self.assertEqual(args[2], "audit")
        self.assertEqual(args[args.index("--format") + 1], "sarif")
        out = self.outputs()
        self.assertEqual(out["exit-code"], "1")
        self.assertEqual(out["findings"], "3")
        self.assertEqual(out["sarif-file"], "./saropa-lints.sarif")

    def test_captures_a_failing_exit_code_under_bash_e(self) -> None:
        # GitHub runs steps with -e. Without the step's `set +e`, exit 1 would
        # abort before the code is recorded and the SARIF upload would skip.
        for code in ("1", "2"):
            result = self.run_step(STEP_AUDIT, MODE="gate", FAKE_DART_EXIT=code)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(self.outputs()["exit-code"], code)

    def test_scan_gets_one_argument_per_glob_trimmed_and_unexpanded(self) -> None:
        # A file that `vendor/*` would match if the shell expanded it.
        (self.workspace / "vendor").mkdir()
        (self.workspace / "vendor" / "a.dart").write_text("", encoding="utf-8")
        result = self.run_step(STEP_AUDIT, MODE="gate", EXCLUDE_GLOBS="vendor/*, **/gen/** ,,")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        args = self.dart_args()
        at = args.index("--exclude-globs")
        self.assertEqual(args[at + 1 : at + 3], ["vendor/*", "**/gen/**"])
        self.assertEqual(len(args), at + 3)

    def test_audit_gets_one_comma_joined_glob_value(self) -> None:
        result = self.run_step(STEP_AUDIT, MODE="gate", COMMAND="audit", INCLUDE_GLOBS=" lib/** , test/**")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        args = self.dart_args()
        self.assertEqual(args[args.index("--include-globs") + 1], "lib/**,test/**")

    def test_a_multi_line_glob_list_keeps_every_line(self) -> None:
        result = self.run_step(STEP_AUDIT, MODE="gate", EXCLUDE_GLOBS="lib/gen/**\ntest/**\n")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        args = self.dart_args()
        at = args.index("--exclude-globs")
        self.assertEqual(args[at + 1 :], ["lib/gen/**", "test/**"])

    def test_a_stale_sarif_is_removed_before_the_run(self) -> None:
        # The CLI dies before writing (exit 2); last run's file must not be
        # reported, counted or uploaded as this run's results.
        (self.workspace / "saropa-lints.sarif").write_text('{"runs":[]}', encoding="utf-8")
        result = self.run_step(STEP_AUDIT, FAKE_DART_EXIT="2", FAKE_DART_NO_OUTPUT="1")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        out = self.outputs()
        self.assertEqual(out["exit-code"], "2")
        self.assertNotIn("sarif-file", out)
        self.assertEqual(out["findings"], "")

    def test_the_sarif_directory_is_created(self) -> None:
        result = self.run_step(STEP_AUDIT, SARIF_FILE="reports/lints.sarif")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue((self.workspace / "reports" / "lints.sarif").is_file())

    def test_a_glob_list_of_only_separators_adds_nothing(self) -> None:
        result = self.run_step(STEP_AUDIT, MODE="gate", EXCLUDE_GLOBS=" , ")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("--exclude-globs", self.dart_args())

    def test_audit_passes_since_and_baseline(self) -> None:
        result = self.run_step(
            STEP_AUDIT, MODE="gate", COMMAND="audit", SINCE="origin/main", BASELINE="baseline.json"
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        args = self.dart_args()
        self.assertEqual(args[args.index("--since") + 1], "origin/main")
        self.assertEqual(args[args.index("--baseline-path") + 1], "baseline.json")

    def test_an_absolute_sarif_file_is_not_prefixed(self) -> None:
        target = self.tmp / "out.sarif"
        result = self.run_step(STEP_AUDIT, SARIF_FILE=str(target))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.outputs()["sarif-file"], str(target))

    def test_fails_when_saropa_lints_is_not_a_dependency(self) -> None:
        (self.workspace / "pubspec.yaml").write_text("name: demo\n", encoding="utf-8")
        result = self.run_step(STEP_AUDIT)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("not a dependency", result.stdout)
        self.assertFalse(self.dart_log.exists(), "dart must not run")


def git(cwd: Path, *args: str) -> str:
    return subprocess.run(
        ["git", *args], cwd=cwd, check=True, capture_output=True, text=True
    ).stdout.strip()


class TestFetchSince(ActionHarness):
    """The fetch step, against a real remote and a shallow clone of it."""

    def setUp(self) -> None:
        super().setUp()
        seed = self.tmp / "seed"
        seed.mkdir()
        git(seed, "init", "-q", "--initial-branch=main")
        git(seed, "config", "user.email", "t@example.com")
        git(seed, "config", "user.name", "T")
        git(seed, "config", "commit.gpgsign", "false")
        for n in range(3):
            (seed / f"f{n}.dart").write_text(f"// {n}\n", encoding="utf-8")
            git(seed, "add", ".")
            git(seed, "commit", "-q", "-m", f"c{n}")
        self.base_sha = git(seed, "rev-parse", "HEAD~1")
        git(seed, "branch", "release/1.0", "HEAD~2")
        git(seed, "checkout", "-q", "-b", "feature")
        (seed / "f9.dart").write_text("// 9\n", encoding="utf-8")
        git(seed, "add", ".")
        git(seed, "commit", "-q", "-m", "feature")
        remote = self.tmp / "remote.git"
        git(self.tmp, "clone", "-q", "--bare", str(seed), str(remote))
        # GitHub serves reachable commits by SHA; a local bare repo must opt in.
        git(remote, "config", "uploadpack.allowReachableSHA1InWant", "true")
        # What actions/checkout leaves: one branch, depth 1, no other refs.
        shutil.rmtree(self.workspace)
        git(
            self.tmp, "clone", "-q", "--depth=1", "--single-branch", "--branch=feature",
            f"file://{remote}", str(self.workspace),
        )

    def fetch(self, since: str) -> subprocess.CompletedProcess:
        return self.run_step(STEP_FETCH, SINCE=since)

    def resolves(self, ref: str) -> bool:
        return subprocess.run(
            ["git", "rev-parse", "--verify", "--quiet", f"{ref}^{{commit}}"],
            cwd=self.workspace, capture_output=True,
        ).returncode == 0

    def test_remote_tracking_name(self) -> None:
        result = self.fetch("origin/main")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(self.resolves("origin/main"))

    def test_bare_branch_name(self) -> None:
        result = self.fetch("main")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(self.resolves("main"))

    def test_branch_name_containing_a_slash(self) -> None:
        result = self.fetch("release/1.0")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(self.resolves("release/1.0"))

    def test_commit_sha(self) -> None:
        self.assertFalse(self.resolves(self.base_sha))
        result = self.fetch(self.base_sha)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(self.resolves(self.base_sha))

    def test_another_remote_is_refused_by_name(self) -> None:
        git(self.workspace, "remote", "add", "upstream", "file:///nonexistent")
        result = self.fetch("upstream/main")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("only origin is fetched", result.stdout)

    def test_an_unresolvable_ref_fails_rather_than_auditing_nothing(self) -> None:
        result = self.fetch("origin/no-such-branch")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("does not resolve even after fetching", result.stdout)


class TestFlagsMatchTheParsers(unittest.TestCase):
    """Every flag the action passes must exist in the CLI that receives it.

    A rename in bin/audit.dart or scan_cli_args.dart would otherwise break
    every consumer's workflow with nothing failing in this repository.
    """

    SHARED = {"--min-severity", "--min-impact", "--exclude-globs", "--include-globs"}
    AUDIT_ONLY = {"--format", "--output", "--quiet", "--since", "--baseline", "--baseline-path"}
    SCAN_ONLY = {
        "--tier", "--resolve", "--max-severity", "--fail-on", "--fail-on-impact",
        "--fail-on-count", "--fail-on-impact-count", "--fail-on-tier",
    }

    @classmethod
    def setUpClass(cls) -> None:
        step = extract_run_scripts(ACTION_YML.read_text(encoding="utf-8"))[STEP_AUDIT]
        # Only the lines that build the argument list; messages mention
        # other commands' flags (`dart pub add --dev`).
        code = "\n".join(
            l for l in step.splitlines() if "args+=(" in l or l.lstrip().startswith("append_globs --")
        )
        cls.emitted = set(re.findall(r"(?<![\w-])(--[a-z][a-z-]+)", code))
        cls.audit_src = (REPO_ROOT / "bin" / "audit.dart").read_text(encoding="utf-8")
        cls.scan_src = (REPO_ROOT / "lib" / "src" / "scan" / "scan_cli_args.dart").read_text(encoding="utf-8")

    def test_every_emitted_flag_is_classified(self) -> None:
        # A new flag in action.yml must be added to one of the sets above,
        # which is what puts it under the parser checks below.
        self.assertEqual(self.emitted - (self.SHARED | self.AUDIT_ONLY | self.SCAN_ONLY), set())
        self.assertIn("--fail-on-tier", self.emitted)

    def test_audit_accepts_every_flag_it_is_given(self) -> None:
        for flag in sorted(self.SHARED | self.AUDIT_ONLY):
            with self.subTest(flag=flag):
                self.assertIn(f"'{flag}'", self.audit_src)

    def test_scan_accepts_every_flag_it_is_given(self) -> None:
        for flag in sorted(self.SHARED | self.SCAN_ONLY):
            with self.subTest(flag=flag):
                self.assertIn(f"'{flag}'", self.scan_src)


class TestEvaluateResult(ActionHarness):
    def evaluate(self, mode: str, code: str, findings: str = "") -> subprocess.CompletedProcess:
        return self.run_step(STEP_EVALUATE, MODE=mode, CODE=code, FINDINGS=findings)

    def test_clean_run_passes_in_every_mode(self) -> None:
        for mode in ("annotate", "gate", "both"):
            self.assertEqual(self.evaluate(mode, "0").returncode, 0, mode)

    def test_findings_fail_only_the_gating_modes(self) -> None:
        self.assertEqual(self.evaluate("annotate", "1", "4").returncode, 0)
        self.assertNotEqual(self.evaluate("gate", "1", "4").returncode, 0)
        self.assertNotEqual(self.evaluate("both", "1").returncode, 0)

    def test_exit_2_fails_every_mode(self) -> None:
        # Exit 2 means nothing was analysed; green would claim otherwise.
        for mode in ("annotate", "gate", "both"):
            self.assertNotEqual(self.evaluate(mode, "2").returncode, 0, mode)

    def test_a_missing_or_unexpected_code_fails(self) -> None:
        self.assertNotEqual(self.evaluate("annotate", "").returncode, 0)
        self.assertNotEqual(self.evaluate("annotate", "139").returncode, 0)


if __name__ == "__main__":
    unittest.main()
