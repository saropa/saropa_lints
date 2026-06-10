# Plan: `webview_flutter_4` migration pack

**Status:** ready to implement. **Value: MEDIUM** — v4 **removed** the `WebView`
widget, so on v4 old code does NOT compile (analyzer already errors). Useful
framing is **pre-upgrade readiness**: gate on the old major, flag v3 code that
breaks on the v4 bump. **Gate type:** pre-upgrade readiness.
**Gate:** `webview_flutter < 4.0.0`. **Driving app:** Saropa Contacts ships
`webview_flutter: ^4.13.1` — already migrated; pack serves users still on 3.x.

## 1. The migration (verified)

v4.0.0 removed the monolithic `WebView` widget and split it into:

| v3 (removed in v4) | v4 |
|---|---|
| `WebView(initialUrl: ..., onWebViewCreated: (c) {...})` | `WebViewController` (loadRequest, setBackgroundColor, clearCache, …) + `WebViewWidget(controller: c)` |
| `WebViewController` callback methods | controller created up front, passed to `WebViewWidget` |
| platform-specifics inline | `*.fromPlatformCreationParams(...)` constructors |

Structural (controller is built then handed to the widget) — **not mechanically
auto-fixable**.

## 2. Rule (`lib/src/rules/packages/webview_flutter_rules.dart`, new file)

Single rule `avoid_pre_v4_webview_widget` (report-only).

**Detection (type-safe):** `InstanceCreationExpression` whose type is `WebView`
from `package:webview_flutter`. Type-check the constructor element's library URI —
`WebView` is a common name; never match by identifier alone.

**No fix.** correctionMessage: "`WebView` is removed in webview_flutter 4.0 — build
a `WebViewController` and render `WebViewWidget(controller: …)`." Links the v4
migration doc. The controller-extraction rewrite is not safe to automate.

## 3. Wiring (recipe steps 2–6)

- `kRulePackDependencyGates`: `'webview_flutter_4': RulePackDependencyGate(dependency: 'webview_flutter', constraint: '<4.0.0')` (pre-upgrade `<` gate — same archetype as `google_sign_in_7`)
- generator: `'webview_flutter_4': {'webview_flutter'}` + title `'webview_flutter 4.x (pre-upgrade)'`
- `kRelocatedRulePackCodes`: `'avoid_pre_v4_webview_widget': (fromPack: 'webview_flutter', toPack: 'webview_flutter_4')`
- Regenerate (twice) + `dart format`.

## 4. Tests

- `test/config/rule_packs_webview_flutter_test.dart`: gate passes 3.x, fails 4.13.1
  / absent; ownership; merge.
- `test/rules/packages/webview_flutter_rules_test.dart`: `WebView(...)` triggers;
  `WebViewWidget(...)` does not; unrelated `WebView` class does not.

## 5. Depends on

The `<`-constraint gate archetype decision in
[plan_migration_google_sign_in.md §5](plan_migration_google_sign_in.md#5-open-decision-needs-maintainer-call).
If pre-upgrade gates are rejected, drop this pack.

## Sources

- [webview_flutter changelog](https://pub.dev/packages/webview_flutter/changelog)
- [V4 migration doc issue #117299](https://github.com/flutter/flutter/issues/117299)
