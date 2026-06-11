# Plan: new `app_links` lint rules

**Package:** app_links ^7.1.1 (Saropa Contacts). **saropa_lints coverage:** none (new file).
**Status:** research complete — ready to implement.
**Related index entry:** [plan_migration_plugin_system.md §3](plan_migration_plugin_system.md) — listed as P2 candidate `app_links_6`.

---

## Background

`app_links` is the Flutter deep-link handler for Android App Links, iOS Universal Links,
and custom URL schemes (desktop included). It replaces the unmaintained `uni_links`.

**Verified v7.1.1 public surface** (from Dart API docs + source):

```
AppLinks()                        // factory singleton
getInitialLink()    → Future<Uri?>
getInitialLinkString() → Future<String?>
getLatestLink()     → Future<Uri?>
getLatestLinkString() → Future<String?>
uriLinkStream       → Stream<Uri>    // broadcast; initial + subsequent links
stringLinkStream    → Stream<String> // broadcast; initial + subsequent links
```

No `enabled` flag is part of the public method surface (it is an iOS-native
initialization option, not a Dart API). No deprecated members remain in v7 — all
renames were completed in v6.

---

## Proposed rules

| rule_name (snake_case) | type | detects | quick-fix? | severity | FP guard |
|---|---|---|---|---|---|
| `app_links_subscription_not_canceled` | correctness | `uriLinkStream.listen()`/`stringLinkStream.listen()` result stored but never `.cancel()`-ed in `dispose()` | report-only | WARNING | subscription stored in a non-`State` class or already canceled elsewhere |
> **VALIDATION (2026-06-11) — DROP (overlap):** covered by `require_stream_subscription_cancel` (disposal_rules.dart:1147) + `avoid_unassigned_stream_subscriptions` (async_rules.dart:552). Keep only if it adds value beyond package-specific messaging.
| `app_links_missing_initial_link` | correctness | `uriLinkStream.listen()` present but no `getInitialLink()` call in same class/file | WARNING | report-only | `getInitialLink` is called in a parent/service class |
> **VALIDATION (2026-06-11) — GUARD NEEDED / OBSOLETE:** premise partly obsolete on v6+ (stream covers cold start); systematic FP. Reconsider value.
| `app_links_uncaught_stream_error` | best-practice | `.listen()` on `uriLinkStream`/`stringLinkStream` with no `onError:` argument | INFO | mechanical fix | — |
> **VALIDATION (2026-06-11) — FIX (quick-fix ban):** the fix inserts an `onError:` handler whose BODY is a `// TODO` comment — trips the project's "no insert-TODO quick fixes" ban. Change to a real handler (e.g. a logging call) or report-only.
| `app_links_late_initialization` | best-practice | `AppLinks()` or stream `.listen()` inside `build()` | WARNING | report-only | — |
| `app_links_avoid_get_initial_link_string` | best-practice | use of `getInitialLinkString()`/`stringLinkStream` — prefers `Uri` surface | INFO | mechanical fix (swap to Uri variant) | intentional string usage for logging |
| `app_links_use_get_initial_link` | migration (v5→v6) | call to `getInitialAppLink()` (removed in v6) | ERROR | mechanical fix | — |
| `app_links_use_uri_link_stream` | migration (v5→v6) | reference to `allUriLinkStream` or `allStringLinkStream` (removed in v6) | ERROR | mechanical fix | — |
| `app_links_use_get_latest_link` | migration (v5→v6) | call to `getLatestAppLink()` (removed in v6) | ERROR | mechanical fix | — |
> **VALIDATION (2026-06-11) — NOTE:** the three `_use_*` migration rules target symbols removed in v6; route via `app_links < 6.0.0` pack gate (first `<`-gate archetype, awaits maintainer decision).

---

## Rule detail

### app_links_subscription_not_canceled

- **What/why:** Calling `appLinks.uriLinkStream.listen(...)` (or `stringLinkStream.listen(...)`)
  and not canceling the returned `StreamSubscription` when the widget or service is
  disposed creates a memory leak. The broadcast stream lives for the app's lifetime;
  the subscriber callback fires even after the `State` is unmounted, potentially
  triggering navigation on a disposed widget or accumulating closures in long sessions.
  This is the single most common `app_links` misuse pattern identified across
  tutorials and issue trackers.

