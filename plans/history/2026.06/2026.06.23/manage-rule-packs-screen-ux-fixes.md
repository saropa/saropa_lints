# Manage Rule Packs screen — UX fixes and rule-finding aids

The Manage Rule Packs webview (Config Dashboard) carried four defects: a redundant
rule-count column paired with a separate "View" button, a coverage gauge that showed
the percentage over an unfilled arc, search that matched only pack names, and pack
toggles that stacked overlapping analyses. This change merges the count/disclosure
columns, repairs the gauge, broadens search to individual rule codes, supersedes
in-flight analyses, and adds four rule-discovery aids.

## Scope

VS Code extension (TypeScript) only. No Dart lint rules, analyzer, or
`analysis_options*` touched.

Files:
- `extension/src/rulePacks/rulePacksWebviewProvider.ts` — table markup, gauge data
  attributes, header count badges, search data attributes, finder/match-count
  containers, two new exported helpers.
- `extension/src/rulePacks/configDashboardScript.ts` — merged-column colspans,
  rule/domain search matching with auto-expand, gauge animation, and the rule-finder
  / match-count / highlight client logic.
- `extension/src/rulePacks/configDashboardStyles.ts` — scoped gauge transition,
  merged Rules cell, match count, finder panel, and `<mark>` highlight styles.
- `extension/src/setup.ts` — supersede-in-flight `runAnalysis`.
- `extension/src/test/rulePacks/rulePacksWebviewProvider.test.ts` — tests for the
  two new helpers.
- `CHANGELOG.md` — Added/Changed/Fixed (Extension) entries under `[Unreleased]`.

## Defects and fixes

### 1. Redundant rule-count column

The pack table rendered a numeric `Rules` cell and, in a separate trailing column, a
"View" button that toggled the same rule list. The two columns are merged into one:
the count is now the disclosure control — an "N rules" link that both displays the
count and expands the detail row. The table dropped from seven to six columns;
`colspan` values in the shared header, detail rows, per-table empty rows, and the
client script's injected empty row were updated to match.

### 2. Coverage gauge rendered empty at any score

The hero gauge's fill level was delivered as a `--gauge-target` custom property on an
inline `style=""` attribute, consumed via `var()` in the shared `@keyframes`. The
webview CSP sets `style-src 'nonce-… ' 'unsafe-inline'`; a nonce in the source list
makes the browser ignore `'unsafe-inline'` for inline style *attributes* (which
cannot carry a nonce), so `--gauge-target` was dropped and the fill resolved to its
`0` fallback while the plain-text numeric label still showed the score. The fill is
now driven from the nonce'd client script via `setProperty` (the mechanism the Code
Health gauge already uses), reading `data-gauge-target` / `data-gauge-arc` /
`data-gauge-color` from the element. The shared keyframe is replaced — scoped to this
dashboard's stylesheet — with a `stroke-dasharray` transition, and the script raises
the value from `0` to the score on the next animation frame so the arc animates in.
A `prefers-reduced-motion` guard jumps straight to the resting value.

### 3. Search matched pack names only

Pack rows carried `data-label` (the pack name) and search matched only that, so a
rule could not be found by its own name. Rows now also carry `data-rules-text` (the
space-joined lowercase rule codes) and `data-domain`. Search matches the pack name,
its problem-area domain, or any rule code; a rule-code-only match auto-expands that
pack's rule list so the matching rule is visible, and the expansion is reverted when
the query is cleared.

### 4. Pack toggles stacked overlapping analyses

Each pack toggle awaited `saropaLints.runAnalysis`, which spawned a fresh cancellable
progress notification and `dart analyze` child without stopping any prior run. Rapid
toggles left several "Running analysis" notifications and overlapping analyzer
processes. `runAnalysis` now holds a module-level `CancellationTokenSource`; a new
run cancels and disposes the previous one before starting, killing the prior child
(its progress notification then resolves and closes). The progress UI's Cancel button
is funnelled into the same token via a listener that is disposed in a `finally`. The
shared slot is cleared only when the finishing run still owns it, so a superseding run
is not clobbered. Newest-wins is always correct: two concurrent full analyses race to
write the same `violations.json`.

## Rule-discovery aids

Four additions key off the active search query:
- Section and domain accordion headers read "N packs · M rules" (helpers
  `packsAndRulesLabel` and `sumPackRules`) so rule concentration is visible before a
  group is opened.
- A live "N packs · M rules" readout (`role="status"`, `aria-live="polite"`) beside
  the search box; the rule half appears only while text-searching.
- Matched substrings are wrapped in `<mark>` inside expanded pack rule lists and the
  finder, using the editor's find-highlight color; reset to plain text on clear.
- A "Matching rules" panel lists each matching rule code once (deduped across
  overlapping packs) with its owning pack(s). A rule code links to its explanation; a
  pack link opens that pack wherever it lives (detected table or a collapsed domain
  group), expands its rule list, and scrolls to it. The list is capped at 60 with a
  "refine your search" note.

## Verification

- `tsc --noEmit` clean for all touched files. (Pre-existing errors in
  `report-webview.ts` and `package-detail-*.ts` belong to other in-flight work and
  were not introduced here.)
- The assembled client script passes a `new Function(src)` syntax check.
- `mocha out-test/test/rulePacks/rulePacksWebviewProvider.test.js` — 15 passing,
  including the two new helper tests.

## Localization note

The Config Dashboard's interactive chrome (search placeholder, filter strip labels,
empty-state text, column tooltips) is hardcoded English throughout; the client script
has no `l10n()` call sites and, as a static template rendered into the webview, cannot
invoke the host-side `l10n()` at render time. The new strings follow that established
local convention. Externalizing them in isolation would be inconsistent and partial;
full localization of this surface is a separate, larger task that would pass a
host-resolved strings bundle into the script. No `en.json` keys were added, so no
catalog regeneration was required.
