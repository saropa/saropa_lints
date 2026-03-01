# Discussion 062: Full Review — Reducing False Positives in saropa_lints

**Status:** Living document  
**Created:** 2026-03-01  
**Purpose:** Actionable review of how to reduce false positive occurrence across 1677+ rules.

### Completed (2026-03-01)

- **Documentation:** Full review doc (this file); links added in CONTRIBUTING.md and CLAUDE.md; "Reducing False Positives" section added to `.claude/skills/lint-rules/SKILL.md`.
- **Phase 1 (disposal_rules):** Replaced all `disposeBody.contains('$name.dispose(')` / `$field.close()` / `$field.cancel()` / etc. with `isFieldCleanedUp()` from `target_matcher_utils`. Rules updated: `require_media_player_dispose`, `require_tab_controller_dispose`, `require_receive_port_close`, `require_socket_close`, `require_debouncer_cancel`, `require_interval_timer_cancel`, `require_file_handle_close`. CI baseline for `disposal_rules.dart` reduced in `test/anti_pattern_detection_test.dart`.
- **Phase 2 (partial):** **navigation_rules:** `avoid_deep_link_sensitive_params`, `prefer_typed_route_params` — replaced `targetSource.contains('queryParameters'|'pathSegments'|'pathParameters')` with exact property name via `_indexTargetPropertyOrName()`. **api_network_rules:** `require_http_status_check` — replaced `bodySource.contains('http.get')` etc. with word-boundary regex; **require_retry_logic** — word-boundary regex for http/dio/client and retry/maxRetries. CI baselines reduced.
- **Phase 2 (batch 2):** **provider_rules:** `avoid_provider_for_single_value` — exact set for Proxy/Multi; `prefer_selector_over_single_watch` — regex for `.select(`; `avoid_provider_value_rebuild` — `endsWith('Provider')`. **permission_rules:** `require_location_permission_rationale` — `_rationalePatterns`; `require_camera_permission_check` — `_cameraCheckPatterns`; `prefer_image_cropping` — word-boundary for cropper/crop/ImageCropper/cropImage. Baselines: permission_rules 20→1, provider_rules 3→1, api_network_rules 133→126.
- **Phase 2 (batch 3):** **permission_rules:** `prefer_image_cropping` — `_profileContextKeywordPatterns` (word-boundary) for profile context. **api_network_rules:** `require_connectivity_check` — `_connectivityHttpPatterns`/`_connectivityCheckPatterns`; `require_request_timeout` — `_timeoutConfigPatterns`. **async_rules:** `require_feature_flag_default` — `_remoteConfigTargetNames` + `extractTargetName`; DateTime UTC — regex for `.toUtc()`/`.utc`; stream/controller rules — `extractTargetName` + `endsWith('stream'|'controller')`. Baselines: api_network 126→114, async 59→50; permission_rules removed (0).
- **Phase 2 (batch 4):** **widget_lifecycle_rules:** `require_scroll_controller_dispose`, `require_focus_node_dispose` — iteration disposal uses regex instead of `disposeBody.contains('.dispose()')`. **api_network_rules:** `prefer_http_connection_reuse`, `avoid_redundant_requests`, `require_response_caching`, `prefer_api_pagination` — word-boundary regex for client/cache/pagination patterns. Baselines: api_network 114→75, widget_lifecycle 18→16, async 50→47.
- **Phase 2 (batch 5):** **api_network_rules:** `require_offline_indicator`, `prefer_streaming_response`, `avoid_over_fetching`, `require_cancel_token` — word-boundary regex for connectivity, file context, over-fetch heuristics, cancel/mounted checks. Baseline: api_network 75→51.
- **Phase 3 batch:** **animation_rules:** `require_animation_controller_dispose` — dispose check uses `isFieldCleanedUp(name, 'dispose', disposeMethodBody)` from `target_matcher_utils`. **async_rules:** `require_stream_controller_close` — `.close()`/`.dispose()` via regex; `avoid_stream_subscription_in_field` — exact StreamSubscription type + `_subscriptionVarNames`/`endsWith('Subscription')`; `require_stream_subscription_no_leak` — `startsWith('StreamSubscription')`; shared `_isStreamSubscriptionType()` helper.
- **Next batch:** Remaining bodySource/targetSource/classSource.contains in api_network_rules (~51).

---

## 1. Executive Summary

False positives erode trust in lints: developers learn to ignore warnings or blanket-suppress with `// ignore:`, defeating the purpose of the package. This review consolidates **root causes**, **existing safeguards**, and **concrete actions** to reduce occurrence.

