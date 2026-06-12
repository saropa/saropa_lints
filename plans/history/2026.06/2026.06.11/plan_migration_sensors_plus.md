# Plan: `sensors_plus_4` migration pack

**Status:** ready to implement. **Value: HIGH** — old API is **deprecated, still
compiles** (the analyzer is otherwise silent, so the lint is the only nudge).
**Gate type:** post-upgrade cleanup. **Gate:** `sensors_plus >= 4.0.0`.
**Driving app:** Saropa Contacts ships `sensors_plus: ^7.0.0` (no old-API calls
found — pack serves the general user base).

## 1. The migration (verified)

`sensors_plus` 4.0.0 deprecated the bare event-stream **getters** in favor of
**functions** that accept a `samplingPeriod`. The getters still compile, so usage
lingers silently.

| Old (deprecated 4.0.0, still compiles) | New |
|---|---|
| `accelerometerEvents` | `accelerometerEventStream()` |
| `userAccelerometerEvents` | `userAccelerometerEventStream()` |
| `gyroscopeEvents` | `gyroscopeEventStream()` |
| `magnetometerEvents` | `magnetometerEventStream()` |

The new functions optionally take `samplingPeriod: SensorInterval.normalInterval`
(or a `Duration`); the migration default (no arg) preserves prior behavior.

## 2. Rule (`lib/src/rules/packages/sensors_plus_rules.dart`, new file)

Single rule `prefer_sensors_event_stream` with four sub-detections (one per
getter). One relocatable code, mirroring `dio_5`.

**Detection:** match `SimpleIdentifier` / `PrefixedIdentifier` resolving to one of
the four deprecated top-level getters whose declaring element is in
`package:sensors_plus`. Type-check the element's library URI — do NOT match the
bare name (other libraries export similarly named symbols).

**Fix (mechanical):** replace the getter identifier with the function-call form,
e.g. `accelerometerEvents` → `accelerometerEventStream()`. Pure textual append of
`Stream()`/swap; no argument remapping. Always emit the no-arg form (behavior-
preserving). High-confidence fix.

## 3. Wiring (recipe steps 2–6; full recipe in the Build recipe section below)

- `kRulePackDependencyGates`: `'sensors_plus_4': RulePackDependencyGate(dependency: 'sensors_plus', constraint: '>=4.0.0')`
- `tool/generate_rule_pack_registry.dart`: `'sensors_plus_4': {'sensors_plus'}` + title `'sensors_plus 4.x'`
- `kRelocatedRulePackCodes`: `'prefer_sensors_event_stream': (fromPack: 'sensors_plus', toPack: 'sensors_plus_4')`
- Regenerate (twice) + `dart format`.

## 4. Tests

- `test/config/rule_packs_sensors_plus_test.dart`: gate passes 4.0.0 / 7.0.0,
  fails 3.x / absent; ownership = sole member of `sensors_plus_4`; merge respects
  `diagnostics: false`.
- `test/rules/packages/sensors_plus_rules_test.dart`: each getter triggers; the
  `*EventStream()` form does not; fix output replaces getter with function call.

## 5. Verify

`dart run tool/rule_pack_audit.dart` exit 0 (sensors_plus_4=1); tests pass;
`dart analyze --fatal-infos` clean.

## Sources

