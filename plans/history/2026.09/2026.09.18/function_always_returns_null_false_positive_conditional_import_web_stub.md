# BUG: `function_always_returns_null` — Fires on the Web-Side Stub Half of a `dart.library.io` Conditional Import

**Status: Open**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-09-18
Rule: `function_always_returns_null`
File: `lib/src/rules/code_quality/code_quality_variables_rules.dart` (line ~922)
Severity: False positive — High (generalises to every Dart/Flutter package with a web/io split: `shared_preferences`, `path_provider`, `flutter_secure_storage`, etc.)
Rule version: v6 | Since: v0.1.4 | Updated: v4.13.0

---

## Summary

Three `static` getters in `drift_debug_server_stub.dart` — the web-side half of a `dart.library.io` conditional export — unconditionally return `null`, which is their entire contract: the stub can never have a live server, so it must report "not running" for every accessor the `dart:io`-backed implementation exposes. `function_always_returns_null` flags all three as "effectively void," even though each mirrors a same-named, same-signature, nullable-returning getter in the sibling `_io.dart` file that returns a real value from a live instance. The rule has no way to see that sibling file and has no exemption for stub/impl conditional-import pairs.

---

## Attribution Evidence

```bash
$ cd /Users/craighathaway/Documents/src/saropa_lints && grep -rn "'function_always_returns_null'" lib/src/rules/
lib/src/rules/code_quality/code_quality_variables_rules.dart:942:    'function_always_returns_null',

$ grep -rn "'function_always_returns_null'" /Users/craighathaway/Documents/src/saropa_drift_advisor/lib/src/ /Users/craighathaway/Documents/src/saropa_drift_advisor/extension/src/
# (no output — 0 matches, confirms the rule is NOT defined downstream)
```

Rule source unchanged between v16.2.1 and 16.3.0 (HEAD); line numbers below cite HEAD.

**Emitter registration:** `lib/src/rules/code_quality/code_quality_variables_rules.dart:942` (`LintCode`)
**Rule class:** `FunctionAlwaysReturnsNullRule` — defined at `lib/src/rules/code_quality/code_quality_variables_rules.dart:922`. Exported via the barrel `lib/src/rules/all_rules.dart:24` (`export 'code_quality/code_quality_variables_rules.dart';` — the barrel only re-exports the file, it does not list class names). Actually registered as a runnable rule via its factory at `lib/saropa_lints.dart:667` (`FunctionAlwaysReturnsNullRule.new,`).
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