**Key takeaways:**
- **#1 cause:** Heuristic/string-based detection (especially `.contains()` on names/source). The project already has an audit, CI guard, and shared utilities to combat this.
- **High-impact gaps:** Context-aware rules (callbacks vs build body), trusted-source recognition (platform paths), and framework-aware semantics (e.g. `SegmentedButton.onSelectionChanged` non-empty set) need more systematic handling.
- **Process:** Every new or modified rule should pass a false-positive checklist and, where heuristics are unavoidable, document known edge cases and use word-boundary/exact-match patterns.

---

## 2. Current State — What’s Already in Place

### 2.1 Documentation and Guidance

| Resource | Purpose |
|----------|---------|
| [CONTRIBUTING.md § Avoiding False Positives](../../CONTRIBUTING.md) | Anti-patterns table, lessons learned (e.g. `avoid_double_for_money`), “What TO do” table, pre-implementation questions |
| [CLAUDE.md](../../CLAUDE.md) | Anti-patterns: string matching for types, assuming parent types, manual project-level queries; recommends type checks and `ProjectContext` |
| [string_contains_false_positive_audit.md](../history/false_positives/string_contains_false_positive_audit.md) | Audit of 121+ `.contains()` usages, severity, remediation patterns (exact set, type check, AST, import check), phased plan, completed fixes |
| [false_positives_kykto.md](../history/false_positives_kykto.md) | Real-world false positives from a consumer project: path sanitization, `ref.read` in callbacks, collection methods, guard clauses, etc. |

### 2.2 Code and CI Safeguards

| Mechanism | Role |
|-----------|------|
| **`lib/src/target_matcher_utils.dart`** | `extractTargetName`, `isExactTarget`, `isFieldCleanedUp`, `hasChainedMethod` — replace substring/body-source checks with exact or AST-based checks |
| **`lib/src/import_utils.dart`** | `fileImportsPackage`, `PackageImports.*` — restrict package-specific rules to files that actually import the package |
| **`ProjectContext`** | Package use, platform, test-file detection — avoid running rules in irrelevant contexts |
| **`test/anti_pattern_detection_test.dart`** | CI guard: fails if any rule file *increases* its count of dangerous `.contains()` patterns (baseline per file) |
| **`test/false_positive_fixes_test.dart`** | Regression tests for specific false-positive fixes (location timeout, Navigator, context, HTTP, ScrollController) |
| **`test/false_positive_prevention_test.dart`** | Documents six rules and their “must not trigger” cases |

### 2.3 In-Rule Mitigations (Examples Already in Codebase)

- **Word boundaries:** Many rules (crypto, security, IAP, error_handling, provider, etc.) use `\b` or word-boundary matching so substrings like `activity` / `private` / `derivative` don’t match `iv`, and `once`/`only` don’t match provider names.
- **Exact type names:** e.g. `ScrollController`, `StreamController`, `AnimationController` matched by exact type or `endsWith`/known set instead of `typeName.contains('Controller')`.
- **Import-based scoping:** Package-specific rules (Dio, Riverpod, etc.) check imports before running, reducing false positives in unrelated files.
- **Callback vs build body:** Some rules (e.g. context/ref in build) document or implement “don’t recurse into `FunctionExpression`” to avoid flagging code inside callbacks (not yet universal).

---

## 3. Root Causes (Consolidated)

### 3.1 String/Heuristic-Based Detection

- **Substring on identifiers:** `name.contains('X')` matches any identifier containing `X` (e.g. `LocationPermissionUtils` → `require_location_timeout`; `SomeContext` → context rules).
- **Substring on types:** `typeName.contains('Stream')` matches `StreamHelper`, `Upstream`, etc.
- **Body/source string search:** `bodySource.contains('$name.dispose(')` is fragile to formatting and null-aware calls; should use AST or `isFieldCleanedUp`.
- **Short or generic terms:** e.g. `iv` in variable names (activity, private), `cost`/`fee`/`balance` in money rules, `key` in security — require word-boundary or exact-set matching.

**Remediation:** Prefer exact-match sets, `startsWith`/`endsWith` for known suffixes, type/element checks, AST visitors; use [target_matcher_utils.dart](../../lib/src/target_matcher_utils.dart) and [string_contains_false_positive_audit.md](history/false_positives/string_contains_false_positive_audit.md) patterns.

### 3.2 Context Blindness (Callbacks vs Build)

- **`ref.read` / `context` in “build”:** Rules that flag “don’t use ref/context in build” often recurse into closures. Callbacks like `onPressed`, `onSelectionChanged`, `onSubmit` run *later*; using `ref.read()` there is correct. Flagging them is a false positive.
- **`setState` in callbacks:** Same idea: `setState` inside a `Future.delayed` or stream listener callback is not “in initState” in the sense of synchronous build; it’s deferred and often guarded by `mounted`.