- **Detection (AST, type-safe):**
  1. Match `MethodInvocation` where the target's `staticType` has library URI
     `package:app_links/app_links.dart` (the `AppLinks` class) and the method name
     is `uriLinkStream` or `stringLinkStream` — these are getters, so the full
     expression is `<AppLinks_instance>.uriLinkStream.listen(...)`.
  2. Actually: the `.listen()` call is on the `Stream<Uri>` / `Stream<String>`
     returned by those getters. Match `MethodInvocation` where `methodName ==
     'listen'` and the target expression (`realTarget`) is a `PropertyAccess` or
     `PrefixedIdentifier` whose getter name is `uriLinkStream` or
     `stringLinkStream`, and resolve the receiver's static type library URI to
     `package:app_links/app_links.dart`.
  3. Confirm the invocation result (a `StreamSubscription`) is assigned to a field
     (store the field element). Walk the enclosing class's `dispose()` method body;
     if no `MethodInvocation` of `cancel` whose target references that same field
     is found, report.

- **Fix:** Report-only. The fix requires inserting a `cancel()` call inside
  `dispose()`, which may not exist yet; the correct insertion point is too
  context-dependent for a safe mechanical rewrite. The diagnostic message must name
  the exact stream and suggest adding `_subscription?.cancel()` in `dispose()`.

- **False positives:**
  - The subscription may be held by an ancestor `ChangeNotifier`, a Riverpod
    `Ref`-lifecycle hook, or a `GetxController`'s `onClose()`. Guard: only report
    when the enclosing class is a `State<T>` subclass (check the `ClassDeclaration`
    supertype chain for `State`) OR when the result is assigned to a field and no
    `cancel()` call on that field is detectable anywhere in the class. Accept the
    residual FP for service classes that cancel via a foreign lifecycle — users can
    suppress with `// ignore: app_links_subscription_not_canceled` per project
    rules.

---

### app_links_missing_initial_link

- **What/why:** Subscribing to `uriLinkStream` handles links received while the app
  is running (warm start) but NOT the link that cold-started the app. A cold-start
  deep link must be retrieved with `getInitialLink()` (returns a `Future<Uri?>`).
  Missing this call means the app ignores the link that the user tapped to open it.
  Note: prior to v6, `uriLinkStream` did NOT include the initial link; from v6
  onwards the stream covers both, so calling `getInitialLink()` is technically
  optional on v6+. However, many tutorials still call both for clarity and
  belt-and-suspenders reliability, and the official README still recommends it.
  Flag at INFO severity to raise awareness without blocking.

- **Detection (AST, type-safe):**
  1. Within a `ClassDeclaration`, detect that `uriLinkStream.listen(...)` is called
     (per the stream-detection pattern above).
  2. Search the same class for any `MethodInvocation` whose `methodName` is
     `getInitialLink` and whose receiver's static type library URI is
     `package:app_links/app_links.dart`.
  3. If step 1 matches and step 2 finds nothing, report on the `.listen()` call site.

- **Fix:** Report-only. Calling `getInitialLink()` with correct routing logic is
  user-authored; a mechanical insertion would produce broken code.

- **False positives:**
  - `getInitialLink()` may be called in a separate service/repository class loaded
    before the widget. Guard: if the detection scope is broadened to the whole file
    (not just the class), the FP rate drops. Alternatively, keep class-scoped
    detection but document the FP in the rule's correction message so users can
    suppress when they handle the initial link in a service layer.

---

### app_links_uncaught_stream_error

- **What/why:** `Stream.listen()` without an `onError:` callback lets stream errors
  bubble to the `Zone`'s unhandled error handler, which in release builds may
  silently swallow errors or crash the app. Network errors, malformed URIs, or
  platform channel failures can all surface as stream errors on `uriLinkStream`.
  Adding `onError:` ensures graceful degradation.

- **Detection (AST, type-safe):**
  Match `MethodInvocation` with `methodName == 'listen'` on a target whose static
  type's library URI is `package:app_links/app_links.dart` (via the `Stream<Uri>`
  type check — the element's enclosing library is the app_links package). Check that
  the argument list contains no named argument named `onError`.

- **Fix:** Mechanical. Insert `, onError: (Object error, StackTrace stack) {
  // TODO: handle error — e.g. log or ignore }` as a trailing named argument. The
  inserted handler is a reporting-ready stub (not a TODO-insert-only fix — it
  provides a compilable, meaningful `onError` signature the developer refines).
  Priority 70.

- **False positives:** None significant. A `.listen()` call that already uses
  `.handleError()` chained before `.listen()` would be a FP; guard by checking for
  a `.handleError()` method call on the immediate target expression.

---

### app_links_late_initialization

