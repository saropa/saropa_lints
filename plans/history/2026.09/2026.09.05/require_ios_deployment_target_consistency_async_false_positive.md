# Fix: iOS substring-match false positives on data-literal strings

`RequireIosDeploymentTargetConsistencyRule` fired on every `SimpleStringLiteral` whose value contained the substring `async` — including Dart rule-name strings like `'avoid_async_call_in_sync_function'` in config/data files. The root cause was a bare `'async': 'iOS 15+ (Swift concurrency)'` entry in the rule's `_ios15PlusApis` map, matched via `.contains()`.

## Finish Report (2026-09-05)

### Phase 1 — Remove the `async` entry

**Changed file:** `lib/src/rules/platforms/ios_platform_lifecycle_rules.dart`
- Removed `'async': 'iOS 15+ (Swift concurrency)'` from `_ios15PlusApis` const map.
- Added a comment explaining why the entry was removed and what a future re-implementation would need.

### Phase 2 — Shared `isDataLiteralElement` guard

An audit of all iOS rules that use `addSimpleStringLiteral` with `.contains()` revealed a systemic risk: any rule whose keyword list contains a short or common substring can false-positive on string literals inside collection literals (rule-name sets, route catalogs, path inventories, migration-code maps).

The private `_isDataLiteralElement` method from `AvoidIosHardcodedDeviceModelRule` was extracted into `literal_context_utils.dart` as the public `isDataLiteralElement()` function. The guard was then applied to 6 rules:

| Rule | Risk keywords | File |
|------|--------------|------|
| `AvoidIos13DeprecationsRule` | iOS API names (low risk, but no guards existed) | `ios_platform_lifecycle_rules.dart` |
| `AvoidIosSimulatorOnlyCodeRule` | `/tmp/`, `localhost:` | `ios_platform_lifecycle_rules.dart` |
| `RequireIosMinimumVersionCheckRule` | iOS API names (low risk, but no guards existed) | `ios_platform_lifecycle_rules.dart` |
| `AvoidIosDeprecatedUikitRule` | `keyWindow` etc. (low risk, but no guards existed) | `ios_platform_lifecycle_rules.dart` |
| `RequireIosDeploymentTargetConsistencyRule` | `AttributedString` | `ios_platform_lifecycle_rules.dart` |
| `RequireIosCertificatePinningRule` | `/auth`, `/login`, `/health` (HIGH risk) | `ios_ui_security_rules.dart` |

`AvoidIosHardcodedDeviceModelRule` was updated to call the shared utility instead of its private copy.

**Test status:** All 179 iOS rule tests pass. All 4 literal_context_utils tests pass.

**Changelog:** Two entries added under `### Fixed` in the `[16.0.0-beta.3] — Unreleased` section.