- [sensors_plus changelog](https://pub.dev/packages/sensors_plus/changelog)
- [sensors_plus 4.0.2 changelog](https://pub.dev/packages/sensors_plus/versions/4.0.2/changelog)
- [accelerometerEvents (deprecated) API doc](https://pub.dev/documentation/sensors_plus/latest/sensors_plus/accelerometerEvents.html)

---

## Correctness & best-practice rules (non-migration)

All rules below: library URI guard = `package:sensors_plus`; type-safe detection
only; no bare-name matching.

`SensorInterval` constants (verified from platform-interface source):

| Constant | Duration |
|---|---|
| `SensorInterval.normalInterval` | 200 ms (default when arg omitted) |
| `SensorInterval.uiInterval` | ~66.667 ms (≈15 Hz) |
| `SensorInterval.gameInterval` | 20 ms (50 Hz) |
| `SensorInterval.fastestInterval` | `Duration.zero` (hardware max) |

| rule_name (snake_case) | type | detects | quick-fix? | severity | FP guard |
|---|---|---|---|---|---|
| `sensors_plus_uncanceled_subscription` | correctness | `*EventStream().listen(…)` result not stored in a field that is canceled in `dispose()` | No | WARNING | result stored in a `StreamSubscription` field that is canceled elsewhere |
| `sensors_plus_no_sampling_period` | best-practice | call to `*EventStream()` with no `samplingPeriod` argument (inherits `normalInterval` default — but caller intent is invisible) | Yes — insert `samplingPeriod: SensorInterval.normalInterval` | INFO | call already passes any `samplingPeriod` arg |
| `sensors_plus_fastest_interval` | best-practice | `samplingPeriod: SensorInterval.fastestInterval` (hardware-max rate = max battery drain) | Yes — replace with `SensorInterval.gameInterval` | WARNING | none; every use of `fastestInterval` is suspect |
| `sensors_plus_listen_in_build` | correctness | `*EventStream().listen(…)` call inside an overridden `build()` method | No | ERROR | none; subscribing in `build()` always creates a new uncanceled subscription |
| `sensors_plus_missing_on_error` | best-practice | `.listen(…)` on a `*EventStream()` result with no `onError:` argument | Yes — insert `onError: (_) {}` stub with a `// TODO` note | INFO | listener already supplies `onError:` |

---

### `sensors_plus_uncanceled_subscription`

> **VALIDATION (2026-06-11) — DROP (overlap):** Covered by `avoid_unassigned_stream_subscriptions` (async_rules.dart:552) + `require_stream_subscription_cancel` (registered tiers.dart:493). The sensors-specific delta is battery framing only — not enough to justify a distinct rule. Drop or fold into correctionMessage of the general rules.

**What/why:** `*EventStream().listen(…)` hands back a `StreamSubscription`. If that
subscription is never canceled, the native sensor stack keeps running after the
widget/object is gone — draining the battery and leaking the callback closure.
Confirmed real issue: the official sensors_plus example was patched (
`setState() called after dispose()`) precisely because the subscription outlived
the widget.

**Detection:**
1. In `addMethodInvocation`, match any invocation whose static target type is
   `Stream<AccelerometerEvent>` / `Stream<GyroscopeEvent>` /
   `Stream<UserAccelerometerEvent>` / `Stream<MagnetometerEvent>` /
   `Stream<BarometerEvent>` **and** whose method name is `listen`.
2. Confirm the receiver came from a call to one of the five `*EventStream()`
   functions declared in `package:sensors_plus` (check the element's library URI).
3. Walk up to the enclosing `ClassDeclaration`. Search its fields for a
   `StreamSubscription<T>` field whose initializer or `initState`/constructor body
   captures the result of this `listen` call.
4. If no such field is found, report at the `listen` node.

**FP guard:** If the result IS stored in a `StreamSubscription` field — even if
that field is declared in a mixin or superclass — do not report; the cancel may
happen elsewhere (e.g. a `DisposableState` mixin). Only report the
definitive case where the return value is discarded (expression statement).

**Fix:** No safe mechanical fix — inserting `cancel()` in `dispose()` requires
knowledge of field name and dispose body shape. Emit a clear `correctionMessage`
directing the developer to store the result and call `cancel()` in `dispose()`.

**Severity:** WARNING.

---

### `sensors_plus_no_sampling_period`

**What/why:** All five `*EventStream()` functions default to
`SensorInterval.normalInterval` (200 ms) when `samplingPeriod` is omitted.
That is a safe default, but the omission makes intent invisible — a reviewer
cannot tell whether the developer chose 200 ms or simply forgot the parameter.
More importantly, if the intent was a slower interval (to save battery) the
omission silently defeats it. Emitting an INFO-level hint nudges callers to be
explicit.

**Detection:**
1. In `addMethodInvocation`, match calls to `accelerometerEventStream`,
   `userAccelerometerEventStream`, `gyroscopeEventStream`,
   `magnetometerEventStream`, `barometerEventStream` whose `element.library.uri`
   == `package:sensors_plus/sensors_plus.dart` (or the platform-interface URI).
2. Check `node.argumentList.arguments` — if no argument has `staticParameterElement`
   named `samplingPeriod`, report.

**Fix (mechanical):** Insert `samplingPeriod: SensorInterval.normalInterval` as a
named argument — preserves existing behavior, makes intent explicit.
High-confidence, zero behavior change.

**Severity:** INFO.

---

### `sensors_plus_fastest_interval`

> **VALIDATION (2026-06-11) — GUARD NEEDED:** "FP guard: none" is an assertion, not a fact — legitimate hardware-calibration / benchmark code uses `fastestInterval` deliberately and fires at WARNING. Add a guard (e.g. INFO severity, or skip when a nearby `// calibration`/`// benchmark` intent comment is present) before ship.

**What/why:** `SensorInterval.fastestInterval` is `Duration.zero` — it requests
the hardware's maximum delivery rate with no throttling. On Android this maps to
`SENSOR_DELAY_FASTEST` (Android Sensors docs: "as fast as possible"). This burns
the battery at maximum sensor rate and is almost never the right choice outside
of specialized hardware-calibration or benchmarking code.

**Detection:**
1. In `addNamedExpression`, match the named argument `samplingPeriod:` on any of
   the five `*EventStream()` calls (library URI guard as above).
2. Resolve the argument's static value: if it is a reference to the static const
   `SensorInterval.fastestInterval` (element's enclosing class is `SensorInterval`
   in `package:sensors_plus_platform_interface`), report at the named expression.

**Fix (mechanical):** Replace `SensorInterval.fastestInterval` with
`SensorInterval.gameInterval`. This is a behavior change (20 ms vs 0 ms) so the
priority should be lower (60) and the message must note it.

**Severity:** WARNING.

---

### `sensors_plus_listen_in_build`

> **VALIDATION (2026-06-11) — RECONCILE:** Partial overlap with `avoid_stream_in_build` (tiers.dart:530) — a `*EventStream().listen()` in `build()` is the same shape that rule already targets. Confirm the general rule's scope and reconcile (sub-detect under it, or drop) before adding a sensors-specific variant.

**What/why:** `build()` is called on every frame repaint, every `setState`, and
every parent rebuild. Calling `*EventStream().listen(…)` inside `build()` creates
a fresh native sensor subscription on every rebuild. Those subscriptions pile up
(none are canceled), each firing callbacks into the same widget — producing
duplicate events, spurious `setState()` calls, and compounding battery drain.

**Detection:**
1. In `addMethodInvocation`, match `listen` on a sensors-plus stream type (same
   type guard as rule 1).
2. Walk ancestors: find the nearest `MethodDeclaration` whose name is `build` and
   which overrides a Flutter `Widget.build` (check `element.isOverride` and that
   the enclosing class extends/implements `State` or `StatelessWidget` from
   `package:flutter`).
3. If the `listen` call is a descendant of that `build` body, report.

**FP guard:** None — there is no legitimate reason to open a sensor subscription
inside `build()`.

**Fix:** No mechanical fix; the correctionMessage instructs the developer to move
the subscription to `initState()` and cancel it in `dispose()`.

**Severity:** ERROR.

---

### `sensors_plus_missing_on_error`

> **VALIDATION (2026-06-11) — FIX (quick-fix ban):** The fix inserts `onError: (_) {}` + a `// TODO` — an empty no-op swallow plus a TODO is the spirit of the banned TODO-insert fix (it silences the stream error rather than handling it). Make the fix insert a meaningful handler, or make the rule report-only.

**What/why:** The official README states: "Some low-end or old Android devices
don't have all sensors available … it is highly recommended to add `onError()`."
Without `onError:`, an unavailable sensor delivers an unhandled platform exception
that surfaces as an uncaught stream error — either crashing the app or silently
swallowing the error depending on the zone. The README example pairs
`onError: (error) { … }` with `cancelOnError: true`.

**Detection:**
1. In `addMethodInvocation`, match `.listen(…)` on sensors-plus stream types
   (same type guard).
2. Inspect `node.argumentList.arguments` for a `NamedExpression` with name
   `onError`. If absent, report at the `listen` node.

**Fix (mechanical — limited):** Insert `onError: (_) {},` as a named argument.
The stub is intentionally minimal; a `// TODO: handle sensor unavailable` comment
is inserted rather than a silent swallow. This satisfies the "no TODO-only fix"
rule because real code (a valid `onError` closure) is inserted; the comment is
supplementary guidance, not the entire fix.

**Severity:** INFO.

---

## Sources (correctness/best-practice rules)

- [sensors_plus README — usage & onError guidance](https://github.com/fluttercommunity/plus_plugins/blob/main/packages/sensors_plus/sensors_plus/README.md)
- [SensorInterval source — Duration values](https://github.com/fluttercommunity/plus_plugins/blob/main/packages/sensors_plus/sensors_plus_platform_interface/lib/src/sensor_interval.dart)
- [Android Sensors Overview — SENSOR_DELAY_* constants](https://developer.android.com/develop/sensors-and-location/sensors/sensors_overview)
- [sensors_plus stream function signatures](https://github.com/fluttercommunity/plus_plugins/blob/main/packages/sensors_plus/sensors_plus/lib/src/sensors.dart)
- [Flutter issue #125849 — dispose() / StreamSubscription.cancel() async](https://github.com/flutter/flutter/issues/125849)
- [plus_plugins issue #956 — sensor stream exception on app terminate](https://github.com/fluttercommunity/plus_plugins/issues/956)

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

**Shipped.** sensors_plus_4 pack: prefer_sensors_event_stream (migration, quick fix) + 3 best-practice rules (no_sampling_period, fastest_interval, missing_on_error). Dropped sensors_plus_uncanceled_subscription and sensors_plus_listen_in_build (overlap).

Rules marked DROP / defer in the 2026-06-11 VALIDATION notes were intentionally not implemented (duplicates, overlap with existing rules, or feasibility concerns). Every rule is import-gated via `fileImportsPackage`; migration rules are version-gated via `kRulePackDependencyGates` and relocated out of their base pack via `kRelocatedRulePackCodes` so a project on the old major never sees a rule for an API it lacks.

**Verification.** `dart analyze lib --fatal-infos` clean; `dart run tool/rule_pack_audit.dart` exit 0; full test suite green (1336 tests across test/integrity, test/config, test/rules/packages); registry regenerated twice + `dart format`. Rules authored by parallel subagents then serially registered into the shared files (tiers.dart, saropa_lints.dart, import_utils.dart, all_rules.dart, rule_packs.dart, generator + audit).

**Plan disposition.** Complete — archived to `plans/history/2026.06/2026.06.11/`.
