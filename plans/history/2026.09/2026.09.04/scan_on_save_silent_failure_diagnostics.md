# Scan-on-save silent failure diagnostics

The scan-on-save pipeline had 7 gates that silently dropped diagnostics with zero
user feedback. When any gate fired (disabled setting, missing project root, file
outside project, daemon backoff, scan error, all severity filters off), the
extension produced no squiggles, no Problems tab entries, no status bar update,
and no output channel log — the extension appeared completely dead.

## Finish Report (2026-09-04)

### Problem

`ScanOnSaveController._onSave()` contained four early-return gates (disabled,
non-Dart language, no project root, file outside root) that exited with `return`
and zero side effects. The status bar item was only shown during and after a
successful scan — never on activation and never on a failed gate. The output
channel received no log entries from the scan-on-save pipeline at all.

### Root cause

The controller was designed as a "fire on save, publish results" pipeline with
no observability built in. Every gate assumed the user would eventually trigger a
successful scan and see results. When a gate permanently blocked (e.g. cached
`undefined` project root for the session), the extension was indistinguishable
from a broken install.

### Changes

**`scanOnSaveController.ts`:**
- Constructor now accepts an optional `OutputChannel` parameter for structured
  logging.
- New `_showInitialState()` runs in the constructor to surface the pipeline
  state (ready / disabled / no Dart project) immediately on activation, before
  any save event.
- New `_log()` method writes `[scan-on-save]` prefixed lines to the shared
  "Saropa Lints" output channel.
- `_onSave()`: language check moved before the enabled check (non-Dart saves
  exit silently; only Dart saves log "disabled" or "no project root"). Each
  gate that previously did a bare `return` now logs the file path and reason.
  The "no project" gate also updates the status bar.
- `_scan()`: logs tier/resolveTypes/daemon state before scanning. Logs full
  error details on failure (persists after the transient warning toast
  auto-dismisses). Logs raw vs. published finding counts on success.
- Status bar tooltip set on success (localized `doneTooltip`) and failure
  (error message).
- Settings-change handler: the disabled branch calls `_showInitialState()`
  instead of duplicating the text/tooltip/show triplet.

**`extension.ts`:**
- Passes `getSharedOutputChannel()` as the third constructor argument.
- Registers `saropaLints.scanOnSave.diagnose` command wired to the
  controller's `diagnose()` method.
- Adds a `pubspec.yaml` file watcher that calls `invalidateProjectRoot()`
  on creation — fixes the race where activation runs before the filesystem
  settles and the "no Dart project" cache verdict locks for the session.

**`scanDaemonManager.ts`:**
- Added `isAlive` and `isInBackoff` getters so the diagnose command can
  report accurate daemon state (previously only `isWarming` was exposed,
  which is false both when alive-and-warm AND when not-spawned-at-all).

**`en.json`:**
- Added keys: `scanOnSave.statusBar.ready`, `.disabled`, `.noProject`,
  `.doneTooltip`.

### Diagnose command

Clicking the status bar item runs `saropaLints.scanOnSave.diagnose`, which
dumps the full pipeline state to the "Saropa Lints" output channel and
reveals it. Covers: enabled, project root, daemon state (not spawned /
warming / alive / backoff / suspended), scan-in-flight, severity filters,
tier, resolveTypes, baseline state, pending files, cached results.

Accessible via the status bar click (UI surface). Not registered in
`package.json` contributes.commands (not a palette item — it's a
one-click diagnostic for "why is nothing happening?").

### Scan on open / activation (follow-up)

Diagnostics previously required a file save to trigger. The controller now
scans without saving:

- `_scanOpenEditors()`: on activation, iterates all already-open
  `TextDocument`s, queues every in-project Dart file, and fires a single
  debounced scan. Users see squiggles as soon as the extension loads.
- `onDidOpenTextDocument` listener: queues newly opened Dart files via the
  same `_queueIfDart()` helper, so switching to or opening a file produces
  diagnostics without saving.
- Both paths share the existing debounce timer and `_pendingFiles` set, so
  rapid opens coalesce into one scan invocation.

### What this does NOT fix

- Pre-existing i18n gaps in `sectionedSidebar.ts` hardcoded strings and
  `stale-ignore-commands.ts` duplication are out of scope (separate UI
  redesign work in those dirty files).