- **What/why:** Creating `AppLinks()` or calling `.uriLinkStream.listen()` inside a
  widget's `build()` method creates a new subscription on every rebuild, leaking
  subscriptions and potentially firing the deep-link callback many times. The
  official README and every guide explicitly states: "instantiate `AppLinks` early
  in your app to catch the very first link when the app is in cold state."
  Initialization belongs in `initState()`, a constructor, or `main()`.

- **Detection (AST, type-safe):**
  1. Match `InstanceCreationExpression` where the constructor's static type has
     library URI `package:app_links/app_links.dart` and class name `AppLinks`.
  2. OR match `uriLinkStream.listen(...)` / `stringLinkStream.listen(...)` (per
     stream-detection pattern).
  3. Confirm the enclosing method is named `build` inside a class whose supertype
     chain includes `Widget` or `State`.

- **Fix:** Report-only. Moving initialization out of `build()` requires the developer
  to choose `initState()` vs a service vs `main()`; the correct target is
  context-dependent.

- **False positives:** A `build()` method that is NOT a Flutter `build(BuildContext)`
  override. Guard: check the method signature is `Widget build(BuildContext context)`
  by verifying the return type is `Widget` and the single parameter type is
  `BuildContext`.

---

### app_links_avoid_get_initial_link_string

- **What/why:** `getInitialLinkString()` / `stringLinkStream` return raw `String`
  URLs that callers must parse themselves, reintroducing `Uri.parse()` failure modes.
  The `Uri`-based API (`getInitialLink()` / `uriLinkStream`) returns a
  pre-validated `Uri?` and is the recommended surface. Using the string API is an
  unnecessary footgun.

- **Detection (AST, type-safe):**
  Match `MethodInvocation` where `methodName` is `getInitialLinkString` or
  `getLatestLinkString`, receiver static type library URI ==
  `package:app_links/app_links.dart`. Also match property access `stringLinkStream`
  on an `AppLinks` instance.

- **Fix:** Mechanical for `getInitialLinkString` → `getInitialLink` (and likewise
  `getLatestLinkString` → `getLatestLink`). For `stringLinkStream` → `uriLinkStream`,
  report-only because the callback type changes from `String` to `Uri`.

- **False positives:** Intentional string usage for logging/analytics. INFO severity
  limits noise; users can suppress per-call.

---

### app_links_use_get_initial_link (migration v5→v6)

- **What/why:** `getInitialAppLink()` was renamed to `getInitialLink()` in v6.0.0
  and removed entirely. Code still referencing the old name fails to compile on v6+.
  This is a **pre-upgrade readiness** (`<` gate archetype) rule — it flags old-API
  calls while the project is still on v5.x, before the upgrade breaks the build.

- **Detection (AST, type-safe):**
  Match `MethodInvocation` where `methodName` == `getInitialAppLink` and the
  receiver's static type has library URI `package:app_links/app_links.dart`. On
  v6+ the symbol is gone, so resolution returns null — the gate ensures this rule
  only runs on `app_links < 6.0.0`.

- **Fix:** Mechanical. Replace `getInitialAppLink(` with `getInitialLink(`.
  The return type (`Future<Uri?>`) and call shape are identical. Priority 90.

- **False positives:** None — the symbol is unique to `app_links`.

---

### app_links_use_uri_link_stream (migration v5→v6)

- **What/why:** `allUriLinkStream` and `allStringLinkStream` were renamed to
  `uriLinkStream` and `stringLinkStream` in v6.0.0. Same pre-upgrade gate as above.

- **Detection (AST, type-safe):**
  Match `PropertyAccess` or `PrefixedIdentifier` where the property name is
  `allUriLinkStream` or `allStringLinkStream` and the receiver's static type has
  library URI `package:app_links/app_links.dart`.

- **Fix:** Mechanical. Replace `allUriLinkStream` → `uriLinkStream` and
  `allStringLinkStream` → `stringLinkStream`. Priority 90.

- **False positives:** None — names are unique to `app_links`.

---

### app_links_use_get_latest_link (migration v5→v6)

- **What/why:** `getLatestAppLink()` / `getLatestAppLinkString()` were renamed to
  `getLatestLink()` / `getLatestLinkString()` in v6.0.0. Same pre-upgrade gate.

- **Detection (AST, type-safe):**
  Match `MethodInvocation` where `methodName` is `getLatestAppLink` or
  `getLatestAppLinkString`, receiver static type library URI ==
  `package:app_links/app_links.dart`.

- **Fix:** Mechanical. Replace `getLatestAppLink(` → `getLatestLink(` and
  `getLatestAppLinkString(` → `getLatestLinkString(`. Priority 90.

- **False positives:** None.

---

## Not lint-able (omitted)

