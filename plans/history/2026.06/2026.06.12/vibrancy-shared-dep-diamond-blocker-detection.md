# Package Vibrancy: shared-transitive-dependency (diamond) blocker detection

The Package Vibrancy dashboard reported many stuck upgrades as unexplained
blocks with no named blocker, or named the wrong package. The blocker analysis
only walked reverse-dependency chains ("which package depends on the blocked
package, and does its constraint hold it back"). That walk structurally cannot
explain the most common real-world block: two sibling dependencies both depend
on a shared transitive dependency, and one sibling caps that shared dependency
below the version the other needs at its latest. The canonical instance is
`dart_style` held back because `saropa_lints` caps `analyzer <13` — both depend
on `analyzer`, neither depends on the other, so the reverse-dependency walk
never connects them. Conflicts over `analyzer` and `meta` therefore surfaced as
"constrained" rows with no actionable explanation.

## Finish Report (2026-06-12)

### Scope

VS Code extension (TypeScript) only. No Dart lint rules, `lib/`, or Dart tests
were touched.

### What changed

- `extension/src/vibrancy/services/flutter-cli.ts` — `runDartPubOutdated` now
  passes `--transitive`. The contested shared dependencies (`analyzer`, `meta`,
  `characters`, …) are themselves transitive, so without this flag their
  resolvable-vs-latest gap is invisible and the pivot of a diamond conflict
  cannot be seen. The extra rows are strictly additive: direct-dependency
  classification still keys off the direct entries.

- `extension/src/vibrancy/scoring/shared-dep-conflict-detector.ts` (new, pure) —
  finds contested shared dependencies (blocked, with two or more dependents)
  and attributes each blocked direct dependency's block to the sibling whose
  constraint is the *binding ceiling*. Binding is defined precisely: the
  constraint permits the resolved version but excludes the latest, so a looser
  sibling range that allows both is never mistaken for the blocker. Direct
  dependencies are preferred as the named blocker so the result is actionable.

- `extension/src/vibrancy/services/shared-dep-constraints.ts` (new) — builds the
  constraint index the detector needs. `dart pub deps --json` exposes the
  resolved graph but not per-edge version constraints, so each candidate
  constrainer's own `pubspec.yaml` is read from the resolved pub cache via the
  existing `resolvePackagePaths` + `parsePubspecYaml`. Reads are bounded to the
  packages that depend on a contested shared dependency, keeping I/O off the
  full transitive set.

- `extension/src/vibrancy/services/blocker-enricher.ts` — runs the diamond pass
  after the reverse-dependency pass and lets it take priority for the packages
  it covers, because those are exactly the ones the reverse-dependency walk
  returns wrong or null for. The signature changed from `cwd: string` to the
  `vscode.Uri` workspace root (its sole caller already had the Uri) so the
  constraint index can resolve the pub cache.

- `extension/src/vibrancy/types.ts` — `BlockerInfo` gained optional
  `sharedDependency`, `sharedDependencyResolvable`, `sharedDependencyLatest`,
  and `blockerConstraint`. Optional, so every existing blocker producer and
  renderer is unaffected; ordinary reverse-dependency blocks leave them unset.

- `extension/src/vibrancy/scoring/blocker-analyzer.ts` — added
  `formatSharedDepDetail`, which renders the shared-dependency explanation for
  the non-localized IDE surfaces or returns null for an ordinary block.

- Display: the hover table, tree detail item, package-detail webview, and
  detail-view webview now show the shared-dependency reason. The webviews route
  it through a new `l10n('packageDetail.version.blockedVia', …)` key with
  `{token}` interpolation; the tree and hover reuse the existing English-only
  blocker-label convention already present in those files.

### Verification

- `npm run check-types` (whole extension, `tsc --noEmit`): clean.
- Test project build (`tsc -p tsconfig.test.json`): clean after replacing the
  orphaned `blocker-analyzer.test.ts` stale result builder with the shared
  `makeMinimalResult` helper.
- Targeted run of the affected files (detector, blocker-analyzer, detail-view
  HTML, package-detail HTML, hover, tree-items): 129 passing.
- Test audit: no test pins the `runDartPubOutdated` argument list (the only
  `pub outdated --json` assertion lives in the unrelated CI-YAML generator).
  The detail-view blocker test uses an ordinary blocker with no
  `sharedDependency`, so the append-only render change keeps its assertion.
  `enrichWithBlockers` has no test references, so the signature change is
  unobserved.

### Tests added

- `extension/src/test/vibrancy/scoring/shared-dep-conflict-detector.test.ts` —
  covers the real `dart_style`/`analyzer`/`saropa_lints` diamond plus
  binding-ceiling selection, the not-blocked guard, the single-dependent guard,
  the looser-sibling guard, direct-over-transitive preference, and the
  no-constraint-data path.
- `extension/src/test/vibrancy/scoring/blocker-analyzer.test.ts` — added
  `formatSharedDepDetail` coverage; this previously-orphaned file was also
  wired into `tsconfig.test.json` and the `npm test` glob.

### Localization

The source key `packageDetail.version.blockedVia` was added to `en.json`.
Regenerating the 25 translated catalogs requires the NLLB machine-translation
pipeline, which is under a standing hard prohibition; it was not run. The i18n
runtime resolver falls back to English for missing keys, so the string renders
correctly in every locale until the next explicitly-authorized translation run.

### Outstanding

Translated locale catalogs are stale for the one new key (English fallback
active). No other outstanding work.
