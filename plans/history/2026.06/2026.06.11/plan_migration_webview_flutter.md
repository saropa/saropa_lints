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

---

## Correctness, best-practice & security rules (v4 usage, non-migration)

These rules target `webview_flutter ^4.0.0` usage patterns — no migration gate needed. All
detection is type-safe against the library URI `package:webview_flutter`; bare-name matching
is prohibited.

| rule_name | type | detects | quick-fix? | severity | FP guard |
|---|---|---|---|---|---|
| `webview_flutter_unrestricted_js` | security | `setJavaScriptMode(JavaScriptMode.unrestricted)` with no NavigationDelegate gating remote content | no (architectural) | WARNING | first-party-only content is legitimate; framed as WARNING not ERROR |
| `webview_flutter_missing_navigation_delegate` | security/correctness | `WebViewController` built without `setNavigationDelegate(...)` call before `loadRequest`/`loadHtmlString` | no (structural) | WARNING | pure local-HTML views with no links have no uncontrolled-nav risk |
| `webview_flutter_javascript_channel_no_origin_comment` | security | `addJavaScriptChannel(...)` call with no adjacent `// origin:` or documented allow-list comment | no | INFO | channels whose source is first-party controlled HTML do not need external origin checking |
| `webview_flutter_cleartext_load_request` | security | `loadRequest(Uri.parse('http://...'))` — non-TLS URI literal passed to `loadRequest` | yes (rewrite scheme) | WARNING | localhost / 127.0.0.1 / `::1` URIs are exempt (dev/test use) |
| `webview_flutter_wildcard_post_message` | security | (speculative — verify) `postWebMessage` called with target-origin `*` | no | WARNING | n/a |

> **VALIDATION (2026-06-11) — FEASIBILITY (drop pending verification):** `postWebMessage` lives in platform-specific packages (`webview_flutter_android` / `webview_flutter_wkwebview`), not the cross-platform surface — likely NOT detectable from `package:webview_flutter` code. Drop unless verification proves it is statically reachable.

> **Note on rule 5 (`webview_flutter_wildcard_post_message`):** `postWebMessage` is a
> platform-channel level API exposed via `webview_flutter_android` / `webview_flutter_wkwebview`
> platform implementations, not the cross-platform `WebViewController` surface.
> Detectability from shared Dart code is speculative — verify before implementing.
> The remaining four rules are statically detectable from the common `package:webview_flutter` API.

---

### `webview_flutter_unrestricted_js`

> **VALIDATION (2026-06-11) — RECONCILE (overlap):** `avoid_webview_javascript_enabled` (security_network_input_rules.dart:322, constructor-arg form) + `prefer_webview_javascript_disabled` (security_network_input_rules.dart:2855, `..setJavaScriptMode(JavaScriptMode.unrestricted)` cascade form) already partly cover this. Reconcile (extend the cascade-form rule) or drop.

**What / why:** Calling `controller.setJavaScriptMode(JavaScriptMode.unrestricted)` enables
JavaScript execution across all content loaded into the WebView. When the WebView also loads
remote or third-party URLs (i.e., not assets or known first-party origins), this is an XSS
surface: any cross-site script in the loaded page can read app-level storage, invoke
`JavaScriptChannel` handlers, and exfiltrate data through the channel callbacks.
JavaScript is disabled by default in `WebViewController`; opting into unrestricted mode is a
deliberate, high-impact decision that warrants a lint prompt to confirm the intent is safe.

**Detection (AST, type-safe):**
- Visit `MethodInvocation` nodes.
- Target method name: `setJavaScriptMode`.
- Confirm the receiver's static type is `WebViewController` from
  `package:webview_flutter/webview_flutter.dart` (check
  `element.library.uri.toString().startsWith('package:webview_flutter')`).
- Confirm the single positional argument resolves to the enum value
  `JavaScriptMode.unrestricted` — check `element.name == 'unrestricted'` on the
  `PropertyAccessExpression`'s static element; never match by string.
- Report at the argument node.

**Fix:** No automated fix — the correct response is architectural (add a `NavigationDelegate`
that allows only known-good origins, or restrict to first-party assets). A TODO-insert fix is
prohibited per project rules.

**False positives:** First-party web apps loaded entirely from `flutter_assets` or from a
controlled single domain legitimately need JavaScript. Frame as WARNING (not ERROR) so teams
with intentional first-party WebViews are not blocked. The correction message should instruct
developers to pair with a `NavigationDelegate` that allows only their own origin.

