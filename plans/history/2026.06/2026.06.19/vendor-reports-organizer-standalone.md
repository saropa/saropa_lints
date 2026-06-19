# Vendor the reports organizer so it runs standalone

The `reports/organize_reports.py` launcher imported its move/prune logic only
from the contacts repo (`../contacts/scripts/.shared/reports_organizer.py`), so
it aborted with an error on any checkout that did not have the contacts repo
cloned as a sibling. The organizer logic is now vendored into this project and
the launcher loads the local copy first.

## Finish Report (2026-06-19)

### Scope
Docs/scripts only (Scope C). Two Python files; no Dart, analyzer, or extension
TypeScript touched.

### Defect
`reports/organize_reports.py` resolved its shared module exclusively at
`<repo-parent>/contacts/scripts/.shared/reports_organizer.py`. When the contacts
repo was not present alongside saropa_lints, `_load_shared_organizer` printed
"Shared organizer not found" and exited 1. The script could not organize reports
without an unrelated sibling repository on disk.

### Change
1. Added `scripts/.shared/reports_organizer.py` — a verbatim vendor of the
   contacts organizer (date parsing, move logic, active-write quiet window,
   progress bar, daily activity log, deepest-first empty-dir prune). The module
   header notes it is vendored and must stay in sync with the contacts source of
   truth.
2. Reworked the launcher's loader to search a candidate tuple: the vendored
   module first, the contacts copy second. The first existing path is loaded;
   when neither exists the error message lists both searched paths. This keeps
   the script self-contained while preserving the original cross-repo fallback
   for a stripped checkout that loses the vendored file.

### Behavior preserved
`reports/` remains gitignored output with the launcher whitelisted
(`!reports/organize_reports.py`); `reports/` and `scripts/` are pubignored, so
neither file ships to pub.dev consumers. The `_cache/` skip, hidden-dotfile
skip, already-organized detection, and active-write quiet window are unchanged
from the shared implementation.

### Verification
- `python -m py_compile` on both files: clean.
- Live run `python reports/organize_reports.py`: moved 57 loose report files
  into `YYYY.MM/YYYY.MM.DD/` folders, skipped 22,101 (already-organized, hidden
  `_cache`/`.batches`/`.trash`/`.saropa_lints`, and the launcher itself), and
  pruned 5 empty folders. The summary line printed and the daily activity log
  was written.

### Known cosmetic limitation
The progress bar redraws one line per processed file. In a non-TTY context
(piped/captured output) it emits one line per file rather than overwriting in
place, producing large captured logs. This is inherited from the shared
implementation and was left unchanged; gating the per-file redraw on
`sys.stdout.isatty()` is a possible future cleanup.
