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
