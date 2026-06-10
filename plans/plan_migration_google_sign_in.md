# Plan: `google_sign_in_7` migration pack

**Status:** ready to implement. **Value: MEDIUM** — the v7 break **removed** the
old API (`GoogleSignIn()` constructor, `signIn()`), so on v7 the old code does NOT
compile and `dart analyze` already errors. A *post-upgrade cleanup* pack would
find nothing. The useful framing is **pre-upgrade readiness**: gate on the **old**
major and flag v6 code that will break when the team bumps to v7.
**Gate type:** pre-upgrade readiness. **Gate:** `google_sign_in < 7.0.0`.
**Driving app:** Saropa Contacts ships `google_sign_in: ^7.2.0` — already migrated
(compiler-forced); this pack helps the general user base still on 6.x.

## 1. The migration (verified)

v7.0.0 is a major refactor for Android Credential Manager + modern Google Identity
Services:

| v6 (removed in v7) | v7 |
|---|---|
| `GoogleSignIn(scopes: [...])` constructor | `GoogleSignIn.instance` singleton + `await initialize()` |
| `signIn()` | `authenticate()` |
| `signInSilently()` | `attemptLightweightAuthentication()` |
| auth returns `accessToken` directly | authentication and **authorization** split — tokens via `authorizationClient` and explicit scope requests |

This is a **structural** change (required async `initialize()`, separated
auth/authorize), not a symbol rename — so it is **not mechanically auto-fixable**.

## 2. Rules (`lib/src/rules/packages/google_sign_in_rules.dart`, new file)

Single rule `avoid_pre_v7_google_sign_in` (report-only, no fix) with sub-detections:

- `GoogleSignIn(...)` constructor invocation (becomes the singleton in v7).
- `.signIn()` / `.signInSilently()` method calls on a `GoogleSignIn` instance.

**Detection (type-safe):** match on the element's library URI =
`package:google_sign_in`; verify the target's static type is `GoogleSignIn`. The
`signIn` name is generic — the type check is essential to avoid flagging unrelated
`.signIn()` methods.

**No fix.** The correctionMessage names the v7 replacement per call
(`GoogleSignIn()` → `GoogleSignIn.instance` + `initialize()`; `signIn()` →
`authenticate()`; access-token retrieval → `authorizationClient`) and links the
migration guide. Auto-rewriting the auth/authorize split would silently drop scope
handling — report-only is the correct, safe choice (do NOT ship an insert-TODO or
half fix per CLAUDE.md).

## 3. Wiring (recipe steps 2–6)

- `kRulePackDependencyGates`: `'google_sign_in_7': RulePackDependencyGate(dependency: 'google_sign_in', constraint: '<7.0.0')`
  — note the **`<`** constraint (pre-upgrade gate). Confirm `packPassesDependencyGate`
  handles `<` ranges; `pub_semver` `VersionConstraint.parse('<7.0.0')` does. Add a
  `test/config` case for the `<`-form if none exists.
- generator: `'google_sign_in_7': {'google_sign_in'}` + title `'google_sign_in 7.x (pre-upgrade)'`
- `kRelocatedRulePackCodes`: `'avoid_pre_v7_google_sign_in': (fromPack: 'google_sign_in', toPack: 'google_sign_in_7')`
- Regenerate (twice) + `dart format`.

## 4. Tests

- `test/config/rule_packs_google_sign_in_test.dart`: gate passes at 6.x, **fails at
  7.2.0** (already migrated) and when absent; ownership; merge override. This is the
  first `<`-constraint gate — assert the direction explicitly.
- `test/rules/packages/google_sign_in_rules_test.dart`: `GoogleSignIn(...)` and
  `.signIn()` trigger with the correct correctionMessage; an unrelated class with a
  `signIn()` method does NOT trigger.

## 5. Open decision (needs maintainer call)

The `<`-constraint "pre-upgrade readiness" gate is a **new pack archetype** (all
existing gates — `dio_5`, `riverpod_2` — are `>=` post-upgrade). Confirm the pack
system should support both directions before landing; if not, this pack is dropped
(low post-upgrade value). See [index §2 gate-direction note](plan_migration_packs_index.md#2-the-reusable-recipe-extracted-from-riverpod_2-and-dio_5).

## Sources

- [google_sign_in changelog](https://pub.dev/packages/google_sign_in/changelog)
- [Migration guide pre-7.0 → v7 (Adariku)](https://isaacadariku.medium.com/google-sign-in-flutter-migration-guide-pre-7-0-versions-to-v7-version-cdc9efd7f182)
- [v7 new auth flow (dev.to)](https://dev.to/_ashish_tandon_/flutter-google-sign-in-with-googlesignin-7-understanding-the-new-authentication-flow-2pbe)
