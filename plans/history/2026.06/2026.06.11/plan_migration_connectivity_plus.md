# Plan: `connectivity_plus_6` migration pack

**Status:** ready to implement. **Value: MEDIUM** — v6 changed the **return type**
of `checkConnectivity()` / `onConnectivityChanged` from a single
`ConnectivityResult` to `List<ConnectivityResult>`. On v6 the old single-value
code is a **type error** (analyzer already flags it). Useful framing is
**pre-upgrade readiness**: gate on the old major, flag v5 single-value handling
that breaks on the v6 bump — the partial mechanical fix (`== X` → `.contains(X)`)
is genuinely helpful here. **Gate type:** pre-upgrade readiness.
**Gate:** `connectivity_plus < 6.0.0`. **Driving app:** Saropa Contacts ships
`connectivity_plus: ^7.1.1` — already migrated; pack serves users still on 5.x.

## 1. The migration (verified)

v6.0.0 added simultaneous multi-connectivity support, changing the shape:

```dart
// v5 (breaks on v6 — single value)
final ConnectivityResult r = await Connectivity().checkConnectivity();
if (r == ConnectivityResult.none) { ... }
Connectivity().onConnectivityChanged.listen((ConnectivityResult r) { ... });

// v6
final List<ConnectivityResult> r = await Connectivity().checkConnectivity();
if (r.contains(ConnectivityResult.none)) { ... }
Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> r) { ... });
```

## 2. Rule (`lib/src/rules/packages/connectivity_plus_rules.dart`, new file)

Single rule `avoid_pre_v6_single_connectivity_result`.

**Detection (type-safe):** flag where the value returned from
`Connectivity().checkConnectivity()` or the `onConnectivityChanged` stream element
is treated as a single `ConnectivityResult` — specifically:
- a binary `==` / `!=` expression with `ConnectivityResult` operand whose other
  operand is the connectivity result, or
- a variable typed `ConnectivityResult` (not `List<…>`) assigned from those APIs,
- a `.listen((ConnectivityResult x) …)` whose param is typed single.

Resolve via element library URI = `package:connectivity_plus`.

**Fix (partial, mechanical for the common case):** `r == ConnectivityResult.x` →
`r.contains(ConnectivityResult.x)` and `r != X` → `!r.contains(X)`. For the typed-
variable and stream-param cases, report-only (changing the declared type is not a
safe local rewrite) with a correctionMessage describing the `List` shape.

## 3. Wiring (recipe steps 2–6)

- `kRulePackDependencyGates`: `'connectivity_plus_6': RulePackDependencyGate(dependency: 'connectivity_plus', constraint: '<6.0.0')` (pre-upgrade `<` gate)
- generator: `'connectivity_plus_6': {'connectivity_plus'}` + title `'connectivity_plus 6.x (pre-upgrade)'`
- `kRelocatedRulePackCodes`: `'avoid_pre_v6_single_connectivity_result': (fromPack: 'connectivity_plus', toPack: 'connectivity_plus_6')`
- Regenerate (twice) + `dart format`.

## 4. Tests

- `test/config/rule_packs_connectivity_plus_test.dart`: gate passes 5.x, fails
  7.1.1 / absent; ownership; merge.
- `test/rules/packages/connectivity_plus_rules_test.dart`: `r == ConnectivityResult.none`
  on a checkConnectivity result triggers + fix → `.contains`; `.contains(...)`
  form does not trigger; an unrelated `== SomeEnum.x` does not trigger.

## 5. Depends on

