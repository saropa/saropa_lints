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

## 3. Wiring (recipe steps 2–6, see [index §2](plan_migration_packs_index.md#2-the-reusable-recipe-extracted-from-riverpod_2-and-dio_5))

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
