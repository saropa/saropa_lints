# Extension i18n translation tooling: free-threaded interpreter fix, menu polish, manual gap closure

An audit of the VS Code extension's locale catalogs reported three strings that
the machine-translation pass had returned unchanged from English: the Filipino
`Cross-project drift` drift label, the Indonesian `info` severity word, and the
Russian startup-nudge error toast `reviewFailed`. Closing those gaps by re-running
the translation pipeline surfaced two separate defects in the pipeline's launcher:
on this machine the `py -3` launcher now resolves to the free-threaded CPython
build (`python3.14t.exe`), which cannot load the shared NLLB runtime, and the
interactive mode menu rendered as a crushed block of text with no spacing.

## Scope

(B) VS Code extension — i18n locale catalogs (`extension/src/i18n/locales/`) and
the translation tooling under `extension/scripts/`. No Dart lint rules, analyzer
plugin code, or tiers touched.

## Section 3 — Deep Review

**Logic & Safety.** The free-threaded guard in `generate_translations.py` re-launches
under a sibling standard interpreter via a blocking `subprocess.run`, not `os.execv`.
On Windows `os.execv` does not replace the process in place: it spawns a new process
and the parent exits immediately, so the shell reclaims the console and prints its
prompt while the relaunched child is still reading stdin and writing stdout. That
interleaving corrupted the interactive menu (a typed `1` landed in a half-returned
prompt). The blocking subprocess keeps exactly one process attached to the console,
matching the pattern `main()` already uses to launch the child `generate_locales.py`.
A re-launch loop is prevented by requiring the resolved standard `python.exe` to be
a distinct path from the current interpreter; SIGINT is ignored in the relauncher so
Ctrl-C is owned by the child chain.

**Architecture & Adherence.** The audit-first behavior reuses the existing
`_run_audit` function rather than adding a parallel reporting path; the source-string
collection and MT-cache load were hoisted above the menu so the pre-menu audit and
the translation run share a single read instead of loading twice. The pre-menu audit
is gated to `args.mode is None and sys.stdin.isatty()`, so CI and explicit `--mode`
invocations (including the publish coverage gate) are unaffected.

**Performance.** The pre-menu audit makes zero network calls (it reads the curated
dictionaries and existing cache only), so the added interactive step is read-only and
bounded by locale count, not translation latency.

**Documentation Quality.** Each non-obvious change carries a comment naming the
failure it prevents: the `os.execv`-vs-`subprocess` console-sharing trap, the
relaunch-loop guard, and the reason the menu gained blank lines.

**Refactoring.** No out-of-scope cleanup was performed.

## Section 4 — Testing Validation

**A. Existing-test audit.** A grep of `extension/scripts/i18n/tests/` for the changed
symbols (`_choose_mode`, `_run_audit`, `Choose [`, `Translation mode`, `default 1`,
`_reexec`, `main(`) found no test pinning the menu text, the mode resolver, or the
relaunch guard. The two test modules that import `generate_locales` —
`test_progress.py` (progress-bar geometry) and `test_report_path.py` (timestamped
report path) — assert behavior unrelated to the menu and main()-ordering changes.

**Run.** Both were executed under the standard interpreter:
`python tests/test_progress.py` → 6 tests OK; `python tests/test_report_path.py` →
2 tests OK. No regressions.

**B. New behavior.** The reordered `main()` was exercised end to end via the read-only
audit path (`generate_locales.py --mode audit --locales de`), which ran to completion,
wrote a report, and exited cleanly — confirming the hoisted source/cache load does not
crash. The interactive menu spacing and Enter-default are not covered by an automated
test because they require a TTY; they were verified by inspection and a compile check.

## Section 5 — Extension l10n Validation

**A. String audit.** The three locale catalog values added are translations of
existing keys, not new user-facing literals. The Russian value preserves the `{error}`
placeholder and leaves the `Saropa Lints` brand untranslated, per the brand
no-translate rule. Curated entries mirroring the three translations were added to
`extension/scripts/i18n/dictionaries.py` so a future regeneration reproduces them
rather than reverting to English.

**B. Catalog regeneration.** No `en.json` key was added, renamed, or removed by this
work, so the source catalog signature is unchanged and a full regeneration is not
required for these three strings. The translated catalogs were hand-filled precisely
to close the gap without running the machine-translation pipeline.

**C. Coverage gate.** For the three targeted strings the locale catalogs now differ
from English, closing those specific gaps. (A later audit shows unrelated new gaps in
`de` and other locales introduced by separate en.json additions from another
workstream; those are outside this task's scope.)

## Section 6 — Project Maintenance & Tracking

- CHANGELOG.md: three Maintenance entries added (manual gap closure; free-threaded
  relaunch guard; interactive-menu audit-first/spacing/default).
- README verified — no rule or doc counts changed.
- pubspec / pubspec.lock — not touched (no release or dependency change).
- Roadmap — no lint entries affected.
- guides reviewed — no user-facing product behavior changed.
- No bug archive — task did not close a `bugs/*.md` file.

## Section 9 — Files changed

Already committed in `4e2aa305` (bundled by a concurrent commit):
- `extension/src/i18n/locales/fil.json` — `drift` value translated.
- `extension/src/i18n/locales/id.json` — `wordInfo` value translated.
- `extension/src/i18n/locales/ru.json` — `startupNudge.reviewFailed` value translated.
- `extension/scripts/i18n/dictionaries.py` — three curated entries (fil/id/ru).
- `extension/scripts/generate_translations.py` — free-threaded relaunch guard via
  blocking subprocess.
- `extension/scripts/i18n/generate_locales.py` — pre-menu read-only audit; menu
  spacing; explicit Enter-default of `1`.
- `CHANGELOG.md` — Maintenance entries.

Outstanding: none for this task.