`<`-constraint gate archetype decision in
[plan_migration_google_sign_in.md §5](plan_migration_google_sign_in.md#5-open-decision-needs-maintainer-call).

## Sources

- [connectivity_plus changelog](https://pub.dev/packages/connectivity_plus/changelog)
- [connectivity_plus on pub.dev](https://pub.dev/packages/connectivity_plus)

---

## Correctness & best-practice rules (non-migration)

Target: `connectivity_plus ^6.0.0` / `^7.x`. Detection is always type-safe via
library URI `package:connectivity_plus`; bare name matching is never used.

| rule_name (snake_case) | type | detects | quick-fix? | severity |
|---|---|---|---|---|
| `connectivity_result_not_reachability` | correctness | non-`none` result used as a network-reachability gate before an HTTP/Dio/http call | no | INFO |
| `connectivity_subscription_not_canceled` | resource-leak | `onConnectivityChanged.listen(…)` result neither assigned to a field nor canceled in a `dispose()`-equivalent | no | WARNING |
| `connectivity_satellite_missing` | completeness | `switch` / `if-else` chain over `ConnectivityResult` values that handles every value except `satellite` (added v7.1.0) | yes (add branch) | WARNING |

---

### `connectivity_result_not_reachability`

> **VALIDATION (2026-06-11) — DROP (duplicate):** `avoid_connectivity_equals_internet` (connectivity_rules.dart:158) has the verbatim same threat model (captive portal / VPN / transport-layer ≠ reachability); also conceptually overlaps `prefer_internet_connection_checker` (connectivity_rules.dart:373). Do NOT add.

**What / why.** The `connectivity_plus` README states explicitly: *"You should not rely on
the current connectivity status to decide whether you can reliably make a network request."*
A non-`none` `ConnectivityResult` only means a network interface is active; a captive-portal
WiFi, a VPN with split-tunnel, or a cellular interface with no route all return non-`none`
while no actual internet request will succeed. Code that gates a remote call purely on this
check gives false confidence and silently fails under those conditions.

**Detection (AST, type-safe).** Look for an `if` condition (or ternary / `&&` chain) that:

1. Reads from a variable or expression whose static type is `List<ConnectivityResult>` — the
   return type of `Connectivity().checkConnectivity()` (resolved via the element's library URI
   `package:connectivity_plus`) — or the stream event type of `onConnectivityChanged`.
2. The condition is a reachability-positive test: `.contains(ConnectivityResult.wifi)`,
   `.contains(ConnectivityResult.mobile)`, `!result.contains(ConnectivityResult.none)`, etc.
   (i.e., concludes "we are online").
3. The `then`-branch body contains an `await` expression whose callee resolves to a known
   HTTP surface: `http.get`, `http.post`, `Dio().get`, `Dio().post`, `HttpClient.getUrl`,
   `dio.fetch`, or any method on a type whose library URI starts with
   `package:http` / `package:dio` / `dart:io HttpClient`.

All three points must be true in the same lexical scope. Resolve `ConnectivityResult` via its
enclosing library URI — never match on the bare name.

**Fix.** No automated fix: the correct guard depends on the caller's architecture (try/catch
with timeout, a real reachability probe, or an `internet_connection_checker_plus` gate). The
`correctionMessage` reads: *"Guard against network timeouts and errors instead; a non-none
ConnectivityResult does not confirm internet access (captive portals, VPN split-tunnel, etc.)."*

**False positives.** Two legitimate patterns must be exempted:

- *Offline-banner / UI state.* Code that updates a `bool _isOffline` field or a
  `ValueNotifier<bool>` from the connectivity result without immediately firing a network
  call. Detection point 3 (HTTP callee in the then-branch) naturally excludes these.
- *Wifi-only preference.* Code that gates wifi-only download logic on
  `result.contains(ConnectivityResult.wifi)` — the intent is interface selection, not
  reachability. Heuristic: if the then-branch does not contain an HTTP callee, no lint is
  raised. This keeps the rule scoped to the headline footgun.

**Severity: INFO** — the pattern is common and often produces working code on well-configured
networks; the lint is advisory, not a hard error.

---

### `connectivity_subscription_not_canceled`

> **VALIDATION (2026-06-11) — DROP (duplicate):** `require_connectivity_subscription_cancel` (api_network_rules.dart:2368) already detects uncanceled `onConnectivityChanged.listen()`. Do NOT add.

**What / why.** `Connectivity().onConnectivityChanged` is an infinite broadcast stream.
Calling `.listen(…)` without storing the returned `StreamSubscription` and canceling it
creates a permanent listener that retains the enclosing widget/object and fires callbacks
after the object is disposed. The `connectivity_plus` README shows the disposal pattern
explicitly and notes *"Be sure to cancel subscription after you are done."*

**Detection (AST, type-safe).** Inside a class body, locate every expression statement of the
form `<expr>.listen(<callback>)` where `<expr>` has static type
`Stream<List<ConnectivityResult>>` and the enclosing class element is resolved to
`package:connectivity_plus`. Two sub-cases trigger the lint:

1. **Unassigned call.** The `.listen(…)` result is not assigned to any variable or field
   (i.e., the call is a bare expression statement, not the RHS of an assignment).
2. **Assigned but never canceled.** The `StreamSubscription` is stored in a field, but that
   field's `.cancel()` is never called in any method named `dispose`, `close`, `onClose`,
   `_dispose`, or `deactivate` within the same class.

Resolve the receiver type via its element's library URI; never match on the bare name
`onConnectivityChanged`.

**Fix.** No automated fix (correct disposal shape depends on whether the class is a
`StatefulWidget`, a `ChangeNotifier`, a Riverpod `Notifier`, etc.). The `correctionMessage`
reads: *"Store the StreamSubscription and call .cancel() in dispose() to prevent listener
leaks after the object is discarded."*

**False positives.**

- Cancellation via a `CompositeSubscription` or `_subscriptions.add(…)` helper: if the
  `.listen(…)` result is passed to any method call in the same class, treat it as managed
  and suppress the lint.
- Top-level / `main()` listeners: outside a class body, permanent listeners are often
  intentional (app-lifetime streams); do not lint these.

**Severity: WARNING** — a leaked stream subscription is a real memory/behavior bug, not
merely a style issue.

---

### `connectivity_satellite_missing`

> **VALIDATION (2026-06-11) — FEASIBILITY + FIX:** May be redundant with Dart 3's built-in switch-exhaustiveness checker — exhaustive `ConnectivityResult` switches already error at the SDK level, leaving only non-exhaustive if-else chains. Gate so it fires only where the analyzer would NOT already report. Also the fix inserts a `case ...satellite:` branch with a `// TODO` body — review against the TODO-fix ban (the branch is structural, but a TODO-only body is the weak spot).

**What / why.** `ConnectivityResult.satellite` was added in `connectivity_plus` v7.1.0
(verified in changelog). Code written against v6 that exhaustively switches over
`ConnectivityResult` values silently falls through the `satellite` case on v7.1+ devices,
potentially misclassifying a satellite connection as "unknown" or hitting an `assert(false)`
default branch.

**Detection (AST, type-safe).** Find any `switch` statement or expression, or any `if-else`
chain, that:

1. Switches/tests on a value whose static type is `ConnectivityResult` (single value from
   a destructured `List<ConnectivityResult>` element, or from a `.first` / `.last` call, or
   from a typed parameter in `.map((r) => …)`).
2. Covers at least three of the eight documented enum values (`wifi`, `bluetooth`,
   `ethernet`, `mobile`, `vpn`, `other`, `none`, `satellite`) — i.e., looks like an
   exhaustive enumeration rather than a single targeted check.
3. Does NOT include a case for `ConnectivityResult.satellite`.

Resolve `ConnectivityResult` via its enclosing library URI.

**Fix (yes — add missing branch).** The quick fix inserts a `case ConnectivityResult.satellite:`
branch immediately before the `default:` / `else` branch, or as the last case if no default
exists, with a `// TODO: handle satellite connectivity` body. This is a real structural fix
(adds a branch), not a TODO-only insert — the branch itself is the structural change; the
TODO inside it is the caller's decision on behavior.

*(Speculative — verify: if the analyzer's exhaustiveness checker already catches missing enum
cases for sealed/exhaustive switches in Dart 3, this rule may overlap with a built-in
diagnostic. Gate the rule so it only fires when the switch is non-exhaustive by the
analyzer's own judgment, i.e., when the static checker would not already report an error.)*

**False positives.**

- Switches that explicitly handle only a subset (e.g., `wifi` vs everything-else) — covered
  by detection point 2 (require ≥3 covered values before flagging).
- Code gated on `connectivity_plus < 7.1.0` in pubspec: if the project's pubspec constraint
  excludes v7.1+, `satellite` is unreachable and no lint is raised.

**Severity: WARNING.**

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

**Shipped.** connectivity_plus_6 pre-upgrade (<6) pack: avoid_pre_v6_single_connectivity_result (migration, partial quick fix) + connectivity_satellite_missing. Dropped connectivity_result_not_reachability and connectivity_subscription_not_canceled (duplicates).

Rules marked DROP / defer in the 2026-06-11 VALIDATION notes were intentionally not implemented (duplicates, overlap with existing rules, or feasibility concerns) — that triage is honored, not skipped. Every rule is import-gated via `fileImportsPackage`; migration rules are version-gated via `kRulePackDependencyGates` and relocated out of their base pack via `kRelocatedRulePackCodes` so a project on the old major never sees a rule for an API it lacks.

**Verification.** `dart analyze lib --fatal-infos` clean; `dart run tool/rule_pack_audit.dart` exit 0; full test suite green (1336 tests across test/integrity, test/config, test/rules/packages); registry regenerated twice + `dart format`. Rules authored by parallel subagents then serially registered into the shared files (tiers.dart, saropa_lints.dart, import_utils.dart, all_rules.dart, rule_packs.dart, generator + audit).

**Plan disposition.** Complete — archived to `plans/history/2026.06/2026.06.11/`.
