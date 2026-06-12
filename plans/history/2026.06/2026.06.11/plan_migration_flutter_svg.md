# Plan: `flutter_svg_2` migration pack

**Status:** ready to implement. **Value: HIGH** — `color` / `colorBlendMode` are
**deprecated and still compile** on 2.x (later fully removed), so the lint is the
only nudge while they linger. **Gate type:** post-upgrade cleanup.
**Gate:** `flutter_svg >= 2.0.0`. **Driving app:** Saropa Contacts ships
`flutter_svg: ^2.3.0` (8 `SvgPicture` sites; none use deprecated `color:` —
already clean, pack serves the general user base).

## 1. The migration (verified)

`flutter_svg` 2.0.0 deprecated the `color` and `colorBlendMode` parameters on
`SvgPicture.*` constructors in favor of a single `colorFilter`.

```dart
// Old (deprecated, still compiles on 2.x)
SvgPicture.asset('icon.svg', color: Colors.red, colorBlendMode: BlendMode.srcIn)

// New
SvgPicture.asset('icon.svg',
    colorFilter: const ColorFilter.mode(Colors.red, BlendMode.srcIn))
```

`colorBlendMode` defaulted to `BlendMode.srcIn`, so a `color:`-only call maps to
`ColorFilter.mode(<color>, BlendMode.srcIn)`.

## 2. Rule (`lib/src/rules/packages/flutter_svg_rules.dart`, new file)

Single rule `prefer_svg_color_filter`.

**Detection (type-safe):** match an `InstanceCreationExpression` / named
constructor invocation whose static type is `SvgPicture` from
`package:flutter_svg`, that passes a `color:` and/or `colorBlendMode:` named
argument. Type-check via the constructor element's library URI — do NOT match any
widget carrying a `color:` arg (`Icon`, `Text`, `Container` all have one). This is
the primary false-positive trap.

**Fix (mechanical):** remove `color:` (+ `colorBlendMode:` if present), insert
`colorFilter: ColorFilter.mode(<colorExpr>, <blendExpr or BlendMode.srcIn>)`.
Preserve `const` when both operands are const. If `color:` is a nullable/dynamic
expression the rewriter cannot prove non-null, emit report-only (a null `color`
meant "no filter", but `ColorFilter.mode(null, ...)` is invalid) — name this in
the correctionMessage.

## 3. Wiring (recipe steps 2–6)

- `kRulePackDependencyGates`: `'flutter_svg_2': RulePackDependencyGate(dependency: 'flutter_svg', constraint: '>=2.0.0')`
- generator: `'flutter_svg_2': {'flutter_svg'}` + title `'flutter_svg 2.x'`
- `kRelocatedRulePackCodes`: `'prefer_svg_color_filter': (fromPack: 'flutter_svg', toPack: 'flutter_svg_2')`
- Regenerate (twice) + `dart format`.

## 4. Tests

- `test/config/rule_packs_flutter_svg_test.dart`: gate passes 2.0.0 / 2.3.0, fails
  1.x / absent; ownership; merge override.
- `test/rules/packages/flutter_svg_rules_test.dart`: `SvgPicture.asset(color:)`
  triggers; `colorFilter:` form does not; `Icon(color:)` / `Container(color:)` do
  NOT trigger (FP guard); fix maps `color`+`colorBlendMode` → `ColorFilter.mode`,
  and `color`-only → `ColorFilter.mode(c, BlendMode.srcIn)`; nullable `color` →
  report-only.

## 5. Verify

`dart run tool/rule_pack_audit.dart` exit 0 (flutter_svg_2=1); tests pass;
`dart analyze --fatal-infos` clean. Confirm FP guard against `Icon`/`Container`
with the scan CLI on a mixed fixture.

## Sources

