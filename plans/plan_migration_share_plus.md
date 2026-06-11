# Plan: `share_plus_11` migration pack

**Status:** ready to implement (exemplar — validates the
Build recipe section below).
**Gate:** `share_plus >= 11.0.0`.
**Driving app usage:** Saropa Contacts ships `share_plus: ^13.1.0`.

## 1. The migration (verified)

`share_plus` 11.0.0 introduced the instance-based `SharePlus` API and
**deprecated** the static `Share.*` methods. Old API still compiles (deprecated),
so projects accumulate silent migration debt — exactly what a gated lint pack is for.

| Old (deprecated in 11.0.0) | New |
|---|---|
| `Share.share(text, subject: s, sharePositionOrigin: r)` | `SharePlus.instance.share(ShareParams(text: text, subject: s, sharePositionOrigin: r))` |
| `Share.shareUri(uri)` | `SharePlus.instance.share(ShareParams(uri: uri))` |
| `Share.shareXFiles(files, text: t, subject: s)` | `SharePlus.instance.share(ShareParams(files: files, text: t, subject: s))` |

Notes:
- `ShareResult` is still the return type, so call sites awaiting a result need no
  result-handling change — only the call shape changes.
- `sharePositionOrigin` (iPad popover anchor) is carried straight through into
  `ShareParams`. The rule's fix MUST preserve it (dropping it regresses iPad).

## 2. Rules to add (`lib/src/rules/packages/share_plus_rules.dart`, new file)

| Rule code | Detects | Fix |
|---|---|---|
| `prefer_shareplus_instance_share` | `Share.share(...)` static call | Rewrite to `SharePlus.instance.share(ShareParams(text: <arg0>, ...named...))` |
| `prefer_shareplus_instance_share_uri` | `Share.shareUri(...)` | → `ShareParams(uri: ...)` |
| `prefer_shareplus_instance_share_files` | `Share.shareXFiles(...)` / legacy `Share.shareFiles(...)` | → `ShareParams(files: ...)` |

Single combined rule vs three: prefer **one** rule code
`prefer_shareplus_instance` with three sub-detections (one per static method), so
the pack has a single relocatable code — mirrors `dio_5`'s single
`avoid_dio_error`. The fix branches on which static method matched.

**Detection (type-safe, not string match):** match `MethodInvocation` where the
target's static type/element is the `Share` class from `package:share_plus`
(check the element's library URI, per CLAUDE.md anti-pattern guidance — do NOT
`name == 'Share'`). Guard against unrelated user classes named `Share`.

**Fix mechanics:** positional first arg of `Share.share`/`shareXFiles` maps to the
`text`/`files` named param of `ShareParams`; all existing named args
(`subject:`, `sharePositionOrigin:`) copy across unchanged. Where the call spans
the positional + named args, wrap them in `ShareParams(...)` and prefix
`SharePlus.instance.share(`. Skip the fix (report only) if the invocation uses an
argument form the rewriter cannot mechanically map (e.g. spread/await inside the
arg list that would change evaluation order).

## 3. Wiring (recipe steps 2–6)

- `kRulePackDependencyGates` (`lib/src/config/rule_packs.dart`):
  `'share_plus_11': RulePackDependencyGate(dependency: 'share_plus', constraint: '>=11.0.0')`
- `tool/generate_rule_pack_registry.dart`: add `'share_plus_11': {'share_plus'}`
  to the gate-dep map and `'share_plus_11': 'share_plus 11.x'` to the title map.
- `tool/rule_pack_audit.dart` `kRelocatedRulePackCodes`:
  `'prefer_shareplus_instance': (fromPack: 'share_plus', toPack: 'share_plus_11')`.
  (The `share_plus` base pack is created implicitly by the generator from the new
  `share_plus_rules.dart` file; the relocation moves the gated code into
  `share_plus_11`.)
- Regenerate (twice) + `dart format`.

## 4. Tests

