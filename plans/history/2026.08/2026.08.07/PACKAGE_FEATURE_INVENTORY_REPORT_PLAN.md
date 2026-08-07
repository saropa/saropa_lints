# Plan — Consolidated Package Opportunities Report

Status: Proposed
Owner: unassigned
Created: 2026-08-07

## Goal

One consolidated report covering **every package and every changelog feature**, each with a
description, homepage/docs links, and a usage count from **0 to n** listing the exact project
filenames. Written to `reports/` as HTML + Markdown + JSON so it can be handed to an AI for a
"are we using these packages well?" review.

This is **consolidation first**: the per-package opportunity data already exists and is already
rendered in three places. The only genuinely new capability is per-symbol usage counting.

---

## 1. What already exists

| Concern | File |
|---|---|
| Mine changelog bullets → `opportunities` (all categories) + `apiNames` | [changelog-opportunities.ts](extension/src/vibrancy/services/changelog-opportunities.ts) |
| Full-history fetch + mine, per package | [opportunity-scan.ts](extension/src/vibrancy/services/opportunity-scan.ts) |
| Runs for every package during scan | [scan-orchestrator.ts:124-141](extension/src/vibrancy/scan-orchestrator.ts#L124-L141) |
| Cross-reference vs project symbols → `unadoptedApiNames`, `opportunityScore` | [extension-activation.ts:1165](extension/src/vibrancy/extension-activation.ts#L1165) `rankAdoption` |
| Single Dart source read, shared by import + symbol scans | [import-scanner.ts:119](extension/src/vibrancy/services/import-scanner.ts#L119) `readDartSources` |
| Per-file import/export sites | [import-scanner.ts:151](extension/src/vibrancy/services/import-scanner.ts#L151) `collectImportsFromSources` |
| **Render — dashboard table cell** | [report-html-table.ts:654](extension/src/vibrancy/views/report-html-table.ts#L654) |
| **Render — detail pane section** (repo + docs links per API name) | [package-detail-html.ts:423](extension/src/vibrancy/views/package-detail-html.ts#L423) |
| **Render — dedicated panel** (cards, AI prompt, call sites) | [opportunities-html.ts](extension/src/vibrancy/views/opportunities-html.ts) |
| Per-package AI prompt assembly | [ai-prompt-bundle.ts](extension/src/vibrancy/services/ai-prompt-bundle.ts) |
| Markdown/JSON export convention (`reports/`, timestamped) | [report-exporter.ts](extension/src/vibrancy/services/report-exporter.ts) |

**Already available per package, no new collection needed:** name, version, latest version,
description, `repositoryUrl`, GitHub `repoUrl`, pub.dev doc URL, every classified changelog bullet
(`opportunities.all` — including `fixed`/`removed`/`security`/`other`, which the UI currently
discards), extracted API names per bullet, the version each bullet shipped in, and the import-site
file list.

## 2. The two gaps

1. **Usage is boolean, not counted or located.** `collectSymbolUsage`
   ([import-scanner.ts:174](extension/src/vibrancy/services/import-scanner.ts#L174)) returns a
   `Set<string>` and **breaks early** once every candidate has been seen
   ([:194](extension/src/vibrancy/services/import-scanner.ts#L194)). That is correct for its job
   (adopted-yes/no ranking) and must not change. It cannot yield counts or filenames.
2. **Every surface filters to unadopted-only.** All three renderers key off
   `unadoptedApiNames.length > 0`, so a fully-adopted package renders nothing. The report needs the
   used side too — that is the "0 to n" range.

Everything else is assembly.

---

## 3. Design

### 3.1 New: `collectSymbolOccurrences`

Added alongside `collectSymbolUsage` in `import-scanner.ts`. Same input array
(`readDartSources` output — no second file walk), same escaping and longest-first alternation.

```ts
export interface SymbolOccurrence {
    readonly filePath: string;
    readonly line: number;      // 1-based
    readonly column: number;    // 1-based
    readonly snippet: string;   // trimmed source line, capped
}
export function collectSymbolOccurrences(
    sources: readonly DartSource[],
    candidates: ReadonlySet<string>,
): ReadonlyMap<string, readonly SymbolOccurrence[]>
```

- **No early break** — scans every file to completion.
- **Skips import/export directive lines**: a `show ReelText` clause names the symbol but is not a
  usage. Reuse the directive patterns already in the module.
- Symbols with zero occurrences are simply absent from the map; the report treats absent as `0`.
- Known ceiling, stated in the report header: **textual matching, not resolved references**. A local
  variable named `Duration`, or a same-named symbol from another package, counts. Resolved-reference
  counting is deferred (§6) — the reviewing AI must be told, not left to assume.

Cost: one extra regex pass over sources already in memory. Run it in the same place as
`collectSymbolUsage` ([extension-activation.ts:1240](extension/src/vibrancy/extension-activation.ts#L1240))
so both share the walk, and store the map on the scan state for the report to read.

### 3.2 New: `feature-inventory-model.ts` — the consolidation

Pure module. Takes `readonly VibrancyResult[]` + the occurrence map, returns the report model.
No `vscode` import, fully unit-testable — same discipline as `ai-prompt-bundle.ts`.

Per package, emit **one entry per changelog bullet** from `opportunities.all` (not just
`opportunities`), carrying:

- `category` (`added`/`changed`/`fixed`/`deprecated`/`removed`/`security`/`other`)
- `text` (the description), `version` (shipped in)
- `apiNames`, and per API name: `usageCount` + the full `usages` list
- `adopted` — true when every named API has ≥1 usage; false when any is unused (this is the same
  judgment `rankAdoption` makes, restated per bullet so both ends of 0→n are present)

Per package: name, version, latest, description, `importFileCount`, the import-site file list, links
(pub.dev page, `https://pub.dev/documentation/<name>/<version>/`, repository, homepage), the existing
`opportunityScore`, and counts (`total` / `adopted` / `unadopted` / `noApiNamed`).

Bullets naming no API (`apiNames` empty) are kept with `usageCount: null` — "cannot be measured" is
distinct from "used zero times", and collapsing the two would mislead the reviewing AI.

Packages with **no changelog** (`opportunities === null`) still get an entry, marked
`changelogAvailable: false`, so the report is complete rather than silently short.

### 3.3 New: renderers

`feature-inventory-html.ts` and `feature-inventory-markdown.ts` — pure functions over the §3.2 model.
The existing three surfaces are left untouched; they remain the focused in-editor views and gain a
link to this export.

HTML structure, for a page with thousands of rows:

- **Level 1** — summary table, one row per package: feature count, adopted, unadopted, usage total,
  score. Sticky header, sortable, jump link into each package section.
- **Level 2** — one `<details>` per package, collapsed, `<summary>` carrying name, version, and the
  adopted/total counts.
- **Level 3** — inside a package, one `<details>` per category (`Added`, `Changed`, `Deprecated`,
  `Removed`, `Security`, `Other`), collapsed, count in the summary.
- **Level 4** — each feature is a `<details>`: summary = `qualifiedName · N usages · vX.Y.Z`;
  body = bullet text, doc + repo search links (reuse the URL shapes in
  [package-detail-html.ts:434-471](extension/src/vibrancy/views/package-detail-html.ts#L434-L471)),
  and the usage list.
- **Usage list** — `path:line` plus snippet. Over 20, show 20 and nest the remainder in a further
  `<details>` with an exact count. No silent caps anywhere.
- **Controls** — inline `<script>` with CSP nonce (same pattern as `opportunities-html.ts`): text
  filter, unused-only / used-only / deprecated-only toggles, expand-all / collapse-all, package index.
- **Zero-usage features carry a distinct chip** so they are findable at a glance.
- Standalone CSS (`prefers-color-scheme` aware) — the file opens in a browser, outside VS Code, so it
  cannot rely on `--vscode-*` variables the way the existing panels do.

Markdown twin: same hierarchy, `<details>` blocks (GitHub renders them) plus plain headings so raw
text ingestion still sees every feature.

JSON: the complete model, **untruncated** — truncation exists only in the presentation layer.

### 3.4 Command + output

- New command `saropaLints.packageVibrancy.exportOpportunitiesReport`, manifest string via
  `%…%` in `package.json` / `package.nls.json`.
- Writes three timestamped files to `reports/` via the existing `resolveReportFolder` /
  `formatTimestamp` helpers in [report-utils.ts](extension/src/vibrancy/services/report-utils.ts):
  `<ts>_saropa_opportunities.{html,md,json}`. Opens the HTML on completion.
- Surfaced from the Package Dashboard toolbar, the Opportunities panel header, and the command
  palette; registered in [commandCatalogEntriesProject.ts](extension/src/views/commandCatalogEntriesProject.ts).
- Requires a completed vibrancy scan (it consumes `VibrancyResult[]`). With no results, offer to run
  the scan first rather than emitting an empty report.

---

## 4. Implementation steps

1. **`collectSymbolOccurrences`** + tests — multi-file, dotted symbols (`ReelText.rich` wins over
   `ReelText`), import-line exclusion, zero-match, and an explicit assertion that it does **not**
   break early.
2. **Wire it into the scan** at [extension-activation.ts:1240](extension/src/vibrancy/extension-activation.ts#L1240),
   sharing the candidate set already built there; hold the map in scan state.
3. **`feature-inventory-model.ts`** + tests — asserts every category present, fully-adopted packages
   present, changelog-less packages present, `usageCount: null` distinct from `0`.
4. **`feature-inventory-html.ts`** / **`feature-inventory-markdown.ts`** + tests — zero-usage chips
   render, counts match the model, truncation discloses an exact count, every string via `l10n`.
5. **Command wiring** — activation, `withProgress`, `reports/` write, open-on-complete, and the
   cross-links from the three existing surfaces.
6. **i18n** — new `opportunitiesReport.*` namespace in `en.json`, manifest strings in
   `package.nls.json`, then `py -3 extension/scripts/generate_translations.py`. Report strings are
   user-facing even though they land in a file.
7. **Docs** — `CHANGELOG.md` under `[Unreleased] / Added` (1–3 sentences), README feature list,
   `CODEBASE_INDEX.md` for the new files.

Steps 1 and 3–4 are independently testable; 3–4 can be built against a hand-written model fixture
before step 2 lands.

## 5. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Textual matching over-counts common names (`Text`, `State`, `Duration`) | Caveat stated in the report header and in the JSON `caveats` array; flag single-word symbols that collide with `dart:core`/Flutter identifiers so the AI discounts them. Real fix in §6. |
| Report size — 100 packages × full changelog history | Everything collapsed by default, no images, usage lists capped in HTML with disclosed overflow, full data in JSON. Log the written byte size. |
| Occurrence scan slows the package scan | One extra pass over in-memory sources; measure and report the delta. If it exceeds ~1s on a large workspace, move it behind the report command instead of the scan. |
| Duplicates the three existing surfaces | Those stay as the focused in-editor views; this is the exhaustive export. Cross-link both directions; no changes to their behavior. |
| Changelog remains the feature source, so a package with no changelog shows no features | Explicitly marked `changelogAvailable: false` in the model and visible in the report — a known, disclosed limit, not a silent gap. §6 covers the fix. |

## 6. Deferred (explicitly out of scope)

- **Public-API extraction from the pub cache** (analyzer-based Dart CLI over
  `.dart_tool/package_config.json`) — the only way to list features of a package with no changelog,
  and to reach members never written up. Larger effort; revisit once the consolidated report exists
  and the gap is measurable.
- Resolved-reference usage counting via the analyzer element model (removes the false-positive class).
- Usage counting inside transitive dependencies.
- Per-feature adoption recommendations — that is the reviewing AI's job by design.

## 7. Acceptance criteria

- Every scanned package appears, including fully-adopted ones and ones with no changelog.
- Every mined bullet appears, in every category — not just `added`/`changed`.
- Each feature shows: description, version introduced, docs + repo links, usage count, and every
  usage filename (complete in JSON).
- Zero-usage and unmeasurable (`null`) features are visually distinct from each other.
- The HTML opens standalone in a browser with every group collapsed on load.
- No hardcoded user-facing strings; `generate_locales.py --fail-on-missing` passes.
- Any truncation in HTML/MD shows an exact count.

---

## Finish Report (2026-08-07)

### What was built

The consolidated report shipped as specified in sections 1–5, with the deferred
items in section 6 left untouched. Nine new modules under
`extension/src/vibrancy/`, one new command, and 85 passing tests across the
affected suites.

- `services/feature-inventory-types.ts` — the data contract, written first so the
  measurement, consolidation, and rendering work could proceed against a fixed
  shape without seeing each other's code.
- `services/import-scanner.ts` — gained `collectSymbolOccurrences`, sibling to
  `collectSymbolUsage`. The existing function stops as soon as every candidate
  has been seen, which is correct for adopted-yes/no ranking and useless for
  counting; it was left untouched rather than generalized.
- `services/feature-inventory-model.ts` — consolidation.
- `services/feature-inventory-export.ts` — orchestration and file writes.
- `views/feature-inventory-*.ts` (nine files) — HTML and Markdown renderers,
  styles, client script, and shared presentation helpers.

### Design decisions worth preserving

**The occurrence scan runs in the export command, not in the package scan.**
Section 3.1 proposed sharing the scan's single source walk. The scan already
walks sources for adoption ranking, but adding an unconditional second pass
taxes every rescan for a report exported rarely. Section 5 of the plan listed
this move as the contingency; it was taken up front rather than after measuring.

**Three-state usage, not two.** A changelog bullet naming no API is
`usageCount: null`, not `0`. Collapsing "cannot be measured" into "used zero
times" would present unmeasured features to a reviewing AI as dead code. The
renderers derive a fourth display state, `partial`, from the per-symbol counts.

**Version ordering.** A comparator returning 0 for unparseable version strings
is non-transitive and stranded `1.0.0` ahead of `1.10.0`. Unparseable versions
now sort last, preserving mined order among themselves.

### Defects found and fixed during review

- The `npm test` script had a dropped closing quote, concatenating two spec
  paths into one argument containing a literal space. Mocha matches nothing for
  such an argument and does not error, so `opportunities-html.test.js` (a
  pre-existing suite) and `feature-inventory-model.test.js` silently never ran
  while CI stayed green.
- The export opened the generated HTML with `openTextDocument`, showing raw
  markup with every control dead. It now uses `vscode.env.openExternal`, falling
  back to the editor only if the browser handoff fails.
- The write path had no error handling; an unwritable `reports/` folder became
  an unhandled rejection that dismissed the progress notification silently.
- `DIRECTIVE_LINE_PATTERN` matched only a directive's opening line, so symbols
  in a `show` clause wrapped by `dart format` counted as usages — the exact
  false positive the directive skip exists to prevent.
- Singular and plural usage labels were one catalog entry, rendering
  "1 usages".

### Known limits

Usage counting is textual, not resolved: a local variable named `Duration` or a
same-named symbol from an unrelated package is counted. This is disclosed in the
report header and in the JSON `caveats` array. Features remain changelog-derived,
so a package with no changelog lists none — marked explicitly rather than
rendered as an empty section. Both have their fix recorded in section 6.

`commandCatalogRegistry.test.ts` fails on six unrelated commands that predate
this work; verified by stashing these changes and re-running.

### Hardening pass (same day)

Applied after the first review, then re-reviewed:

- **Symbol matching rewritten from an alternation regex to tokenized Set
  lookups.** The old shape cost O(candidates) at every source position, and the
  candidate set is the union of API names across every dependency's changelog
  history. The replacement tokenizes dotted identifier chains once per line and
  looks each up in the candidate Set, walking segment starts so a member name
  (`rich` in `foo.rich`) is still found and `ReelText.rich` still beats
  `ReelText`. Verified semantically equivalent case by case during re-review.

  **This removed a growth term; it did not fix a measured bottleneck.** A
  wall-clock test was written to guard the scaling claim and then deleted: the
  alternation it replaced cleared 5000 candidates across 2000 lines in
  single-digit milliseconds, so any threshold loose enough not to flake also
  passed for the old implementation. The test that remains asserts correctness
  at that size only. The performance rationale is complexity reasoning, not
  evidence, and should not be cited as a win.

- **Docs URL unpinned.** `buildLinks` now emits `/documentation/<name>/latest/`
  rather than the installed version. pub.dev serves no documentation for a
  retracted version, so pinning 404s for exactly the packages a reader most
  needs. This also collapses a second source of truth — the package detail pane
  already built the `latest` shape.

- **Directive continuation hardened.** A trailing line comment is stripped
  before the terminating-semicolon check, so `import 'x' // drop this;` no
  longer ends the directive and expose the wrapped `show` clause beneath it as
  usages. A commented-out directive's own leading `//` is excluded from that
  strip so it still terminates normally.

- **Report size disclosed.** The export returns the HTML byte count and warns
  past 8 MB, pointing at the JSON artifact as the better input for tooling.

- **A silent failure introduced by the first fix was caught by key parity.**
  Refactoring the error handling orphaned the "no reports folder" message,
  making that path return with no user feedback. The result is now three-way:
  `undefined` for an already-reported error, `null` for an unresolvable folder,
  the record on success.

### Still unverified at hand-off

The feature was never executed end to end. No Extension Development Host was
launched, no browser opened the generated HTML, and no report was produced from
a real workspace. Every claim above rests on compilation, unit tests, and
review. The inline script was parsed, never run against a DOM.

### Second hardening pass — evidence over argument

The first hardening pass rested on reasoning. This one replaced the reasoning
with measurements, and two of the three claims did not survive.

**The tokenizer rewrite is now differentially tested, and it is NOT equivalent.**
`symbol-occurrence-equivalence.test.ts` reimplements the replaced alternation
matcher and asserts both produce identical symbol, file, line, and column output
across dotted members, bare member segments, prefixes of longer identifiers,
underscore identifiers, whitespace-split dotted names, string and comment
contents, repeated hits, deep chains, and a generated 25-file corpus.

Its first run found a divergence that review had missed: the old
`\b(alternation)\b` never matched a `$`-leading identifier, because `\b` requires
a word character and `$` is not one. Dart generated code uses `$`-prefixed names
freely, so the replaced matcher had been under-counting them silently. The
tokenizer finds them. The difference is an improvement and is now pinned by its
own test rather than buried inside an equivalence claim.

**The report size warning was a guess; it is now measured.** Synthetic reports
at increasing scale gave ~1 MB at 25 packages, ~4 MB at 50, ~13 MB at 100, and
~38 MB at 150. Growth is linear in total feature count. The 8 MB threshold lands
near 75 packages, which is the right place for a warning — but it also means the
plan's own target workspace of 100+ dependencies exceeds it, so the JSON
artifact, not the page, is the intended input at that scale.

**A size fix was tried and reverted.** Dropping source snippets from the
overflow usage lists looked like the obvious lever. Measured, it reclaimed only
about 10% because per-feature markup dominates, and it cost the reader the one
piece of context that makes a call site judgeable. Reverted, with the measurement
recorded at both sites so nobody re-attempts it.

**Directive shapes broadened.** Tests now cover the forms `dart format` actually
emits: a wrapped `show` with a following `hide`, `as` and `deferred as` prefixes
before a wrapped clause, and a wrapped `export`.

**One assumption resolved rather than documented.** `reports/` was already
covered by `.gitignore`, so the unbounded-growth risk named at hand-off does not
reach the repository.

### Deliberately not done

No DOM library is installed, and adding one to see the page render is a
dependency decision for the maintainer, not a hardening step to take
unilaterally. The generated HTML has still never been displayed by a browser.

### Third pass — the report's behavior is now executed

The gap carried through two hand-offs was that the generated page had never
run. Every test asserted on the HTML string: that a control appeared, that the
script parsed. None proved a control worked. A runtime error inside the inline
script would have left the filter, the mode toggles, expand-all, and the column
sort dead while the whole suite stayed green.

`jsdom` was added as a devDependency (a maintainer decision, taken with explicit
approval) and `feature-inventory-dom.test.ts` now renders the report, evaluates
the document with scripts enabled, and drives each control: expand and collapse
across every disclosure, text filtering with group hiding, the changelog-less
package that must survive a query it cannot match, filter clearing, the three
mutually exclusive mode toggles including toggle-off, category selection, column
sort with direction reversal, and hash navigation opening a linked package's
ancestors.

**The harness was mutation-tested before being trusted.** Three deliberate
defects were injected into the script and each was caught: pointing the filter
at a non-existent class failed 4 tests, dropping the sort's direction term
failed the sort test, and removing the `total > 0` guard failed exactly the
changelog-less-package test written to protect it. The script was then restored
and verified byte-identical to the committed version. A green suite that cannot
fail proves nothing, which is the lesson the deleted wall-clock test taught.

The script needed no fixes — it was correct as written. That is now evidence
rather than assumption.

**Collateral, recorded because it was self-inflicted:** the first `npm install`
ran from the repository root and created a stray root `package.json`,
`package-lock.json`, and `node_modules`. Removed; jsdom belongs only to
`extension/package.json`.

The remaining unverified surface is narrow: the report has still never been
opened by a real browser, so CSS layout and the theme media query are unproven.
Behavior, data, and structure are covered.
