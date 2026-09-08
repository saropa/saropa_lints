# PROPOSAL: Extension-native diagnostic for open-work docs filed in a closed/archive location

**Status: In Progress**

Created: 2026-09-07
Type: Infrastructure (extension-native diagnostic)
Related rules: none (new extension-native diagnostic, not a Dart AST rule)

---

## Summary

Add an extension-native diagnostic (TypeScript, `extension/src/`) that flags
a markdown file written into a workspace's configured "closed/archive"
directory whose own content still reads as open, unresolved work — an
unchecked severity marker, an open status field, an unaddressed
action-items section — and suggests moving it to the workspace's configured
"open issues" directory instead.

This is a generic doc-hygiene check, not tied to any one project's folder
naming. Both the archive path and the open-issues path are workspace
settings with sensible defaults; the signal patterns that mean "still open"
are also configurable, since different teams use different status
vocabularies.

---

## Motivation

Many teams (and, increasingly, AI agents writing docs on their behalf)
maintain a two-bin convention: an "open/actionable" directory for work not
yet done, and a "history/archive" directory for closed, completed work.
The convention is usually documented somewhere, but nothing enforces it —
a document with real unresolved findings can be written straight into the
archive path by habit (it looks like a dated report, so it "feels" like it
belongs in history), and once it's there, no triage workflow re-scans an
archive directory for open action items. The findings are then effectively
lost until a human happens to re-read old history and notices.

This is a workspace-convention problem, not a code-correctness problem —
detecting it requires reading arbitrary markdown content plus knowing which
directory a file landed in, neither of which the Dart AST engine can see
(per the "Rule Sources: Dart AST vs Extension-Native" section of this
guide). It is a clean fit for the extension-native engine: full workspace
file access, arbitrary file type, path/directory awareness, and it already
has a home in the shared Problems-panel/report surfacing model documented
here for other non-Dart diagnostics (e.g. `l10nDiagnostics.ts`).

This is the mirror image of the check already shipped in
`extension/src/extensionChecks/bugArchivalCheck.ts` (flags a `bugs/*.md`
report whose `Status:` line says it's done but the file hasn't been moved
to `plans/history/`). That check is the closer prior art for
implementation — same per-check `DiagnosticCollection`, same
save/open-triggered scan, same `Status:` line regex — and this proposal
should follow its pattern rather than the more general `l10nDiagnostics.ts`
one.

---

## Detection / Behavior

Fire only on markdown files whose path matches a configurable "archive"
glob (default `**/docs/history/**/*.md`, since that's a common convention,
but fully overridable per workspace — some repos use `docs/archive/`,
`changelog/done/`, etc., via
`saropaLints.docPlacement.archiveGlob`).

Scan the file's own text for configurable "still open" signals — shipped
defaults, each independently toggleable via
`saropaLints.docPlacement.openSignals`:

- A structural status field showing an open state (e.g. `Status: Open`,
  `**Status: Open**` — matched as a field, not a bare substring)
- A structural severity field or table cell showing an unresolved severity
  (e.g. `Severity: Critical`, `| Critical |`)
- An unresolved action-items heading (e.g. `## Recommended next steps`,
  `## Work still to do`, `## TODO`, `## Open items`)

