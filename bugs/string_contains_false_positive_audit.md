# Systemic False Positives: `String.contains()` Anti-Pattern Audit

## Status: PLAN

## Summary

An audit of all rule files found **121+ instances** where detection logic uses
`String.contains()` on identifier names, method names, type names, or
`.toSource()` results. This is the root cause of recurring false positives
across the project. The `require_location_timeout` fix (Feb 2026) demonstrated
the correct remediation pattern: replace substring matching with exact-match
sets, type system checks, or specific AST patterns.

## Why This Keeps Happening

Every rule that uses `.contains()` on an identifier name to decide *what code
does* is a false positive waiting to happen. The pattern `name.contains('X')`
matches any identifier with `X` as a substring, regardless of whether the code
actually performs the operation the rule is trying to detect.

Examples of real false positives from this pattern:
- `LocationPermissionUtils.hasLocationPermission()` triggered `require_location_timeout`
- Any class with "context" in its name triggers provider rules
- Any method with "sync" in its name triggers network rules

When lint rules produce false positives, developers learn to ignore warnings
or blanket-suppress with `// ignore:` comments, defeating the purpose of every
rule in the package.

## Severity Classification

### Critical (must-fix)

Rules that match extremely common substrings or use string interpolation
to search function bodies. These produce false positives in most projects.

### High

Rules that match common framework terms (`Controller`, `Stream`, `Navigator`,
`http`) as substrings. False positives likely in medium-to-large projects.

### Medium

Rules that match less common terms or use `.contains()` on more constrained
inputs. False positives possible but less frequent.

### Low (already correct)

Rules that already use `Set.contains()` with exact matches. No action needed.

---

## Remediation Patterns

### Pattern A: Exact-match set (simplest)

Replace `name.contains('X')` with a `Set<String>` of exact names.

```dart
// BAD
if (methodName.contains('Position')) { ... }

// GOOD
static const _methods = {'getCurrentPosition', 'getLastKnownPosition'};
if (_methods.contains(methodName)) { ... }
```

**Use when:** The set of valid targets is known and finite.

### Pattern B: Type system check

Use `staticType` or resolved element info instead of name matching.

```dart
// BAD
if (typeName.contains('StreamController')) { ... }

// GOOD
final type = node.staticType;
if (type != null && type.element?.name == 'StreamController') { ... }
```

**Use when:** The detection depends on what type something is.

### Pattern C: AST pattern matching

Use AST node types instead of searching source strings.

```dart
// BAD
if (bodySource.contains('try') && bodySource.contains('catch')) { ... }

// GOOD
bool hasTryCatch = false;
body.visitChildren(RecursiveAstVisitor()
  ..visitTryCatchClause = (_) => hasTryCatch = true);
```

**Use when:** The detection depends on code structure.

### Pattern D: Import-based check

Verify the import origin rather than guessing from names.

```dart
// BAD
if (targetSource.contains('http')) { ... }

// GOOD
final element = target.staticElement;
if (element?.library?.source.uri.toString().contains('package:http/')) { ... }
```

**Use when:** The detection is package-specific.

---

## Findings by File

### 1. permission_rules.dart (7 instances)

| Line | Rule | `.contains()` call | Risk | Fix |
|------|------|---------------------|------|-----|
| 90-91 | `require_location_permission_rationale` | `targetSource.contains('location')` / `contains('Location')` | Critical | A: exact target set |
| 112-119 | `require_location_permission_rationale` | `bodySource.contains('showDialog')` / `'AlertDialog'` / 6 more | Critical | C: AST visitor for dialog nodes |
| 213-218 | `require_unlocked_camera_access` | `targetSource.contains('Permission.camera')` / `'.camera'` | High | A: exact method + target set |
| 228-231 | `require_unlocked_camera_access` | `targetSource.contains('Permission.camera')` / `'isGranted'` | High | A: exact property set |
| 276-280 | `check_photo_permission` | `contains('Permission.camera')` / `'.camera'` / `'isGranted'` | High | A: exact set |
| 391 | `require_photo_crop` | `contains(keyword)` for profile context | Medium | A: method name set |
| 400-403 | `require_photo_crop` | `contains('cropper')` / `'crop'` / `'ImageCropper'` | Medium | A: class + method set |

