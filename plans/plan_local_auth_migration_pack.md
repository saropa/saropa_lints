# Plan: local_auth 3.0 migration rules (version-gated pack)

**Status:** active. Split out of `plan_local_auth.md` (the 5 always-on rules shipped
2026-06-11; see `plans/history/2026.06/2026.06.11/plan_local_auth.md`). These 4
migration rules need the semver rule-pack system AND the **`<`-gate archetype**,
which is not yet supported (all shipped gates are `>=`) and awaits a maintainer
decision — see `plan_migration_google_sign_in.md §5`. They were NOT shipped with the
correctness rules because their target symbols (`AuthenticationOptions`, `stickyAuth`,
`useErrorDialogs`, `PlatformException` catch) resolve only on local_auth **< 3.0**;
firing them on a 3.x project would be wrong (the symbols are gone / changed there).

**Package:** local_auth (2.x → 3.0 breaking changes).

## The 4 rules → pack `local_auth_3` (gate `local_auth < 3.0.0`, pre-upgrade readiness)

| rule_name | detects | fix | severity |
|---|---|---|---|
| `local_auth_deprecated_options_class` | `AuthenticationOptions(...)` construction (class removed in 3.0) | partial mechanical (promote fields to `authenticate()` named args) | WARNING |
| `local_auth_use_error_dialogs_removed` | `AuthenticationOptions(useErrorDialogs: ...)` (field removed; build own error UI) | report-only | ERROR |
| `local_auth_sticky_auth_renamed` | `stickyAuth:` (renamed to `persistAcrossBackgrounding`) | mechanical rename | WARNING |
| `local_auth_platform_exception_catch` | `on PlatformException` catch around an `authenticate()` (3.0 throws `LocalAuthException`) | mechanical (`PlatformException`→`LocalAuthException`) | WARNING |

Detection detail and library URIs are in the archived original plan §`local_auth_platform_exception_catch`
through §`local_auth_deprecated_options_class`. `AuthenticationOptions` /
`LocalAuthExceptionCode` resolve from
`package:local_auth_platform_interface/local_auth_platform_interface.dart`.

## Pack wiring (blocked on `<`-gate archetype decision)

```dart
// kRulePackDependencyGates (lib/src/config/rule_packs.dart)
'local_auth_3': RulePackDependencyGate(dependency: 'local_auth', constraint: '<3.0.0'),
// kRelocatedRulePackCodes (tool/rule_pack_audit.dart) — all 4 codes fromPack 'local_auth' toPack 'local_auth_3'
```

Plus the registry + title in `tool/generate_rule_pack_registry.dart`, regen ×2, format,
`rule_pack_audit` exit 0. **Prerequisite:** maintainer sign-off on the `<` (pre-upgrade)
gate archetype — shared blocker with `google_sign_in_7`, `connectivity_plus_6`,
`webview_flutter_4`, `app_links_6`.

## Sources

See `plans/history/2026.06/2026.06.11/plan_local_auth.md` § Sources.
