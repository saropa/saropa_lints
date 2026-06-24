# Package Upgrade Opportunities — surfacing under-adopted dependency features

Objective summary: The Package Vibrancy subsystem could tell a user a dependency
was outdated, but never that a dependency they were *current* on had shipped
features the project had never adopted. This work adds a heuristic engine that
mines each dependency's changelog for adoptable features, cross-references them
against the symbols the project actually uses, and surfaces the result through a
dedicated "Upgrade Opportunities" dashboard, a sortable table column, a toolbar
sweep, a per-package AI prompt, and a sidebar badge.

## Finish Report (2026-06-24)

### Scope
VS Code extension (TypeScript) only — `extension/src/vibrancy/**` and
`extension/src/views/sectionedSidebar.ts`. No Dart lint-rule, analyzer, or
`tiers.dart` code touched.

### Problem
"Up-to-date" in the Package Dashboard meant only that a version constraint was
satisfied. A caret constraint silently carries a package across many minor
releases; the features those releases added are frequently never adopted, and
nothing in the tooling pointed at them. The only changelog handling fetched the
current→latest delta and short-circuited up-to-date packages entirely
(`buildUpdateInfo` returned `changelog: null`), so the largest pool of unadopted
features — those in packages already on the latest version — was invisible.

### Change

Engine (pure, unit-tested):
- `services/changelog-opportunities.ts` — classifies changelog bullets into
  categories (added/changed/fixed/deprecated/removed/security/other) via
  Keep-a-Changelog section headers when present and leading-verb keyword
  inference when absent; extracts candidate API names (backtick spans,
  multi-hump PascalCase, dotted member access); ranks opportunities against
  project usage facts.
- `services/ai-prompt-bundle.ts` — assembles a ready-to-paste AI prompt from the
  classified opportunities plus the project's own call sites, with a task
  instruction encoding the review discipline (read the real API, reject
  decorative changes). Reframes its header for up-to-date packages.
- `services/opportunity-scan.ts` — fetches a package's full changelog history
  (reusing the cached `fetchChangelogWithFallback`) and mines every adoptable
  feature, independent of any version bump.

Pipeline:
- `changelog-service.ts` exports `parseAllEntries` and
  `fetchChangelogWithFallback` for full-history mining.
- `scan-orchestrator.ts` runs the opportunity scan for every package in its
  existing parallel fetch block and stores `opportunities` on the result.
- `import-scanner.ts` adds `readDartSources` (single shared walk),
  `collectImportsFromSources`, and `collectSymbolUsage` — so the import map and
  the changelog-symbol usage scan derive from one file read rather than two.
- `extension-activation.ts` computes the used-symbol set from the candidate API
  names, ranks each package (`unadoptedApiNames`, `opportunityScore`), and
  attaches both to the results.
- `types.ts` gains optional `opportunities`, `unadoptedApiNames`,
  `opportunityScore` on `VibrancyResult`.

Surfaces:
- Dedicated **Upgrade Opportunities dashboard** (`views/opportunities-html.ts` +
  `views/opportunities-panel.ts`, command
  `saropaLints.packageVibrancy.showOpportunities`) — a focused list of only the
  packages with unadopted features, ranked by score, each card showing
  description, README logo, the unused features, the importing files (click to
  jump to the line), and a Copy-for-AI button.
- **Opportunities column** in the Package Dashboard table (sortable; hides when
  empty) and a **"Copy opportunities for AI"** toolbar sweep bundling the
  top-ranked packages' prompts into one paste.
- **Per-package "Copy upgrade prompt for AI"** button in the detail pane.
- **Sidebar** Editor-dashboards section: the Package Dashboard row shows a "· N
  to adopt" badge, and a dedicated "Upgrade Opportunities" entry appears once a
  scan finds any.

### Heuristic ceiling (documented in code)
The classification surfaces *what* is new and whether a symbol is referenced; it
does not judge whether a feature semantically fits a specific call site. The
prompt and UI are framed as "review these," not "apply for you."

### Tests
- New: `changelog-opportunities.test.ts`, `ai-prompt-bundle.test.ts`,
  `symbol-usage.test.ts`, `opportunities-html.test.ts` — classification, API
  extraction, ranking, prompt assembly (including the up-to-date header), symbol
  matching (word boundaries, dotted preference), and the dashboard renderer
  (filter, ranking order, empty state, conditional copy button, clickable
  locations).
- Existing `import-scanner.test.ts` and `report-html.test.ts` re-run green after
  the single-walk refactor and the new table column.
- Whole-extension `tsc --noEmit` passes.

### Known follow-up
The user-facing strings added to `en.json` and `package.nls.json` require the
translation pipeline (`extension/scripts/generate_translations.py`) to repopulate
the locale catalogs. Until that runs, the `languagePick` locale-coverage test
fails (e.g. zh below full coverage). The pipeline is operator-run, not part of
this change.