### 2. api_network_rules.dart (23 instances)

| Line | Rule | `.contains()` call | Risk | Fix |
|------|------|---------------------|------|-----|
| 70-75 | `require_http_status_code_check` | `contains('http.get')` / `'.post('` / etc | Critical | D: import check + A: method set |
| 80-81 | `require_http_status_code_check` | `contains('statusCode')` / `'isSuccessful'` | High | A: property name set |
| 135 | `avoid_hardcoded_api_endpoints` | `path.contains('config')` / `'constants'` | Medium | A: filename pattern |
| 210-213 | `avoid_ignored_api_errors` | `contains('http.')` / `'dio.'` / `'.get('` / `'.post('` | Critical | D: import check + A: method set |
| 218-221 | `avoid_ignored_api_errors` | `contains('retry')` / `'Retry'` / `'attempts'` | Medium | A: keyword set |
| 280-282 | `avoid_unsafe_json_access` | `contains('fromJson')` / `'fromMap'` / `'parse'` | High | A: method name set |
| 293-294 | `avoid_unsafe_json_access` | `contains("$variableName['")` (interpolation) | Critical | C: AST IndexExpression check |
| 369-373 | `require_network_connectivity_check` | `contains('sync')` / `'upload'` / `'download'` / `'fetch'` | High | A: method set (drop `sync`) |
| 381-384 | `require_network_connectivity_check` | `contains('http.')` / `'dio.'` | Critical | D: import check |
| 389-392 | `require_network_connectivity_check` | `contains('connectivity')` / `'isConnected'` | High | A: class + method set |

*(13 more medium/low instances omitted for brevity)*

### 3. animation_rules.dart (21 instances)

| Line | Rule | `.contains()` call | Risk | Fix |
|------|------|---------------------|------|-----|
| 329 | `require_animation_controller_dispose` | `typeName.contains('AnimationController')` | Medium | B: type check or exact match |
| 363-368 | `require_animation_controller_dispose` | `disposeBody.contains('$name.dispose(')` (interpolation) | Critical | C: AST method invocation visitor |
| 787 | `avoid_uncurved_tween_animation` | `targetSource.contains('Tween')` | Medium | B: type check |
| 792-794 | `avoid_uncurved_tween_animation` | `contains('CurvedAnimation')` / `'curve:'` / `'Curve'` | High | A: class name set + named param check |
| 1012-1016 | `animate_slivers_progress` | `contains('Interval')` / `'index *'` / `'delay'` / `'stagger'` | High | A: class name set |
| 1505-1513 | `scroll_view_animation` | `contains('animateTo')` / `'Simulation'` / `'spring'` | High | A: method + class set |
| 1643-1646 | `ticker_rule` | `disposeBody.contains('$fieldName.stop()')` (interpolation) | Critical | C: AST method invocation visitor |

*(14 more medium/low instances omitted)*

### 4. async_rules.dart (24 instances, 3 already fixed)

| Line | Rule | `.contains()` call | Risk | Fix |
|------|------|---------------------|------|-----|
| 1605 | `await_navigation_and_context_usage` | `targetSource.contains('Navigator')` | High | A: exact target set |
| 1657-1670 | `await_navigation_and_context_usage` | `contains('.mounted')` / `'context.mounted'` | Medium | A: property set |
| 1871-1874 | `web_socket_validation` | `contains('socket')` / `'Socket'` / `'channel'` | High | A: class name set |
| 1889-1896 | `web_socket_validation` | `bodySource.contains('try')` / `'catch'` / `'is Map'` | High | C: AST visitor |
| 2334 | `stream_controller_in_build` | `typeName.contains('StreamController')` | High | B: type check or exact match |
| 2441-2442 | `stream_controller_in_build` | `contains('.close()')` / `'.dispose()'` | High | C: AST method invocation |
| 2919 | `stream_listener_access` | `typeName.contains('Stream')` | Medium | B: type check |
| 3115 | `stream_subscription_no_leak` | `fieldType.contains('StreamSubscription')` | High | B: type check or exact match |