Minimal reduction of the real conditional-import pair (stub half is what's flagged):

```dart
// server_impl.dart — the dart:io-backed half, selected on VM/native
class Server {
  static Server? _instance;
  /// The port the server is bound to, or null if not running.
  static int? get port => _instance?.port; // real value when running
}

// server_stub.dart — the web half, selected when dart:io is unavailable
class Server {
  /// Stub: always returns null (server not running on web).
  static int? get port => null; // LINT (false positive) — this IS the contract
}
```

**Frequency:** Always, for any conditional-import stub member whose body is a bare `null` literal and whose return type is nullable.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the nullable return type is honored, not "effectively void"; the stub member exists only because a sibling implementation file returns a real value under the same public signature. |
| **Actual** | `[function_always_returns_null] Function returns null on every code path, making the return type effectively void. ...` reported on `static int? get port`, `static bool? get changeDetectionEnabled`, `static bool? get monitoringEnabled` at `drift_debug_server_stub.dart:68, 72, 78`. |

---

## AST Context

```
CompilationUnit (drift_debug_server_stub.dart)
  └─ ClassDeclaration (DriftDebugServer, web stub variant)
      └─ MethodDeclaration (static getter `port`, isStatic: true, isGetter: true)
          └─ ExpressionFunctionBody
              └─ NullLiteral  ← node the rule reports on (via nameToken of the getter)
```

Same shape repeats for `changeDetectionEnabled` (line 72) and `monitoringEnabled` (line 78).

---

## Root Cause

`FunctionAlwaysReturnsNullRule.runWithReporter` (`code_quality_variables_rules.dart:944-967`) registers on both `FunctionDeclaration` and `MethodDeclaration`. For each, `_hasOverrideAnnotation(node.metadata)` (line ~964, checked before `_checkFunctionBody`) is the *only* exemption checked before the null-body test. It looks for a syntactic `@override` annotation — nothing else. `_checkFunctionBody` (`code_quality_variables_rules.dart:1002-1036`) then:

- Skips generators (`body.isGenerator`) and `Stream`/`Iterable` return types (lines 1004-1013) — not applicable here.
- Skips `void`/`Future<void>`/`FutureOr<void>` return types via `_isVoidType` (line 1016) — not applicable; `port`/`changeDetectionEnabled`/`monitoringEnabled` are declared `int?`/`bool?`.
- For `ExpressionFunctionBody` (line 1018-1023, the shape of all three flagged getters): if `body.expression is NullLiteral`, it reports unconditionally at line 1021 (`reporter.atToken(nameToken)`).

There is no check anywhere in this rule for:
- Whether the enclosing file is one half of a `dart.library.*` conditional export/import pair (e.g. `export 'x_stub.dart' if (dart.library.io) 'x_io.dart';` in a barrel file).
- Whether a same-named, same-signature member exists in a sibling file with a non-trivial (non-`null`-only) body.
- Whether the getter is `static` (the `@override` exemption cannot even apply to a `static` member — a static member overrides nothing — so these three getters get zero exemption coverage from the rule's only escape hatch).

Confirmed via `grep -n "dart.library\|conditional\|_stub\|isStub\|conditionalImport" lib/src/rules/code_quality/code_quality_variables_rules.dart` → no matches. The rule is a pure single-file AST check; it structurally cannot see the sibling `_io.dart` file to confirm the nullable return type is meaningful there.

---

## Suggested Fix

Two independent, additive options (either would resolve this instance; the second is more general):

1. **File-path heuristic:** skip the check when `context.filePath` (or `resolver.path`) matches a conditional-import stub naming convention (e.g. ends with `_stub.dart`, or matches a sibling `if (dart.library.io)`/`if (dart.library.js_interop)` clause discoverable by scanning the same-directory barrel file's `export`/`import` directives for the current file's basename). This is cheap (string/path check) and directly targets the pattern.
2. **Static-member exemption:** since `_hasOverrideAnnotation` can never fire for a `static` member (nothing to override), and a `static` getter/method's contract is far more likely to be an intentional stub-only accessor than an incomplete implementation, consider excluding `static` members from this rule entirely, or at minimum lowering severity/requiring an explicit opt-out comment convention (e.g. `/// Stub:` doc-comment prefix, already used at all three sites here) that the rule could recognize as an intentional-null marker.

Both changes are scoped to `_checkFunctionBody`/`runWithReporter` in `code_quality_variables_rules.dart:944-1036`; no change needed elsewhere.

---

## Fixture Gap

Fixture at `example/lib/code_quality/function_always_returns_null_fixture.dart` (251 lines) exists and covers: bare `return null;`, expression-body `=> null;`, `@override` getters returning null (line ~219, `String? get label => null;`), unannotated returns. It has **no case** for:

1. **`static` getter with a `null`-only body, mirroring a same-signature non-static-or-non-null sibling** — expect NO lint (this bug's exact shape).
2. **A member in a file matching a conditional-import stub naming convention** (`*_stub.dart`) — expect NO lint, at least as a documented/skipped case if the fix is file-path-based.

---

## Changes Made

_Not yet — open report._

---

## Tests Added

_Not yet — open report._

---

## Commits

_Not yet — open report._

---

## Environment

- saropa_lints version: 16.2.1 resolved (findings); 16.3.0 / HEAD (source reviewed for this report — confirmed unchanged for this rule since v16.2.1, only newer commit to a relevant file is 96aaeff2 which touches only `PreferLateFinalRule`)
- Dart SDK version: 3.12.2 (stable)
- custom_lint version: n/a (findings from `saropa_lints scan` CLI / VS Code extension)
- Triggering project/file: `saropa_drift_advisor` 4.4.1, `lib/src/drift_debug_server_stub.dart:68, 72, 78`; scan report `saropa_drift_advisor/reports/20260918/20260918_081229_findings.json`

---

## Finish Report (2026-09-18)

**Verdict: Valid.** The report accurately diagnosed the root cause and its
attribution evidence checked out. Of the two suggested fixes, option 1
(file-path/conditional-import awareness) was implemented; option 2 (a
blanket exemption for `static` members) was rejected as over-broad — it
would silence genuinely buggy static getters/methods that happen to always
return `null` outside of a stub/io split, which is a real and unrelated bug
shape the rule should keep catching.

### Root cause

`FunctionAlwaysReturnsNullRule` (`lib/src/rules/code_quality/code_quality_variables_rules.dart`,
class `FunctionAlwaysReturnsNullRule`) is a pure single-file AST check with
only one exemption (`@override`, which is syntactically impossible for
`static` members). It has no way to see that a file is the web-side stub
half of a `dart.library.io`/`.ffi` conditional import/export, where a
null-only body IS the documented contract (the sibling `_io.dart`/native
file returns real values under the same signature).

### Fix

Added a semantic (resolved-AST-based, not name/string heuristic on the
*rule* itself) helper `isConditionalImportStubTarget(String? filePath)` in
`lib/src/conditional_import_utils.dart`, symmetric to the existing
`isNativeOnlyConditionalImportTarget`. It reuses the same one-pass-per-project
directive scan (`_buildNativeOnlyTargets`) and additionally records, per
`import`/`export` directive:
- the **default URI** of any directive that also carries a
  `dart.library.io`/`dart.library.ffi` configuration (the true conditional
  wiring case), and
- the naming-convention fallback: a `*_stub.dart` file with a sibling
  `*_io.dart` file in the same directory (mirroring the existing
  `_collectSiblingStubTarget` heuristic used for the native side).

Both are cached per-project alongside the existing native-only set
(`_stubTargetsByProject`, built together with `_nativeOnlyTargetsByProject`
in the same scan — no extra filesystem pass).

`FunctionAlwaysReturnsNullRule.runWithReporter` now returns early via
`if (isConditionalImportStubTarget(context.filePath)) return;` before
registering its `FunctionDeclaration`/`MethodDeclaration` visitors, so the
entire stub file is skipped — this rule genuinely cannot verify per-member
whether a given null-returning stub member mirrors a meaningful sibling
member, so file-level skip (rather than a per-member static check) is the
narrowest defensible boundary that doesn't require guessing.

This preserves all existing behavior for non-stub files: `@override`
handling, generator skipping, void-type skipping, and — critically — a
lone `static` getter that always returns `null` **outside** a conditional
import stub pair is still flagged (verified by regression test below), so
option 2's blanket static exemption was correctly avoided.

### Files changed

- `lib/src/conditional_import_utils.dart` — added `isConditionalImportStubTarget`
  and the `stubOnly` collection threaded through `_buildNativeOnlyTargets`,
  `_collectTargetsFromFile`, and `_collectSiblingStubTarget`.
- `lib/src/rules/code_quality/code_quality_variables_rules.dart` — added the
  `isConditionalImportStubTarget(context.filePath)` early-return guard in
  `FunctionAlwaysReturnsNullRule.runWithReporter`.
- `test/utils/conditional_import_utils_test.dart` — added an
  `isConditionalImportStubTarget` group: null/empty path, directive-based
  stub detection (`import`/`export`, `.io`/`.ffi`), native-branch/other-file
  negatives, and the naming-convention fallback (including the exact
  `drift_debug_server_stub.dart`/`drift_debug_server_io.dart` shape from
  this report) with its negative (lone `*_stub.dart`, no sibling).
- `test/rules/code_quality/function_always_returns_null_stub_test.dart`
  (new) — end-to-end resolved-analyzer regression test: builds an isolated
  temp package with a real `drift_debug_server_stub.dart` /
  `drift_debug_server_io.dart` / conditional-export-wiring file triple and
  asserts `FunctionAlwaysReturnsNullRule` reports nothing on the stub file;
  a second test asserts a lone static null-returning getter with no stub
  pairing is still flagged (regression guard against over-suppression).

### Tests

- `dart analyze` on all touched files: no issues found.
- `dart test test/rules/code_quality/function_always_returns_null_stub_test.dart test/utils/conditional_import_utils_test.dart`: 20/20 passed.
- `dart test test/rules/code_quality/code_quality_rules_test.dart`: 221/221 passed (no regressions to existing code_quality rule suite).
- `dart test test/rules/config/platform_rules_test.dart`: 14/14 passed (confirms the shared `conditional_import_utils.dart` change didn't regress its existing consumer, `prefer_platform_io_conditional`).
- `dart format` applied only to the touched/new files.

### Proposed CHANGELOG bullet

- fix: `function_always_returns_null` no longer flags null-only stub members in the web-side half of a `dart.library.io`/`.ffi` conditional import/export (e.g. `shared_preferences`/`path_provider`-style `_stub.dart`/`_io.dart` splits)