- **Initialization before `runApp()`** — the `main()` call order relative to
  `runApp()` is detectable in principle but too error-prone to flag without
  significant FP risk (async gaps, service locators, deferred initialization all
  confound analysis).
- **Duplicate initial-link handling** (calling `getInitialLink()` AND relying on
  `uriLinkStream` for the same cold-start event on v6+) — behavioral, not structural.
  v6 changelog notes the stream no longer re-sends the initial link on re-subscribe,
  so this is mostly self-corrected.
- **`enabled` flag misuse** — the `enabled` flag (added in v7.0.0) is an iOS
  native-side initialization option, not a Dart method; not AST-detectable.
- **Missing platform setup** (AndroidManifest intent filters, iOS Info.plist
  Associated Domains) — file-system/config checks, outside the Dart AST surface.

---

## Implementation note

**New file:** `lib/src/rules/packages/app_links_rules.dart`

**Registration checklist (ALL three steps required — see MEMORY.md):**
1. Rule classes in `lib/src/rules/packages/app_links_rules.dart`
2. `_allRuleFactories` in `lib/saropa_lints.dart` — add `AppLinksXxxRule.new` for
   each rule
3. Tier assignments in `lib/src/tiers.dart`:
   - Correctness rules (`app_links_subscription_not_canceled`,
     `app_links_missing_initial_link`, `app_links_late_initialization`) →
     `recommendedOnlyRules`
   - Best-practice rules (`app_links_uncaught_stream_error`,
     `app_links_avoid_get_initial_link_string`) → `professionalOnlyRules`
   - Migration rules (the three `_use_*` rules) → gated pack (see below)

**Migration pack wiring** (following [plan_migration_plugin_system.md §2 recipe](plan_migration_plugin_system.md)):
- Gate archetype: **pre-upgrade `<` gate** (`app_links < 6.0.0`) — the renamed
  symbols are fully removed in v6, so on v6+ they do not compile and `dart analyze`
  already errors. The gate ensures the rules only activate on `app_links ^5.x`,
  where the old names still compile.
- `kRulePackDependencyGates` entry:
  `'app_links_6': RulePackDependencyGate(dependency: 'app_links', constraint: '<6.0.0')`
- `tool/generate_rule_pack_registry.dart` gate-dep map: add `'app_links_6':
  {'app_links'}` and title `'app_links_6': 'app_links 6.x migration'`.
- `kRelocatedRulePackCodes` in `tool/rule_pack_audit.dart`: one entry per migration
  rule code → `(fromPack: 'app_links', toPack: 'app_links_6')`.
- Regenerate: `dart run tool/generate_rule_pack_registry.dart`, then `dart format`.

**Note:** this is the first `<`-gate (pre-upgrade) pack in the codebase. The
`plan_migration_plugin_system.md` §4 notes this archetype awaits a maintainer
decision. Implementing `app_links_6` would also serve as the reference for the
other pending Tier B packs (`google_sign_in_7`, `connectivity_plus_6`,
`webview_flutter_4`).

---

## Rejection log (speculative rules omitted)

| Candidate | Reason omitted |
|---|---|
| Warn on `Uri.parse(string)` after `getInitialLinkString()` | Too broad — `Uri.parse` is general Dart, not app_links-specific |
| Require `WidgetsFlutterBinding.ensureInitialized()` before `AppLinks()` | Already flagged by other saropa_lints rules; out of scope |
| Warn on missing navigation guard after deep link | Runtime-only concern, not AST-detectable |
| Warn on Android `launchMode` not set to `singleTop` | AndroidManifest attribute check, not Dart AST |

---

## Sources

- [app_links pub.dev page](https://pub.dev/packages/app_links)
- [app_links changelog](https://pub.dev/packages/app_links/changelog)
- [AppLinks class Dart API docs](https://pub.dev/documentation/app_links/latest/app_links/AppLinks-class.html)
- [app_links source: app_links.dart](https://raw.githubusercontent.com/llfbandit/app_links/master/app_links/lib/src/app_links.dart)
- [llfbandit/app_links GitHub](https://github.com/llfbandit/app_links)
- [app_links example main.dart](https://pub.dev/packages/app_links/example)
- [Flutter deep-linking guide — dev.to](https://dev.to/ankushppie/flutter-deep-linking-complete-guide-for-android-app-links-ios-universal-links-4kde)
- [FlutterFlow issue #3223 — getInitialAppLink removed in v6](https://github.com/FlutterFlow/flutterflow-issues/issues/3223)
- [supabase-flutter issue #941 — getInitialAppLink NoSuchMethodError](https://github.com/supabase/supabase-flutter/issues/941)