**Remediation:** Treat “in build” as “directly in the build method body,” not inside nested `FunctionExpression`s. Stop recursion at closure boundaries where the rule semantics require it (documented in [avoid_unnecessary_setstate_false_positive_closure_callbacks.md](../history/false_positives/avoid_unnecessary_setstate_false_positive_closure_callbacks.md), [avoid_ref_in_build_body_false_positive_callbacks_inside_build.md](../history/avoid_ref_in_build_body_false_positive_callbacks_inside_build.md)).

### 3.3 Trusted Sources and Semantics

- **Path sanitization:** `require_file_path_sanitization` flags paths built from `getApplicationDocumentsDirectory()`, `getTemporaryDirectory()`, etc. Those are platform APIs, not user input — flagging is a false positive.
- **Collection methods:** `.first`/`.last` on collections that are guaranteed non-empty by the API (e.g. `SegmentedButton.onSelectionChanged`’s `Set<T>`) or guarded by earlier control flow (e.g. early return when `fold == 0`) are false positives if the rule doesn’t account for framework or data-flow.

**Remediation:** Maintain allowlists of “trusted” path sources and, where feasible, recognize callback shapes or simple data-flow that make a call safe (see [platform_path_utils.dart](../../lib/src/platform_path_utils.dart) and discussion in [false_positives_kykto.md](../history/false_positives_kykto.md)).

### 3.4 Package/Type Confusion

- **Same name, different type:** e.g. user-defined `PermissionHandler` vs package class; custom `Key` vs Flutter `Key`. Without import or type resolution, name-only checks cause false positives.
- **Generic method names:** e.g. `createWidget()` matching a “create” pattern; methods like `sync` that aren’t network sync.

**Remediation:** Use `fileImportsPackage` / `ProjectContext` and, where possible, resolved type/element so the rule only runs for the intended package/type.

### 3.5 Overly Broad Patterns

- **Hero tag uniqueness across routes:** Same tag on different routes is often intentional; the rule can’t distinguish same-route duplicates (real bugs) from cross-route pairs (false positives).
- **NumberFormat without locale:** Parameterless `NumberFormat()` uses device locale by design; flagging it as “missing locale” is a false positive for display use cases.

**Remediation:** Narrow rule scope (e.g. same-route only), or lower severity and document known false positives; consider “opt-in” strictness or configuration.

---

## 4. Actionable Recommendations

### 4.1 For All New or Touched Rules

1. **Pre-implementation (from CONTRIBUTING):**
   - Can this be done with **exact API/method/constructor names** or **resolved types** instead of names/source strings?
   - If names are used: could `audioVolume` / `cadenceTracker` (or similar) trigger incorrectly? Use **word-boundary or exact-set** matching.
   - If matching in strings: test with property access (`.length`), null checks (`!= null`), and substrings that appear inside common words.

2. **Implementation:**
   - Prefer **exact sets** for method/type/target names; use **`target_matcher_utils`** and **`import_utils`** instead of ad-hoc `.contains()` on `targetSource`/`typeName`/`bodySource`/`disposeBody`/`createSource`/`fieldType`/`source`.
   - Use **`ProjectContext`** and **`fileImportsPackage`** so package- or platform-specific rules run only in relevant files.
   - For “in build” / “in initState” semantics: **do not recurse into `FunctionExpression`** (or document why recursion is correct) so callbacks are not treated as build body.

3. **Testing:**
   - Add **GOOD cases** in fixtures (no `expect_lint`) that represent easy-to-confuse code and must *not* trigger.
   - Add a **unit test** that asserts “this code must not produce a lint” for at least one borderline case per rule.

4. **Documentation:**
   - In the rule’s DartDoc, note **known limitations or false positive risks** (e.g. “May have false positives for non-sensitive keys”).
   - When a reported false positive is fixed, add a regression test and, if useful, a short note in `bugs/history/false_positives/`.

### 4.2 For the Codebase as a Whole

- **Continue phased remediation** from [string_contains_false_positive_audit.md](../history/false_positives/string_contains_false_positive_audit.md): Phase 1 (disposal interpolation) → Phase 2 (context/location/http) → Phase 3 (framework terms) → Phase 4 (body/keyword). Track progress in that file.
- **Tighten CI baseline:** When `.contains()` usages are removed from a rule file, **decrease** the corresponding baseline in `test/anti_pattern_detection_test.dart` (and remove the file key when count reaches 0). Do not add new baseline entries for new files unless they contain grandfathered violations.
- **Centralize “trusted path” and “safe callback” knowledge:** Extend `platform_path_utils` (or a small shared module) for trusted path APIs; consider a shared “is inside callback passed to build” helper so ref/context/setState rules stay consistent.
- **Severity and tier:** For rules with **known unavoidable false positives**, consider WARNING instead of ERROR and/or moving to Comprehensive/Pedantic tier, and document in ROADMAP/rule doc.