**OWASP:** [MASVS-PLATFORM-2 / M6:Insecure Authorization] — unrestricted JS in a WebView
loading uncontrolled URLs is a privilege-escalation vector for in-app script injection.

---

### `webview_flutter_missing_navigation_delegate`

> **VALIDATION (2026-06-11) — DROP (duplicate):** `require_webview_navigation_delegate` (widget_patterns_require_rules.dart:1944) explicitly covers webview_flutter 4.0+ and tracks `setNavigationDelegate` per-controller (security_auth_storage_rules.dart:3160). Do NOT add.

**What / why:** A `WebViewController` with no `setNavigationDelegate(...)` call follows all
navigation decisions made by the page itself — any link click, redirect, or injected
`window.location` assignment navigates the WebView to an arbitrary URL. The user sees no
address bar and has no way to verify the destination, creating a phishing surface (documented
in flutter/flutter#137576 as a recommended mandatory guard). Android's native WebView defaults
to handing navigation off to the system browser (visible address bar, user context); Flutter's
`WebViewWidget` keeps it in-app by default, removing the user's only verification mechanism.

**Detection (AST, type-safe):**
- Visit `VariableDeclaration` or `FieldDeclaration` whose initializer is
  `InstanceCreationExpression` constructing `WebViewController` from
  `package:webview_flutter`.
- Scan the enclosing class or function body (the same cascade chain or subsequent statements)
  for a `MethodInvocation` named `setNavigationDelegate` on the same controller variable.
- If no such call exists before any `loadRequest` / `loadHtmlString` / `loadFlutterAsset`
  call on that controller, report on the `WebViewController()` construction.
- **Limit scope to the same syntactic block** to avoid cross-function false positives where
  the delegate is set in a different lifecycle method; mark those cases as out-of-scope (INFO)
  rather than WARNING.

**Fix:** No automated fix — the delegate implementation requires domain-specific allow-list
logic the linter cannot generate.

**False positives:** A WebView that only ever loads `loadFlutterAsset` with no external links
in the HTML is not a navigation-control risk. The detection should suppress (or downgrade to
INFO) when **all** load calls on the controller are `loadFlutterAsset` only.

**OWASP:** [MASVS-PLATFORM-3 / M4:Insufficient Input/Output Validation] — uncontrolled
in-app navigation bypasses OS-level URL visibility and phishing protection.

---

### `webview_flutter_javascript_channel_no_origin_comment`

> **VALIDATION (2026-06-11) — GUARD NEEDED:** Detection is "look 3 lines back for a comment containing `origin:`" — comment-presence linting, trivially defeated and false-triggered, and it never inspects `onMessageReceived`. Weak signal even at INFO; strengthen the detection or drop.

**What / why:** `WebViewController.addJavaScriptChannel(name, onMessageReceived: ...)` wires a
named Dart callback that any JavaScript running in the WebView can invoke by calling
`channelName.postMessage(...)`. Unlike `postMessage` on the web platform, there is no built-in
origin parameter — the callback receives a `JavaScriptMessage` containing only the message
string, with no information about which frame or origin sent it (confirmed by the Android
WebView platform docs: "no mechanism for the application to verify the origin of the calling
frame"). If the WebView loads third-party content or is vulnerable to XSS, any script can
invoke the channel and trigger native Dart code with attacker-controlled input.

The rule does not attempt to detect whether origin checking is implemented (that logic is in
`onMessageReceived` and is not statically inspectable). Instead it flags the absence of an
explicit origin-acknowledgment comment adjacent to the call, following the pattern used by
`IgnoreUtils` for intent-signaling. This keeps the signal lightweight (INFO) while forcing
authors to consciously record their threat-model decision at the call site.

**Detection (AST, type-safe):**
- Visit `MethodInvocation` named `addJavaScriptChannel` on a receiver typed
  `WebViewController` from `package:webview_flutter`.
- Check the preceding line(s) (up to 3 lines back via source offset comparison) for a comment
  containing `origin:` or `trusted-only` (case-insensitive). Use `CommentUtils` from
  `lib/src/comment_utils.dart`.
- If no such marker is found, report INFO at the method name token.

**Fix:** No automated fix — insert-TODO is prohibited. The correction message should state:
"Add a comment documenting the trusted origin (e.g. `// origin: first-party assets only`) or
validate the message source inside `onMessageReceived`."

**False positives:** Channels whose backing HTML is 100% first-party (Flutter assets) with
JavaScript not accepting external input are low-risk. The INFO severity means this does not
block CI; it surfaces a review prompt.

**OWASP:** [MASVS-PLATFORM-2] — unguarded native bridges are the primary escalation path for
WebView-based privilege attacks; mirrors the Android `addJavascriptInterface` risk class.

---

### `webview_flutter_cleartext_load_request`

> **VALIDATION (2026-06-11) — DROP (duplicate):** `require_https_only` / `checkHttpUrls` (security_network_input_rules.dart:3664) flags any `'http://'` literal with the SAME localhost/127.0.0.1/::1 exemptions; `loadRequest(Uri.parse('http://...'))` already trips it. Do NOT add.

**What / why:** `WebViewController.loadRequest(Uri.parse('http://...'))` loads content over an
unencrypted HTTP connection. The WebView renders this content with full page-trust: scripts
execute under `JavaScriptMode.unrestricted` if set, `JavaScriptChannel` handlers respond to
any script, and any network-path attacker can inject content or redirect the page. Both Android
(`android:usesCleartextTraffic="false"`) and iOS (App Transport Security) provide OS-level
cleartext blocks, but those are manifest/plist settings outside Dart code — a cleartext URI
literal in Dart is the upstream mistake and is statically detectable.

**Detection (AST, type-safe):**
- Visit `MethodInvocation` named `loadRequest` on a receiver typed `WebViewController` from
  `package:webview_flutter`.
- Inspect the first positional argument. If it is a `MethodInvocation` of `Uri.parse` (from
  `dart:core`) whose single argument is a `StringLiteral`, extract the string value.
- Report if the scheme is `http` (case-insensitive) AND the host is not `localhost`,
  `127.0.0.1`, or `::1`.
- Also visit `MethodInvocation` of `Uri` constructors (`Uri(scheme: 'http', ...)`) and check
  the named `scheme` argument similarly.

**Fix (yes — rewrite scheme):** A `ChangeBuilder` replacing `'http://'` with `'https://'` in
the string literal is safe and reversible. Priority 80. Message: "Use HTTPS to prevent
cleartext traffic interception."

**False positives:** `localhost` / `127.0.0.1` / `::1` are dev/test endpoints and are
explicitly exempt. Dynamic URIs (runtime-constructed `Uri` variables) are not detectable
statically — the rule only catches literal strings, so the false-positive rate on live URIs
computed at runtime is zero.

**OWASP:** [MASVS-NETWORK-1 / M3:Insecure Communication] — cleartext HTTP is the canonical
TLS-bypass vector; CWE-319 (Cleartext Transmission of Sensitive Information).

---

### Sources for this section

- [webview_flutter pub.dev README / API](https://pub.dev/packages/webview_flutter)
- [webview_flutter API — addJavaScriptChannel](https://pub.dev/documentation/webview_flutter/latest/webview_flutter/WebViewController/addJavaScriptChannel.html)
- [webview_flutter API — loadRequest](https://pub.dev/documentation/webview_flutter/latest/webview_flutter/WebViewController/loadRequest.html)
- [flutter/flutter#137576 — Make NavigationDelegate mandatory](https://github.com/flutter/flutter/issues/137576)
- [Android WebView native bridges security (developer.android.com)](https://developer.android.com/privacy-and-security/risks/insecure-webview-native-bridges)
- [Android WebView security checklist — Oversecured](https://oversecured.com/blog/android-security-checklist-webview)
- [Flutter network policy / cleartext breaking change](https://docs.flutter.dev/release/breaking-changes/network-policy-ios-android)
- OWASP MASVS-PLATFORM, MASVS-NETWORK-1

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

**Shipped.** webview_flutter pack (whole-gated <4): avoid_pre_v4_webview_widget. The 5 correctness rules were all dropped per validation (duplicates / overlap / feasibility), so the pre-upgrade migration rule ships alone.

Rules marked DROP / defer in the 2026-06-11 VALIDATION notes were intentionally not implemented (duplicates, overlap with existing rules, or feasibility concerns) — that triage is honored, not skipped. Every rule is import-gated via `fileImportsPackage`; migration rules are version-gated via `kRulePackDependencyGates` and relocated out of their base pack via `kRelocatedRulePackCodes` so a project on the old major never sees a rule for an API it lacks.

**Verification.** `dart analyze lib --fatal-infos` clean; `dart run tool/rule_pack_audit.dart` exit 0; full test suite green (1336 tests across test/integrity, test/config, test/rules/packages); registry regenerated twice + `dart format`. Rules authored by parallel subagents then serially registered into the shared files (tiers.dart, saropa_lints.dart, import_utils.dart, all_rules.dart, rule_packs.dart, generator + audit).

**Plan disposition.** Complete — archived to `plans/history/2026.06/2026.06.11/`.