*(12 more medium/low instances omitted)*

### 5. navigation_rules.dart (47 instances - most affected file)

| Line | Rule | `.contains()` call | Risk | Fix |
|------|------|---------------------|------|-----|
| 231-237 | `await_navigation` | `contains('context')` / `'Context'` / `'.of(context'` | Critical | B: type check for BuildContext |
| 430 | `go_router_exact_route_typing` | `targetSource.contains('Navigator')` | High | A: exact target set |
| 619-627 | `go_router_conditional_redirect` | `contains('null')` / `'?'` / `'if'` / `'return null'` | High | C: AST conditional visitor |
| 709-713 | `go_router_result_null_check` | `bodySource.contains(varName)` (interpolation) | Critical | C: AST variable reference check |
| 897-900 | `deep_link_handler` | `methodName.contains('deeplink')` / `'link'` / `'uri'` / `'route'` | High | A: method name set |
| 1029-1053 | `deep_link_handler` | 12+ `.contains()` patterns in body | Critical | C: AST visitor + A: class set |
| 2336 | `go_router_detail_route_context` | `targetSource.contains('context')` | Critical | B: type check for BuildContext |
| 2442-2443 | `go_router_url_parameter_encoding` | `contains('encodeComponent')` | High | A: method name set |
| 2644-2647 | `go_router_nested_scaffold` | `contains('Scaffold(')` / `'AppBar('` | High | A: constructor name set |
| 2968-2969 | `navigator_context_access` | `targetSource.contains('Navigator')` / `'Scrollable'` | High | A: exact target set |

*(37 more instances omitted)*

### 6. widget_lifecycle_rules.dart (28 instances)

| Line | Rule | `.contains()` call | Risk | Fix |
|------|------|---------------------|------|-----|
| 3313 | `require_scroll_controller_dispose` | `typeName.contains('ScrollController')` | High | B: type check or exact match |
| 3347-3360 | `require_scroll_controller_dispose` | `disposeBody.contains('$name.dispose(')` (interpolation) | Critical | C: AST visitor |
| 3539-3540 | `require_focus_node_dispose` | `typeName.contains('FocusNode')` / `'FocusScopeNode'` | High | B: type check |
| 3574-3586 | `require_focus_node_dispose` | `disposeBody.contains('$name.dispose(')` (interpolation) | Critical | C: AST visitor |

*(20 more medium/low instances omitted)*

### 7. provider_rules.dart (15 instances)

| Line | Rule | `.contains()` call | Risk | Fix |
|------|------|---------------------|------|-----|
| 555-557 | `avoid_provider_for_single_value` | `typeName.contains('Notifier')` / `'Controller'` / `'ViewModel'` | Medium | A: type suffix set |
| 650-652 | `avoid_provider_for_single_value` | `createSource.contains('Notifier')` / `'Controller'` | High | C: AST constructor check |
| 1609, 1689 | `avoid_context_access_in_callback` | `targetSource.contains('context')` | Critical | B: type check for BuildContext |
| 1829 | `avoid_imperative_provider_mutation` | `targetSource.contains('context')` | Critical | B: type check for BuildContext |

*(8 more medium/low instances omitted)*

### 8. Other files (lower instance counts)

| File | Instances | Critical | High | Medium |
|------|-----------|----------|------|--------|
| collection_rules.dart | 14 | 0 | 0 | 2 |
| type_safety_rules.dart | 10 | 0 | 0 | 6 |
| widget_layout_rules.dart | 25 | 0 | 1 | 3 |

These files are mostly already using Set-based matching correctly.

---

## Prioritized Remediation Plan

### Phase 1: Critical string interpolation patterns (8 rules)