### 4.3 For Specific Rule Families

| Area | Suggestion |
|------|------------|
| **Path sanitization** | Treat `getApplicationDocumentsDirectory`, `getTemporaryDirectory`, `getApplicationSupportDirectory` (and similar) as trusted; don’t require sanitization for their return values. |
| **Riverpod/Provider “in build”** | Limit “build body” to direct children of the build method; treat `FunctionExpression` as callback boundary and skip recursion for “no ref/context in build” checks. |
| **Collection safety** | Optionally allowlist Flutter callbacks that guarantee non-empty collections (e.g. `SegmentedButton.onSelectionChanged`); or document as known limitation. |
| **Hero tag uniqueness** | Consider same-route-only check, or WARNING + doc that cross-route same tag can be intentional. |
| **NumberFormat locale** | Don’t flag parameterless `NumberFormat()` when used in display context, or add an optional “display-only” exemption. |

---

## 5. Prioritized Remediation (From Audit)

The audit’s phased plan remains the right order:

1. **Phase 1 — Critical string interpolation:** Replace `disposeBody.contains('$name.dispose(')` (and similar) with AST disposal utility. **Done:** disposal_rules.dart now uses `isFieldCleanedUp()`. Remaining: animation_rules, widget_lifecycle_rules if they still use the pattern.
2. **Phase 2 — Critical substring on common words:** Replace substring checks with type/import-based or exact/word-boundary checks. **Done:** navigation_rules (avoid_deep_link_sensitive_params, prefer_typed_route_params); api_network_rules (require_http_status_check, require_retry_logic); provider_rules (avoid_provider_for_single_value, prefer_selector_over_single_watch, avoid_provider_value_rebuild); permission_rules (require_location_permission_rationale, require_camera_permission_check, prefer_image_cropping). **Remaining:** any leftover bodySource.contains in api_network/permission; Phase 3 (framework terms).
3. **Phase 3 — High-risk framework terms:** Replace substring matching on `Navigator`, `Stream`, `Controller`, `Tween`, `socket` with exact-match sets or type checks.
4. **Phase 4 — Medium-risk:** Body/keyword and method-name patterns; fix case-by-case with exact sets or AST.

Current baseline counts in `anti_pattern_detection_test.dart` (e.g. api_network_rules 143, async_rules 59, navigation_rules 52) indicate where the most remaining `.contains()` risk lives; reducing those files first will have the largest impact.

---

## 6. Testing and Prevention Checklist

Before submitting a new or modified rule:

- [ ] No new `.contains()` on `methodName`, `targetSource`, `typeName`, `bodySource`, `disposeBody`, `createSource`, `fieldType`, or generic `source` (or baseline explicitly updated with justification).
- [ ] Used `target_matcher_utils` or exact sets / type checks / AST where target/type/body detection is needed.
- [ ] Package-specific rule uses `fileImportsPackage` or `ProjectContext` so it doesn’t run in unrelated files.
- [ ] Fixture includes at least one “must NOT trigger” case (no expect_lint) that could easily be confused with a violation.
- [ ] Rule DartDoc mentions known false positive risks or limitations if heuristics are unavoidable.
- [ ] If the rule is “in build” / “in initState”: recursion into callbacks is intentional and documented, or recursion stops at `FunctionExpression`.

---

## 7. References

- [CONTRIBUTING.md § Avoiding False Positives](../../CONTRIBUTING.md) — Anti-patterns, lessons learned, what to do
- [string_contains_false_positive_audit.md](../history/false_positives/string_contains_false_positive_audit.md) — Audit, patterns, phases, completed fixes
- [false_positives_kykto.md](../history/false_positives_kykto.md) — Consumer-reported false positives and suggested improvements
- [target_matcher_utils.dart](../../lib/src/target_matcher_utils.dart) — Exact target, disposal, chained method helpers
- [import_utils.dart](../../lib/src/import_utils.dart) — Package import checks
- [anti_pattern_detection_test.dart](../../test/anti_pattern_detection_test.dart) — CI guard and baseline
- [false_positive_fixes_test.dart](../../test/false_positive_fixes_test.dart) — Regression tests for specific fixes
- Individual bug reports under `bugs/history/false_positives/` and `bugs/history/` for per-rule fixes and patterns