If any enabled signal is present AND no configurable "closed" signal
overrides it (e.g. `Status: Fixed`, `Status: Closed`, `Status: Done`
anywhere in the file — teams often update just the status line in place
rather than rewriting an entire findings table), emit a diagnostic on line 1
(the defect is the file's *location*, not any single line of body content)
through the existing shared `vscode.DiagnosticCollection`, so it appears in
the Problems panel and web report alongside every other diagnostic source.

### Should flag (open work in the archive path)

```markdown
<!-- File matches the configured archive glob -->
# Report Title

Severity: Critical
...
## Recommended next steps
1. Fix the thing.
```

### Should pass (same content, filed under the configured open-issues path)

```markdown
<!-- File matches the configured open-issues glob instead -->
# Report Title

Severity: Critical
...
## Recommended next steps
1. Fix the thing.
```

### Should pass (archive path, but a closed-signal overrides the stale open marker)

```markdown
<!-- File matches the configured archive glob -->
# Report Title

Status: Fixed
...
No open findings remain — all items resolved and verified.
```

---

## Proposed Tier

N/A — extension-native diagnostics sit outside the Dart-rule tier system
(Essential/Recommended/Professional/Comprehensive/Pedantic). Suggest
treating it as always-on with a single enable/disable toggle
(`saropaLints.docPlacement.enabled`, default `true`), like other structural
workspace-hygiene checks, rather than gating it behind a tier meant for
code-style preferences.

---

## Edge Cases

1. **Workspace doesn't use a two-bin open/archive doc convention at all** — the archive glob simply never matches; zero false positives, zero configuration burden for repos that don't opt in.
2. **A closed report's prose happens to contain the word "Critical"** (e.g. "this used to be a Critical finding") — mitigated by requiring the open-signal match to sit in a recognizable structural position (a `Field:` line or a table cell), never a bare substring scan across free prose.
3. **A closed-signal is added in place without removing the stale open-signal elsewhere in the same file** — this should suppress the diagnostic (see Detection above); it's the common real-world pattern of updating one status line rather than rewriting a whole findings section, and over-firing on it would train users to ignore the diagnostic.
4. **Legitimate archival of a file that intentionally documents historical open items** (e.g. a retrospective listing findings that were deliberately never fixed) — needs discussion: possibly a per-file suppression comment (`<!-- saropa-lints-ignore doc-placement -->`) for the rare deliberate case, analogous to a Dart `// ignore:` comment.
5. **Any doc type, not just audits** — plans, postmortems, finish reports, investigation logs — should all be covered uniformly by the same signal set; the rule shouldn't special-case "audit" documents specifically.

---

## Alternatives Considered

- **Dart AST rule**: rejected — the Dart analyzer never resolves markdown files; structurally impossible for this engine (see "Rule Sources" section of this guide).
- **Per-project automation hook** (e.g. a CI check or a repo-local pre-commit/agent-harness hook that greps new files under the archive path): works, but must be hand-built and maintained separately in every repo that wants it, with no shared UI. An extension-native diagnostic fixes it once for every workspace with the extension installed, using the Problems panel/report surface teams already watch.

---

## Decision

Accepted. Implemented as `extension/src/extensionChecks/docPlacementCheck.ts`,
following the `bugArchivalCheck.ts` pattern (own `DiagnosticCollection`,
scan on open/save, no shared registry). Config surface, defaults, and
diagnostic message match the spec above, with two implementation notes:

- Glob matching is a small hand-rolled `globToRegExp` (`**`/`*` only), not
  `vscode.languages.match` or a `minimatch` dependency — see the
  Implementation Notes section above for why neither existing utility nor
  a new dependency was warranted.
- A `/code-review medium` pass caught two defects before ship, both fixed:
  the default `archiveGlob` shipped as `**/docs/history/**/*.md`, which
  does not match this repo's own `plans/history/YYYY.MM/YYYYMMDD/`
  convention (same target `bugArchivalCheck.ts` already archives to) — now
  defaults to `**/plans/history/**/*.md`; and the default `Status:`/
  `Severity:` regexes missed the `**Status:** Fixed` bold-label style this
  repo's own archived docs use (only `**Status: Fixed**` matched) — fixed
  by absorbing an optional `\*{0,2}` right after the field's colon.
- Unverified per `extension-verification.md`: typechecks and unit tests
  (22 passing in `docPlacementCheck.test.ts`) are green, but the new
  settings and the live Problems-panel diagnostic have not yet been seen
  in the Extension Development Host (F5). Needs: the 5 new
  `saropaLints.docPlacement.*` settings visible in the Settings UI, and
  the diagnostic firing/clearing correctly on a markdown file under
  `plans/history/` in both themes.

---

## Implementation Notes

- Likely home: a new `extension/src/extensionChecks/docPlacementCheck.ts`
  module, following the `bugArchivalCheck.ts` pattern directly (own
  `vscode.DiagnosticCollection`, `onDidSaveTextDocument` /
  `onDidOpenTextDocument`, scan already-open docs at activation).
- **Verified: no existing structural markdown parser to reuse.**
  `extension/src/markdownUtils.ts` only escapes/builds `vscode.MarkdownString`
  tooltip content — it has no heading/field/table parsing. The
  status/severity/heading field matching here needs the same kind of
  anchored regex `bugArchivalCheck.ts` already uses for its `Status:` line
  (`STATUS_LINE_PATTERN`), extended for severity fields and headings — not
  a shared utility that doesn't exist yet.
- **Verified: no existing glob-matching utility either.** `pathUtils.ts`
  only has `normalizePath` and a file-existence cache; `projectRoot.ts` only
  resolves the `pubspec.yaml` directory. There is no `minimatch`/`micromatch`
  dependency in `extension/package.json` and no glob-matching helper
  anywhere in `extension/src/`. Matching a document path against
  `archiveGlob`/`openIssuesGlob` config values needs either a new small
  glob-to-regex helper or a new dependency — budget for that, don't assume
  it's a one-line reuse.
- Config surface (all via the existing `config/` module):
  - `saropaLints.docPlacement.enabled` (default `true`)
  - `saropaLints.docPlacement.archiveGlob` (default `**/docs/history/**/*.md`)
  - `saropaLints.docPlacement.openSignals` (default list of status/severity/
    heading patterns, user-extensible)
  - `saropaLints.docPlacement.closedSignals` (default list of overriding
    "this is actually done" patterns)

---

## Commits

<!-- Add commit hashes as implementation lands -->