- `test/config/rule_packs_share_plus_test.dart`: gate passes at 11.0.0 / 13.1.0,
  fails at 10.x and when share_plus absent; ownership = `prefer_shareplus_instance`
  is the sole member of `share_plus_11` and is NOT in the ungated `share_plus`
  pack; merge respects `diagnostics: false`.
- `test/rules/packages/share_plus_rules_test.dart`: each static form triggers;
  `SharePlus.instance.share(ShareParams(...))` does NOT trigger; the fix output
  for `Share.share('x', sharePositionOrigin: r)` preserves `sharePositionOrigin`.

## 5. Verify

`dart run tool/rule_pack_audit.dart` exit 0 (share_plus_11=1 member); new
`test/config` + `test/rules/packages` tests pass; `dart analyze --fatal-infos`
clean. Confirm behavior against real code with the scan CLI:
`dart run saropa_lints scan <dir> --tier comprehensive --format json`.

## Sources

- [share_plus on pub.dev](https://pub.dev/packages/share_plus)
- [share_plus changelog](https://pub.dev/packages/share_plus/changelog)
- [SharePlus API source](https://github.com/fluttercommunity/plus_plugins/blob/main/packages/share_plus/share_plus/lib/share_plus.dart)

---

## Correctness & best-practice rules (non-migration)

These rules target the new `SharePlus`/`ShareParams` API (≥11.0.0) — they fire on correct, non-deprecated call sites that still contain runtime footguns.

| rule_name (snake_case) | type | detects | quick-fix? | severity | FP guard |
|---|---|---|---|---|---|
| `share_plus_missing_position_origin` | correctness | `ShareParams(...)` constructed without `sharePositionOrigin` | No (requires widget context) | WARNING | skip when `Platform.isAndroid` or `Platform.isWindows` is the sole target; flag only when the library URI is `package:share_plus` |
| `share_plus_unawaited_share` | correctness | `SharePlus.instance.share(...)` call not wrapped in `await` / `unawaited(...)` | Yes — wrap with `await` | WARNING | skip if already inside `unawaited(...)` call |
| `share_plus_unchecked_result` | best-practice | `await SharePlus.instance.share(...)` where the `ShareResult` return value is discarded (expression statement) | No | INFO | skip if caller explicitly discards via `unawaited()` (not awaited at all — covered by prior rule) |
| `share_plus_empty_share_params` | correctness | `ShareParams` constructed with all content fields (`text`, `files`, `uri`) provably null or empty literal | Yes — remove the call | ERROR | only flag when ALL three fields are statically absent/null/empty; skip when any field is non-literal |
| `share_plus_uri_and_text_conflict` | correctness | `ShareParams(uri: ..., text: ...)` with both `uri` and `text` set to non-null values | Yes — remove one of the conflicting args | ERROR | only flag when both are provably non-null at the call site |

---

### `share_plus_missing_position_origin`

> **VALIDATION (2026-06-11) — GUARD NEEDED:** No real platform guard — fires on every Android/Web `ShareParams` omitting `sharePositionOrigin`. The "skip when Platform.isAndroid/isWindows is sole target" guard is aspirational, not specified detection. Add a concrete platform-conditional guard before ship.

**What/why:** On iPad, the iOS share sheet is presented as a popover; without a non-zero `sharePositionOrigin: Rect`, UIKit cannot anchor it and throws a `PlatformException` at runtime — the share sheet either never appears or the app crashes. On iOS 26+ (all devices), a zero-sized or absent `Rect` now also triggers a crash (`{0,0},{0,0} must be non-zero and within coordinate space of source view`), fixed at the package level in 12.0.1 for non-iPad, but the iPad requirement is unconditional for all versions. The pub.dev README states: "Without it, share_plus will not work on iPads and may cause a crash or leave the UI unresponsive."

**Detection (AST, type-safe):**
- Match `InstanceCreationExpression` whose static element resolves to `ShareParams` from library URI `package:share_plus/share_plus.dart` (or the barrel `package:share_plus`).
- Check that the argument list contains no named argument with label `sharePositionOrigin`.
- Do NOT match on the class name string `"ShareParams"` — resolve through the constructor element's enclosing library URI.

**Fix:** No automated fix — the correct `Rect` must be derived from `RenderBox.localToGlobal(Offset.zero) & size` on the triggering widget, which requires widget context the lint cannot supply. Report-only.

**False positives:**
- Android-only code paths where `sharePositionOrigin` has no effect (but it is harmless to pass it, so flagging still improves cross-platform resilience).
- Web targets where `sharePositionOrigin` is ignored — if the call site is gated behind a compile-time `kIsWeb` check, suppress (best-effort; INFO may be preferable to WARNING in mixed-platform projects).
- Severity choice: WARNING is appropriate because the crash is real and reproducible on iPads/iOS 26; downgrade to INFO only if the project's `analysis_options.yaml` targets Android/Web exclusively (speculative — verify against `ProjectContext.isFlutterProject` and target platform metadata).

---

### `share_plus_unawaited_share`

> **VALIDATION (2026-06-11) — DROP (overlap):** Substantially subsumed by `avoid_unawaited_future` (async_rules.dart:3297). Justify the package-specific Android second-`share()`-race delta (returns `unavailable` on overlap) as the unique value, or drop.

**What/why:** `SharePlus.instance.share()` returns `Future<ShareResult>`. On Android, a second `share()` call arriving while a prior call is still pending causes the first to return `ShareResultStatus.unavailable` with the message "prior share-sheet did not call back, did you await it?" (documented in the package source). Beyond that race condition, any caller that reacts to the share result (e.g. shows a toast on success) must await the future to observe the status. An unawaited call silently drops the result.

**Detection (AST, type-safe):**
- Match `MethodInvocation` nodes where the method name is `share`, the target resolves to an element whose enclosing type is `SharePlus` from library URI `package:share_plus`, AND the invocation is used as an `ExpressionStatement` (i.e. its value is discarded) without being the argument to `unawaited(...)`.
- Verify the return type of the resolved method element is `Future<ShareResult>` — do not rely on the name `share` alone.

**Fix:** Wrap the expression statement with `await `: change `SharePlus.instance.share(params);` → `await SharePlus.instance.share(params);`. The containing function must be `async`; if it is not, the fix is suppressed (report-only) because making a function async is a wider refactor.

**False positives:**
- Intentional fire-and-forget: the caller explicitly wraps with `unawaited(SharePlus.instance.share(...))` — this satisfies the lint and documents intent; do not flag.
- Test code where the future result is not relevant — suppress in test files via `ProjectContext.isTestFile`.

---

### `share_plus_unchecked_result`

**What/why:** Even when correctly awaited, the `ShareResult` is often thrown away: `await SharePlus.instance.share(params);` as an expression statement. The `ShareResultStatus` enum carries `success`, `dismissed`, and `unavailable`. Apps that show "shared successfully" toasts or trigger analytics without inspecting the result conflate `dismissed` and `success`, producing misleading UX. `unavailable` is returned on platforms (Android historically, Windows) that cannot identify the user's action — treating it as success silently swallows unknown outcomes.

**Detection (AST, type-safe):**
- Match `AwaitExpression` whose operand is a `MethodInvocation` resolving to `SharePlus.instance.share` (same library-URI check as above), where the entire `AwaitExpression` is used as an `ExpressionStatement` (result discarded).
- This is distinct from `share_plus_unawaited_share`: that rule catches missing `await`; this rule catches `await` present but result unused.

**Fix:** No automated fix — the correct handling depends on app logic (toast, analytics, navigation). Report-only at INFO so the caller can assess whether `ShareResultStatus` matters in that context.

**False positives:**
- Callers that genuinely do not care about the outcome (e.g., a share button with no post-share behavior). INFO severity keeps this advisory rather than blocking. The caller can suppress with `// ignore: share_plus_unchecked_result` and a one-line rationale per the project's ignore policy.

---

### `share_plus_empty_share_params`

**What/why:** `SharePlus.instance.share()` enforces at runtime: "at least one of uri, files, or text must be provided"; "text cannot be empty if provided"; "files cannot be empty if provided." Violations throw `ArgumentError` synchronously inside the `share()` call. A call site where ALL three content fields are statically absent, `null`, or empty string/list literals is a guaranteed runtime throw that a lint can catch at analysis time.

**Detection (AST, type-safe):**
- Match `InstanceCreationExpression` for `ShareParams` (same library-URI check).
- Inspect the named argument list:
  - `text` absent OR its expression is `StringLiteral` with value `""` (or `null` literal).
  - `files` absent OR its expression is `ListLiteral` with zero elements (or `null` literal).
  - `uri` absent OR its expression is `NullLiteral`.
- Only flag when ALL three conditions hold simultaneously — any non-trivially-null/non-empty field defeats the rule.
- Do NOT flag when any field is a variable, conditional, or non-literal expression (runtime value unknown).

**Fix:** Remove the enclosing `SharePlus.instance.share(...)` call (or the `ShareParams` construction). The fix is only safe when the `ShareParams` is directly and solely the argument to a `share()` call; if it is assigned to a variable used elsewhere, report-only.

**False positives:** Very low — the rule requires ALL content fields to be statically empty/null, which is rarely intentional. The main FP is a `ShareParams` constructed partially and then `copyWith`-ed before use; since `ShareParams` does not expose a `copyWith` in the public API (speculative — verify), this is unlikely. Flag only on literal-empty construction.

---

### `share_plus_uri_and_text_conflict`

> **VALIDATION (2026-06-11) — GUARD NEEDED:** A nullable-typed var guarded `!= null` upstream still FPs (static type stays nullable). Restricting to non-nullable-typed/literal operands removes that FP but weakens the rule to near-literals-only — note the trade-off in the plan and pick a side.

**What/why:** `ShareParams` enforces at runtime: "uri and text cannot be provided at the same time." Passing both throws `ArgumentError` synchronously. This is a constraint that cannot be expressed in Dart's type system but IS statically detectable when both arguments are provably non-null at the call site.

**Detection (AST, type-safe):**
- Match `InstanceCreationExpression` for `ShareParams` (library-URI check).
- Check that the argument list contains BOTH a named `uri:` argument whose expression is NOT a `NullLiteral` AND a named `text:` argument whose expression is NOT a `NullLiteral` AND NOT an empty `StringLiteral`.
- Resolving whether an expression is non-null: for literal values (non-null Uri literal, non-empty string literal) this is definitive; for variables, check `staticType` nullability (`DartType.nullabilitySuffix != NullabilitySuffix.question` is necessary but not sufficient — a non-nullable `String` could still be passed into `text`; flag it since any non-null `text` + any non-null `uri` is always an error).

**Fix:** Remove the `text:` named argument (prefer keeping `uri:` since the conflict is always resolved by dropping one; the fix message should name which was removed so the developer can reverse if needed). Only apply the fix when BOTH fields are literal values; otherwise report-only.

**False positives:**
- One field assigned a nullable typed variable: if `text` is `String?` and the developer guards `text != null` upstream, the lint fires but a runtime guard exists. Mitigate by only flagging when both fields are non-nullable-typed or string/Uri literals.
- Severity ERROR is appropriate: this is a guaranteed `ArgumentError` throw with no graceful fallback.

---

### Research sources

- [share_plus pub.dev README](https://pub.dev/packages/share_plus)
- [share_plus changelog](https://pub.dev/packages/share_plus/changelog)
- [Issue #3685: `share` fails on iOS 26 when `sharePositionOrigin` is zero](https://github.com/fluttercommunity/plus_plugins/issues/3685)
- [Issue #1640: `sharePositionOrigin` PlatformException on iPad](https://github.com/fluttercommunity/plus_plugins/issues/1640)
- [Issue #1001: No status when dismissing Android share sheet](https://github.com/fluttercommunity/plus_plugins/issues/1001)
- [Nathan Fox: Flutter share_plus crash on iOS 26 — the sharePositionOrigin fix](https://www.nathanfox.net/p/flutter-share_plus-crash-on-ios-26)

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
