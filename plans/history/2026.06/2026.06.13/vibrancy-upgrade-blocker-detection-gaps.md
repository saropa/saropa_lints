# Package Vibrancy: upgrade-blocker detection gaps

The Package Vibrancy dashboard reported many stuck dependency upgrades as
unexplained "blocked" or bare "constrained" rows, and nagged to upgrade
dependencies that were deliberately frozen or could not be bumped at all. The
blocker analysis only walked reverse-dependency chains and compared pub.dev
versions; it could not see five recurring blocker shapes that real saropa
pubspec comments document. Each shape was reproduced from those comments and
addressed, except the ones that need inputs the scanner does not have.

## Finish Report (2026-06-13)

### Scope

VS Code extension (TypeScript) only. No Dart lint rules, `lib/`, Dart tests, or
`analysis_options*.yaml`.

### Blocker classes and how each is now handled

1. **SDK-pin diamond** — a contested shared transitive dep (characters,
   collection, path, stack_trace, meta) is pinned by a Flutter SDK package
   (flutter_test) whose constraint is opaque. `findConstrainer` in
   `shared-dep-conflict-detector.ts` gained an SDK fallback: when no hosted
   sibling exposes a readable binding ceiling but an SDK package depends on the
   blocked shared dep, the block is attributed to the SDK as an inferred pin
   (`viaSdk`). The SDK package set is derived from lockfile source `sdk` and
   threaded through `enrichWithBlockers`. Mirrors the inference the override
   analyzer already documents for SDK-transitive overrides.

2. **Constrained reason** — a row pub could lift but the project's own pubspec
   caps was labeled `constrained` with no reason. `enrichWithBlockers` now
   attaches `constrainedReason` (own constraint + resolvable + latest), rendered
   as "your constraint ^x caps this — y resolvable".

3. **Override/SDK-aware version status** — git/path/SDK deps cannot be bumped by
   editing a constraint, yet showed a pub.dev "update available" gap. The
   update-available diagnostic is now gated on hosted source
   (`isHostedUpgradeable`), and the hover version arrow is annotated via
   `managedSourceNote` ("via git override", "SDK-managed").

4. **Pin intent** — a "do not bump" / "do not use" note in a dependency's
   pubspec comment was discarded at parse, so a deliberately-frozen dep looked
   like neglect. `pin-intent-parser.ts` reads the comment block attached to each
   dependency, classifies it (`do-not-upgrade` / `do-not-use`), and the upgrade
   nag is suppressed for it. Also subsumes the practical native-build-break case
   (e.g. home_widget's AGP/Kotlin pin), whose only machine-readable signal is
   the comment.

5. **Cross-project version drift** — pub-outdated sees one workspace, so a
   package pinned at a lower major than a sibling repo (saropa_lints `^9.7.0`
   here vs `^13.12.7` elsewhere) was invisible. A new setting
   `saropaLints.packageVibrancy.siblingRepoPaths` lists sibling repo folders;
   `sibling-constraints.ts` reads their pubspec constraints and
   `cross-project-drift-detector.ts` compares majors, flagging a lagging package
   as "behind". Off until paths are configured.

### Deliberately not built (with reason)

- **Undeclared-import / publish-rule** (a package imports `package:x` it does
  not declare) is already enforced by the pre-tag publish audit gate
  (`scripts/modules/_audit_checks.py`, `get_dependency_import_status`). A scanner
  duplicate would be redundant.
- **Comment-less native build break** (a Gradle/AGP incompatibility with no
  pubspec signal) needs a Gradle/AGP knowledge base that cannot be made
  reliable; the commented case is covered by pin intent (item 4).

### Surfaces

Blocker, constrained, source-note, pin-intent, and drift detail are shown in the
hover table, the tree Version/Update groups, the package-detail webview, and the
detail-view webview. Webview strings route through new `l10n()` keys
(`blockedVia`, `blockedViaSdk`, `constrained`, `constrainedBy`, `pinHeld`,
`pinDoNotUse`, `drift`, `driftBehind`, `driftDiffers`) plus a `package.nls.json`
description for the new setting; the tree/hover surfaces reuse the existing
English-only blocker-label convention already present in those files.

### Verification

- `npm run check-types`: clean for every touched file (the only errors are
  pre-existing `test-ux/` Playwright files from a separate workstream).
- 155 tests passing across the affected suites.
- `verify-nls-keys`: OK (307 keys) — the new manifest setting has its NLS entry.
- Translated locale catalogs regenerated and confirmed to carry the new keys;
  the NLLB pipeline runs on its own authorized cadence, not from the scan code.

### Tests added

- `cross-project-drift-detector.test.ts` — behind / ahead / same-major /
  missing / multi-sibling / no-config / uncoercible.
- `pin-intent-parser.test.ts` — do-not-bump, do-not-use, trailing ignore
  marker, blank-line break, next-dep binding, ordinary-doc negative.
- `shared-dep-conflict-detector.test.ts` — added SDK fallback and
  hosted-preference cases.
- `blocker-analyzer.test.ts` — added `formatConstrainedReason`,
  `managedSourceNote`, `isHostedUpgradeable`, `formatPinIntent`,
  `formatVersionDrift`; de-rotted the orphaned result builder onto the shared
  `makeMinimalResult`.

### Commits

- `b88cb668` — SDK pins, constrained reasons, override gaps, pin intent.
- `b99ca377` — cross-project version drift.

### Outstanding

None for the detection work. Cross-project drift is dormant until a consumer
sets `siblingRepoPaths`.