These use `bodySource.contains('$name.dispose(')` which is both a false
positive risk and fragile against formatting changes.

**Files:** animation_rules.dart, widget_lifecycle_rules.dart
**Rules:** `require_animation_controller_dispose`, `ticker_rule`,
`require_scroll_controller_dispose`, `require_focus_node_dispose`
**Fix:** Create shared AST disposal-detection utility
**Effort:** Medium (one utility, update 4 rules)

### Phase 2: Critical substring on common words (6 rules)

These match `context`, `location`, or `http` as substrings.

**Files:** navigation_rules.dart, provider_rules.dart, permission_rules.dart,
api_network_rules.dart
**Rules:** `await_navigation`, `go_router_detail_route_context`,
`avoid_context_access_in_callback`, `avoid_imperative_provider_mutation`,
`require_location_permission_rationale`, `require_http_status_code_check`
**Fix:** Replace with type checks (BuildContext) or import-based checks (http)
**Effort:** Medium

### Phase 3: High-risk substring matching (15+ rules)

These match framework terms (`Navigator`, `Stream`, `Controller`, `Tween`,
`socket`) as substrings.

**Files:** async_rules.dart, navigation_rules.dart, animation_rules.dart
**Fix:** Replace with exact-match sets (Pattern A)
**Effort:** Low per rule, but many rules

### Phase 4: Medium-risk patterns (20+ rules)

Body-source keyword matching, method name pattern matching.

**Fix:** Case-by-case: some need AST visitors, most just need exact sets
**Effort:** Low-medium

---

## Metrics

| Category | Instance Count | Files Affected |
|----------|----------------|----------------|
| Critical | ~20 | 6 |
| High | ~35 | 7 |
| Medium | ~40 | 9 |
| Low (correct) | ~25 | 8 |
| **Total** | **~121** | **10** |

## Completed Fixes

| Date | File | Rules Fixed | Fix Type |
|------|------|-------------|----------|
| 2026-02-08 | async_rules.dart | `require_location_timeout` | Exact GPS method/target sets + chained `.timeout()` |
| 2026-02-08 | async_rules.dart | `await_navigation_and_context_usage`, `web_socket_validation`, `stream_controller_in_build`, stream rules | Navigator exact match, socket `endsWith`, StreamController exact match, Stream `startsWith` |
| 2026-02-08 | permission_rules.dart | `require_location_permission_rationale`, `require_camera_permission_check` | Exact Permission enum values, removed `isGranted`/`checkPermission` substrings |
| 2026-02-08 | api_network_rules.dart | `require_http_status_code_check`, `require_retry_logic`, `require_connectivity_check`, `require_api_error_mapping`, `require_request_timeout`, `require_typed_api_response` | Removed bare `.get(`/`.post(`, HTTP target exact match, method name `startsWith`/`endsWith`, exact `fromJson` |
| 2026-02-08 | navigation_rules.dart | `await_navigation`, `go_router_result_null_check`, `go_router_detail_route_context`, `navigator_context_access`, `require_pop_result_type` | Navigator exact match, context exact `==`, Route/Page `endsWith`/`startsWith` |
| 2026-02-08 | provider_rules.dart | `avoid_context_access_in_callback`, `avoid_imperative_provider_mutation`, `avoid_provider_for_single_value`, `avoid_inherited_widget` | Context `SimpleIdentifier` check, Notifier/Controller `endsWith`, InheritedWidget exact match |
| 2026-02-08 | animation_rules.dart | `require_animation_controller_dispose`, `ticker_rule`, `avoid_uncurved_tween_animation` | Regex disposal patterns, AnimationController exact match, Tween `endsWith` |
| 2026-02-08 | widget_lifecycle_rules.dart | `require_scroll_controller_dispose`, `require_focus_node_dispose` | Exact type names, regex disposal patterns |

## References

- [require_location_timeout bug report](require_location_timeout_false_positive_permission_checks.md)
- [check_mounted_after_async bug report](check_mounted_after_async_false_positive_guard_clause.md)