- [flutter_svg changelog](https://pub.dev/packages/flutter_svg/changelog)
- [Issue #828: migration guide for deprecated `color`](https://github.com/dnfield/flutter_svg/issues/828)
- [Issue #856: color in SvgPicture](https://github.com/dnfield/flutter_svg/issues/856)

---

## Correctness & best-practice rules (non-migration)

All rules gate on `flutter_svg >= 2.0.0` and detect `SvgPicture` exclusively via its
static type resolved from library URI `package:flutter_svg` — never by bare name or
string matching. `errorBuilder` was added in **2.0.17**; the network/string rules
should sub-gate on `>= 2.0.17` (or emit a weaker INFO on earlier 2.x and rely on
`placeholderBuilder` guidance only).

| rule_name | type | detects | quick-fix? | severity | FP guard |
|---|---|---|---|---|---|
| `svg_network_missing_error_builder` | correctness | `SvgPicture.network(...)` with no `errorBuilder:` argument | yes — inserts stub | WARNING | skip only when `errorBuilder:` already present (`placeholderBuilder:` does NOT cover the error case — see body) |
| `svg_network_missing_placeholder` | UX | `SvgPicture.network(...)` with no `placeholderBuilder:` argument | yes — inserts stub | INFO | skip when `width`/`height` are zero (intentional invisible placeholder) |
| `svg_missing_semantics_label` | a11y | `SvgPicture.*` (any constructor) with no `semanticsLabel:` AND no `excludeFromSemantics: true` | yes — inserts `semanticsLabel: ''` with TODO comment | INFO | skip when `excludeFromSemantics: true` is already present |
| `svg_string_missing_error_builder` | correctness | `SvgPicture.string(...)` with no `errorBuilder:` argument | yes — inserts stub | WARNING | skip when `errorBuilder:` already present |
| `svg_asset_not_precached` | performance | `SvgPicture.asset(...)` called inside a `build` method body on a class that has no corresponding `svg.cache.putIfAbsent` call anywhere in the file | no (cross-file) | INFO | skip when widget is `const`, when inside a test file, or when `SvgAssetLoader` for the same path string is found in the same library (speculative — verify scope) |

---

### `svg_network_missing_error_builder`

> **VALIDATION (2026-06-11) — FIX (guard contradiction):** Resolved — the FP-skip table previously listed `placeholderBuilder:` as a suppressor, contradicting the body (which correctly says placeholderBuilder only shows while loading, not on failure). Table row fixed: only `errorBuilder:` suppresses.

**What / why:** `SvgPicture.network` without `errorBuilder:` silently renders nothing
when the request fails or returns a non-SVG body. There is no visual fallback, no
exception surface, and no user signal — the widget simply stays blank. Added in
flutter_svg 2.0.17 ([Issue #996](https://github.com/dnfield/flutter_svg/issues/996));
earlier 2.x builds have no error callback at all.

**Detection (AST, type-safe):** Visit every `InstanceCreationExpression` whose
constructor name resolves to `SvgPicture.network` (static type `SvgPicture` from
`package:flutter_svg/src/svg.dart` or the re-export `package:flutter_svg/flutter_svg.dart`).
Check the named argument list for an `errorBuilder` argument. If absent, report at
the constructor name token. Confirm library URI contains `package:flutter_svg` before
reporting — do NOT match any other widget carrying a `url:` or `network` constructor.

**Fix:** insert `errorBuilder: (context, error, stackTrace) => const SizedBox.shrink()`
as a named argument. A non-null stub is preferred over a silent `null` so the caller
is forced to consciously change it rather than leaving the blank behavior in place.

**False positives:** none known beyond the type-check guard. A `placeholderBuilder`
alone does NOT cover the error case (it only shows while loading, not on failure), so
do not treat its presence as a suppressor.

---

### `svg_network_missing_placeholder`

**What / why:** `SvgPicture.network` is inherently async. Without `placeholderBuilder:`,
the widget renders a blank/transparent space until the first frame of the SVG arrives.
On slow or offline connections this blank space is visible for a noticeable duration
and is indistinguishable from a broken layout. `SvgPicture.asset` is unaffected
(asset bytes are synchronously available from the bundle).

**Detection (AST, type-safe):** Same constructor resolution as above
(`SvgPicture.network`). Check named argument list for `placeholderBuilder`. If absent,
report at the constructor name token.

**Fix:** insert `placeholderBuilder: (context) => const SizedBox.shrink()` as a stub.
The stub is intentionally minimal — the developer must replace it with a real
loading widget. Do not insert `CircularProgressIndicator` directly; that would impose
a visual choice the codebase may not want.

**False positives:** if `width: 0` and `height: 0` are both present the widget is
intentionally invisible; skip. Also skip if both `width` and `height` are literal
zero values.

---

### `svg_missing_semantics_label`

> **VALIDATION (2026-06-11) — FIX (quick-fix ban):** The fix inserts `semanticsLabel: ''` + a `// TODO` — an empty value that silences nothing meaningful plus a TODO falls under the TODO-insert fix ban. Make the rule report-only (no quick fix), or have the fix insert `excludeFromSemantics: true` as a genuine code change.

**What / why:** SVGs are opaque to screen readers unless `semanticsLabel` is provided.
The `SvgPicture` widget wraps its output in a `Semantics` node; without a label the
node carries an empty description and VoiceOver / TalkBack users get no context.
Decorative SVGs MUST set `excludeFromSemantics: true` instead — that is the correct
opt-out, not simply omitting the label, because an unlabeled but semantics-included
node still pollutes the a11y tree.

**Detection (AST, type-safe):** Visit every `InstanceCreationExpression` whose static
type is `SvgPicture` (any constructor: `asset`, `network`, `string`, `memory`,
`file`). Report when BOTH of the following are true: (a) `semanticsLabel` named arg
is absent or its value is an empty string literal `''`; AND (b) `excludeFromSemantics`
named arg is absent or is `false`. Report at the widget expression.

**Fix:** insert `semanticsLabel: ''` with a `// TODO: describe this SVG for screen readers` inline comment. An empty string is intentionally invalid so the developer is forced to fill it in — the fix is a nudge, not a silencer.

**False positives:** any `SvgPicture` that already has `excludeFromSemantics: true`
is a legitimate decorative SVG and MUST NOT be reported. That combination is correct
and expected. Do not report when `semanticsLabel` is present even if it is a variable
reference (non-literal) — trust the developer to have set it.

---

### `svg_string_missing_error_builder`

**What / why:** `SvgPicture.string` decodes raw SVG markup at runtime. If the string
is dynamically built or comes from an external source it may be malformed, partially
truncated, or contain unsupported SVG features; the vector_graphics compiler will
throw during parsing. Without `errorBuilder:` the exception propagates as an
unhandled widget build error and the widget tree subtree is dropped. With a handler
the app can degrade gracefully. (Note: in a native Flutter context there is no
browser-level XSS risk from SVG `<script>` tags — flutter_svg's parser does not
execute embedded scripts. The concern here is parse failure / app crash, not code
injection.)

**Detection (AST, type-safe):** Same approach as the network rule but for the
`SvgPicture.string` named constructor. Check for the `errorBuilder` argument. Report
when absent.

Narrowing heuristic to reduce FP rate: only report when the first positional argument
(the string value) is NOT a string literal (i.e., it is a variable, method call, or
interpolation — evidence it is dynamic). When the string is a compile-time constant
literal the SVG content is fixed and known-good at write time, making an error handler
less critical. Emit INFO rather than WARNING in that case.

**Fix:** same stub as the network rule.

**False positives:** `SvgPicture.string` with a hard-coded string literal is lower
risk; keep severity at INFO for that case per the heuristic above. Skip entirely
if `errorBuilder:` is already present.

---

### `svg_asset_not_precached`

> **VALIDATION (2026-06-11) — FEASIBILITY (defer/drop):** Cross-file precaching (main.dart / splash) is an unavoidable FP (the plan admits this), and file-local string-literal path matching is fragile. Defer behind the migration rules or drop — do not ship in the first cut.

**What / why:** flutter_svg 2.x removed the `precachePicture` API. The replacement
is to call `svg.cache.putIfAbsent(loader.cacheKey(null), () => loader.loadBytes(null))`
with a `SvgAssetLoader` before the frame that renders the widget
([Issue #841](https://github.com/dnfield/flutter_svg/issues/841);
[migration article](https://medium.com/@alimardon_begov/flutter-rendering-svg-with-no-lags-805c47bf6770)).
Without precaching, the first render of a `SvgPicture.asset` incurs a synchronous
isolate decode plus cache-miss I/O, causing a visible per-frame lag on navigation.

**Detection (AST, type-safe — speculative, verify scope):** Visit `InstanceCreationExpression`
nodes resolving to `SvgPicture.asset`. Check whether the enclosing method is a
`build` override (parent chain: `MethodDeclaration` with name `build` inside a class
extending `State` or `StatelessWidget`). Then scan the same compilation unit for any
`MethodInvocation` whose receiver resolves to `svg.cache` (`svg` is the global
`Svg` instance from `package:flutter_svg/svg.dart`) and whose method name is
`putIfAbsent`, with an argument whose value contains the same string literal as the
`SvgPicture.asset` path. If no such call is found anywhere in the file, report at
the `SvgPicture.asset` constructor.

**Limitations / FP notes:**
- Cross-file precaching (e.g., precached in `main.dart` or a splash screen) will
  appear as a false positive. The rule is a file-local check only — document this
  clearly in the `correctionMessage` so developers know the intent, not just the error.
  Consider adding an `// ignore: svg_asset_not_precached` escape hatch via
  `IgnoreUtils`.
- Widgets annotated `const` are trivially zero-cost to construct and should be skipped
  (though runtime decode still applies — mark in correction message that the precache
  is still recommended even for const constructors).
- Test files (`isTestFile` via `ProjectContext`) should be skipped entirely.
- Severity: INFO — this is a performance nudge, not a correctness error.
- **This rule has higher FP risk than the others.** Cross-file precache patterns are
  common. Implement this rule last and validate against a real project before shipping.

**Quick fix:** none. Cross-file precache insertion is beyond safe mechanical repair
scope. The `correctionMessage` should include the exact code pattern to add in the
app's initialization path.

---

## Sources (non-migration rules)

- [flutter_svg pub.dev API docs — SvgPicture](https://pub.dev/documentation/flutter_svg/latest/svg/SvgPicture-class.html)
- [flutter_svg changelog](https://pub.dev/packages/flutter_svg/changelog) (errorBuilder added 2.0.17)
- [Issue #996: Add errorBuilder to SvgPicture](https://github.com/dnfield/flutter_svg/issues/996)
- [Issue #921: How do I handle errors?](https://github.com/dnfield/flutter_svg/issues/921)
- [Issue #841: Provide easy migration examples for precachePicture](https://github.com/dnfield/flutter_svg/issues/841)
- [vector_graphics.md — precachePicture removal](https://github.com/dnfield/flutter_svg/blob/master/vector_graphics.md)
- [Medium: Flutter SVG pre-caching with SvgAssetLoader](https://medium.com/@alimardon_begov/flutter-rendering-svg-with-no-lags-805c47bf6770)

---

## Build recipe (self-contained)

The reusable steps every migration pack follows; the package-specific values are
in the Wiring section above. Extracted from the shipped `riverpod_2` and `dio_5`
packs.

1. **Rule(s) + fix.** Add detection rule(s) for the *old* API to
   `lib/src/rules/packages/<package>_rules.dart` (create the file if absent),
   extending `SaropaLintRule`. Add a `DartFix` that rewrites old → new where the
   transform is mechanical.
2. **Register.** Add `MyRule.new` to `_allRuleFactories` in
   `lib/saropa_lints.dart`; add the rule code to a tier set in `lib/src/tiers.dart`.
3. **Dependency gate.** Add to `kRulePackDependencyGates` in
   `lib/src/config/rule_packs.dart`:
   `'<package>_<major>': RulePackDependencyGate(dependency: '<package>', constraint: '>=X.0.0')`.
4. **Pack definition.** Add the gated pack id + its dependency name(s) and title in
   `tool/generate_rule_pack_registry.dart` (the gate-dep map and title map,
   alongside the `dio_5` / `riverpod_2` entries).
5. **Relocate the rule code into the gated pack.** Add to `kRelocatedRulePackCodes`
   in `tool/rule_pack_audit.dart`:
   `'<rule_code>': (fromPack: '<package>', toPack: '<package>_<major>')`. This is the
   load-bearing step — it moves the version-gated rule out of the ungated package
   pack so a project on the *old* version is never told to adopt an API that does
   not exist there.
6. **Regenerate.** `dart run tool/generate_rule_pack_registry.dart` (run twice — the
   TS writer reads the compiled registry), then `dart format`.
7. **Test.** `test/config/` — gate + ownership + merge (mirror
   `rule_packs_semver_test.dart`). `test/rules/packages/<package>_rules_test.dart` —
   detection + fix.
8. **Verify.** `dart run tool/rule_pack_audit.dart` exit 0; `dart analyze --fatal-infos` clean.

**Gate-direction — two archetypes.** The right gate direction depends on whether the
old API still compiles on the new version.

- **Post-upgrade cleanup (`>=` gate).** Old API is *deprecated but still compiles*.
  The analyzer is silent, so the lint is the only nudge. Gate on the **new** major;
  flag lingering old-API usage. Matches `dio_5`, `riverpod_2`, `share_plus_11`,
  `sensors_plus_4`, `flutter_svg_2`. Highest value — the gap the compiler does not
  already cover.
- **Pre-upgrade readiness (`<` gate).** Old API is *removed* in the new major, so on
  the new version it does not compile and `dart analyze` already errors — a `>=` pack
  would find nothing. Gate on the **old** major instead; flag current (valid) code
  that will break on the bump, as opt-in upgrade prep. Used by `google_sign_in_7`,
  `webview_flutter_4`, `connectivity_plus_6`. Medium value, and depends on a
  maintainer decision to support `<` gates (a new archetype — all shipped gates are
  `>=`).

---

## Finish Report (2026-06-11)

Scope (LINTER variant): (A) Dart lint rules / analyzer plugin + (C) docs.

**Shipped.** flutter_svg_2 pack: prefer_svg_color_filter (migration, quick fix, SvgPicture-type-resolved) + 4 correctness rules (network/string errorBuilder, network placeholder, semantics label). Deferred svg_asset_not_precached (cross-file FP).

Rules marked DROP / defer in the 2026-06-11 VALIDATION notes were intentionally not implemented (duplicates, overlap with existing rules, or feasibility concerns). Every rule is import-gated via `fileImportsPackage`; migration rules are version-gated via `kRulePackDependencyGates` and relocated out of their base pack via `kRelocatedRulePackCodes` so a project on the old major never sees a rule for an API it lacks.

**Verification.** `dart analyze lib --fatal-infos` clean; `dart run tool/rule_pack_audit.dart` exit 0; full test suite green (1336 tests across test/integrity, test/config, test/rules/packages); registry regenerated twice + `dart format`. Rules authored by parallel subagents then serially registered into the shared files (tiers.dart, saropa_lints.dart, import_utils.dart, all_rules.dart, rule_packs.dart, generator + audit).

**Plan disposition.** Complete — archived to `plans/history/2026.06/2026.06.11/`.
