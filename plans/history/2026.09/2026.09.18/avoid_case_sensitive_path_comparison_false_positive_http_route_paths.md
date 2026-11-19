# BUG: `avoid_case_sensitive_path_comparison` — fires on HTTP route-path comparisons and on a variable-indirected root-walk sentinel

**Status: Open**

Created: 2026-09-18

Rule: `avoid_case_sensitive_path_comparison`
File: `lib/src/rules/platforms/windows_rules.dart` (line ~407, class at line 380)
Severity: False positive — High (volume: 122 of the triggering scan's ~340 total findings, 36%)
Rule version: v3 | Since: v4.9.20 | Updated: v4.13.0

Rule source unchanged between v16.2.1 and 16.3.0 (HEAD); line numbers cite HEAD (checkout at `9456b83e`, `v16.2.1-13-g9456b83e`).

---

## Summary

`avoid_case_sensitive_path_comparison` reports *"File path compared without case normalization. Windows filesystem is case-insensitive."* on 122 sites in the downstream project `saropa_drift_advisor` (scan `reports/20260918/20260918_081229_findings.json`, saropa_lints 16.2.1 resolved). None of the 122 is a filesystem-path bug:

- **119 sites** compare an **HTTP request URL path** (`Uri.path` via `HttpRequest.uri.path`) against a lowercase route constant. HTTP request-target paths are case-sensitive by specification; case-folding them would widen the router's accepted surface (e.g. making `/API/mutations` match a rate-limit-exempt route).
- **3 sites** are the standard "walked to filesystem root" sentinel (`parent.path == dir.path`, where `parent` was assigned from `dir.parent` on the previous line) — both operands derive from the same `Directory` object, so casing is identical by construction. The rule already has a dedicated exemption for exactly this idiom, but it does not fire here because the exemption is a pure source-text match (see Root Cause, Pattern 2).

---

## Attribution Evidence

```bash
$ grep -rn "'avoid_case_sensitive_path_comparison'" lib/src/rules/
lib/src/rules/platforms/windows_rules.dart:407:    'avoid_case_sensitive_path_comparison',

$ grep -rn "'avoid_case_sensitive_path_comparison'" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# 0 matches
```

**Emitter registration:** `lib/saropa_lints.dart:2549` — `AvoidCaseSensitivePathComparisonRule.new,`
**Rule class:** `AvoidCaseSensitivePathComparisonRule` — defined `lib/src/rules/platforms/windows_rules.dart:380`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

### Pattern 1 — HTTP route path (119 of 122 findings)

```dart
class ServerConstants {
  static const pathApiHealth = '/api/health';
}

void route(Uri requestUri) {
  final String path = requestUri.path; // e.g. from HttpRequest.uri.path

  // LINT (false positive): `path` is an HTTP request-target path, not a
  // filesystem path. Case-folding it would make '/API/health' match too,
  // silently widening the router's accepted surface.
  if (path == ServerConstants.pathApiHealth) {
    // dispatch
  }
}
```

Minimal reduction of `saropa_drift_advisor/lib/src/server/router.dart:147,157-158` and `lib/src/server/compare_handler.dart:43` (117 + 2 = 119 sites, same shape throughout).

### Pattern 2 — root-walk sentinel via intermediate variable (3 of 122 findings)

```dart
import 'dart:io';

void walkToRoot(Directory dir) {
  while (true) {
    final parent = dir.parent;
    // LINT (false positive): both operands derive from the same
    // Directory chain (`parent` was just assigned from `dir.parent`),
    // so casing is identical by construction — the standard "stop at
    // filesystem root" idiom.
    if (parent.path == dir.path) break;
    dir = parent;
  }
}
```

Minimal reduction of `saropa_drift_advisor/lib/src/server/generation_handler.dart:736-738` (and identical code at lines 763-765, 796-798).

**Frequency:** Always — every route-constant comparison and every occurrence of this exact root-walk idiom shape.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic for `Uri.path`/`HttpRequest.uri.path` receivers, and no diagnostic for the root-walk idiom regardless of whether `.parent` is accessed directly or through an intermediate local variable |
| **Actual** | `[avoid_case_sensitive_path_comparison] File path compared without case normalization...` reported at all 122 sites |

---

## AST Context

Pattern 1:
```
MethodDeclaration / function body
  └─ Block
      └─ IfStatement
          └─ BinaryExpression (==)   ← node reported here
              ├─ SimpleIdentifier (path)         [receiver: Uri.path via a local String]
              └─ PrefixedIdentifier (ServerConstants.pathApiHealth)
```

Pattern 2:
```
WhileStatement
  └─ Block
      ├─ VariableDeclarationStatement (final parent = dir.parent;)
      ├─ IfStatement
      │   └─ BinaryExpression (==)   ← node reported here
      │       ├─ PropertyAccess (parent.path)
      │       └─ PropertyAccess (dir.path)
      └─ ExpressionStatement (dir = parent;)
```

---

## Root Cause

### Pattern 1 (119 sites) — `_containsPathPattern` matches on identifier text, never on receiver static type or origin

`context.addBinaryExpression` (`windows_rules.dart:421-469`) only gates on:
- `windows_rules.dart:429` — `_isBothSidesString(node)`, which (`windows_rules.dart:135-164`) checks only that `node.leftOperand.staticType`/`rightOperand.staticType` are `dart:core String` — it does not distinguish a `String` that came from `Uri.path`/`HttpRequest.uri.path` from one that came from `File`/`Directory`/`FileSystemEntity`.
- `windows_rules.dart:435-436` — `_containsPathPattern(leftSource) || _containsPathPattern(rightSource)`, which (`windows_rules.dart:68-78`, delegating to `_hasPathAsWord`/`_hasCamelCaseWord` at `windows_rules.dart:82-127`) is a **pure source-text match on the identifier spelling**: it fires because the local variable is literally named `path` (`final String path = req.uri.path;`) and the constant is literally named `pathApiHealth` (`_hasCamelCaseWord` treats the capital `A` after `path` as a camelCase word boundary, so `pathApiHealth` counts as containing the word "path").

There is no static-type or receiver check anywhere in the rule that asks whether the `String` originates from `File`/`Directory`/`FileSystemEntity`/`path` package `Context`, vs. `Uri`/`HttpRequest`. `usesTypeResolution => true` (`windows_rules.dart:398`) is spent entirely on the string-vs-non-string check (`_isBothSidesString`), not on filesystem-origin detection. This is a case of "the identifier is named `path`" being conflated with "the value is a filesystem path" — exactly the class of bug the existing `_isNonPathStringLiteral`/`_isDartImportUri` exclusions (`windows_rules.dart:448-458`) were added to narrow, but neither exclusion covers `Uri.path`/`HttpRequest.uri.path`.

### Pattern 2 (3 sites) — the root-detection exemption is a literal-substring match that breaks under an intermediate variable

The rule already has a dedicated exemption for this exact idiom: `_isRootDetectionIdiom` (`windows_rules.dart:443`, implemented at `windows_rules.dart:480-514`). But `_isRootDetectionPair` (`windows_rules.dart:492-514`) determines the match **purely from the `toSource()` text** of each operand:
- one side's source must end with the literal substring `.path` but not `.parent.path` (line 494-495),
- the other side's source must end with the literal substring `.parent.path` (line 498),
- and the prefixes before those suffixes must be textually identical (line 513: `simpleBase == parentBase`).

The actual flagged code is:
```dart
final parent = dir.parent;
if (parent.path == dir.path) break;
```
Left operand source is `"parent.path"` (ends with `.path`, not `.parent.path` — OK as the "simple" side). Right operand source is `"dir.path"` — but `_isRootDetectionPair` requires the *other* side to end with the literal text `.parent.path`, and `"dir.path"` does not contain that substring at all (the `.parent` hop happened one statement earlier, when `parent` was assigned, and is invisible to a text-only check of the comparison expression itself). Both call orderings in `_isRootDetectionIdiom` (`windows_rules.dart:482-483`) fail for the same reason, so the exemption never engages once the `.parent` access is factored out into a named local variable — which is exactly what happens whenever the same `parent` value is also needed for the following `dir = parent;` reassignment (i.e., in every idiomatic multi-statement root-walk loop, as opposed to a single-expression `while (dir.path != dir.parent.path)`).

The rule's own fixture (`example/lib/windows/avoid_case_sensitive_path_comparison_fixture.dart:99-113`) only exercises the single-expression form (`dir.path != dir.parent.path` / `dir.parent.path == dir.path`) — never the two-statement form with an intermediate `parent` variable, which is the shape that appears in real root-walk loops that also need `dir = parent;` on the next line.

---

## Suggested Fix

**Pattern 1:** Before flagging, check whether either operand's static type/originating expression is `Uri`/`HttpRequest` (e.g. `expr is PropertyAccess && expr.target?.staticType?.getDisplayString() == 'Uri'`, or trace the declaring `VariableDeclaration`'s initializer for a `.uri.path`/`.path` access on a `Uri`/`HttpRequest`-typed receiver) and skip in that case, alongside the existing `_isDartImportUri` exclusion (`windows_rules.dart:455-458`) which already establishes the precedent of excluding case-sensitive-by-specification string kinds.

**Pattern 2:** Make `_isRootDetectionPair` (or a new sibling check) resolve through a single-hop local variable assignment: when one operand is `<var>.path` and `<var>` was declared in the immediately enclosing block by `final <var> = <otherBase>.parent;`, treat it as equivalent to `<otherBase>.parent.path` for the purposes of the base-expression comparison, rather than requiring the literal substring `.parent.path` in the comparison expression's own source text.

---

## Fixture Gap

The fixture at `example/lib/windows/avoid_case_sensitive_path_comparison_fixture.dart` should add:

1. **`Uri.path`/`HttpRequest.uri.path` receiver compared to a route constant** — expect NO LINT (Pattern 1; the single highest-value case, covering 119/122 real findings):
   ```dart
   void goodHttpRoutePath(Uri requestUri) {
     final String path = requestUri.path;
     if (path == '/api/health') {}
   }
   ```
2. **Root-detection idiom via an intermediate `.parent` variable** — expect NO LINT (Pattern 2):
   ```dart
   void goodRootDetectionIdiomViaVariable(_FakeDirectory dir) {
     while (true) {
       final parent = dir.parent;
       if (parent.path == dir.path) break;
       dir = parent;
     }
   }
   ```

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

## Finish Report (2026-09-18)

**Verdict: Valid, both patterns confirmed as described.**

### Root cause

`lib/src/rules/platforms/windows_rules.dart`, `AvoidCaseSensitivePathComparisonRule`:

- **Pattern 1 (HTTP route paths):** the rule had no notion of "this `String`
  came from `Uri.path`" — it only checked that both operands were
  `dart:core String` (`_isBothSidesString`) and that either side's source
  text contained the word "path" (`_containsPathPattern`). A local variable
  literally named `path`, holding `requestUri.path`, satisfied both checks
  with nothing to distinguish it from a real filesystem path.
- **Pattern 2 (root-walk via intermediate variable):** the existing
  `_isRootDetectionIdiom`/`_isRootDetectionPair` exemption matched purely on
  `toSource()` text, requiring one operand's source to literally end with
  `.parent.path`. Factoring the `.parent` hop into a local (`final parent =
  dir.parent;`) — needed anyway for the following `dir = parent;`
  reassignment — made that suffix invisible to the text-only check, so the
  exemption silently stopped firing for the idiomatic two-statement form.

### Fix

Both fixes are semantic (resolved-element based) rather than additional
text heuristics, per the report's own recommendation:

- Added `_isUriPathAccess(Expression)`: recognizes a `.path` property access
  whose receiver's **static type** display-strings as `Uri` (covers both
  direct `requestUri.path` and chained `request.uri.path`, since the
  immediate receiver of the final `.path` hop is always `Uri`-typed).
  Additionally traces back through a **single** local-variable assignment —
  resolving the identifier's `Element` and locating its declaring
  `VariableDeclaration` in the enclosing block via `declaredFragment.element`
  equality — so `final String path = requestUri.path; ... path == '/api'`
  is recognized too, not just the single-expression form. Wired in as a new
  early-return guard in `runWithReporter`, alongside the existing
  `_isDartImportUri` "case-sensitive by spec" exclusion.
- Rewrote the root-detection idiom check from string-suffix matching
  (`_isRootDetectionPair(String, String)`) to a semantic
  `_isRootDetectionIdiom(Expression, Expression)` built on a new
  `_rootPathSide(Expression)` classifier. It walks the actual
  `PropertyAccess`/`PrefixedIdentifier` AST shape of each operand, and when
  a `.path` receiver is a bare local variable, resolves that variable's
  declaration (same `_findLocalDeclaration` machinery as above) to check
  whether *its* initializer is `<base>.parent` — treating `parent.path` as
  equivalent to `dir.parent.path` when `parent` was assigned from
  `dir.parent`. The base-expression equality check (guarding against
  `a.path == b.parent.path` false-negatives, C15) is preserved unchanged.
- Both new helpers share `_asPropertyAccess` (normalizes `PropertyAccess`
  and `PrefixedIdentifier` into one `(target, property)` shape) and
  `_findLocalDeclaration` (resolves a `SimpleIdentifier`'s element back to
  its declaring `VariableDeclaration` by walking enclosing `Block`s).

Files changed: `lib/src/rules/platforms/windows_rules.dart` (added
`import 'package:analyzer/dart/element/element.dart';`, replaced the
string-based root-detection pair check, added `_isUriPathAccess`,
`_rootPathSide`, `_asPropertyAccess`, `_findLocalDeclaration`, and one new
early-return guard in `runWithReporter`).

### Tests added

- `example/lib/windows/avoid_case_sensitive_path_comparison_fixture.dart`:
  three new `LINT_NOT` cases — root-detection idiom via an intermediate
  `.parent` local (the exact two-statement shape from the report), direct
  `Uri.path` compared to a route constant, and `Uri.path` stored in a local
  variable named `path` before comparison. `LINT_COUNT` assertion left at 4
  (unchanged — all new cases are non-firing).
- `test/rules/platforms/avoid_case_sensitive_path_comparison_fixture_test.dart`:
  matching resolved-analyzer tests for the same three cases.

### Test results

- `dart analyze` on `lib/src/rules/platforms/windows_rules.dart`,
  `example/lib/windows/avoid_case_sensitive_path_comparison_fixture.dart`,
  and `test/rules/platforms/avoid_case_sensitive_path_comparison_fixture_test.dart`:
  no issues found.
- `dart test test/rules/platforms/avoid_case_sensitive_path_comparison_fixture_test.dart`:
  **26/26 passed**, including all pre-existing regression cases (mismatched
  root-detection bases still fire, import-URI suppression, snake_case
  boundaries, etc.) and the 3 new cases for this report.

### Proposed CHANGELOG line

- fix: `avoid_case_sensitive_path_comparison` no longer flags `Uri.path`/`HttpRequest.uri.path` HTTP route comparisons or the root-walk idiom when `.parent` is captured in an intermediate local variable

---

## Follow-up: soundness hardening (2026-09-18, same day)

An independent review of the fix above (Opus review, confirmed by running the
suite) found the first pass was **too broad** in two ways and flagged four
categories of new false negatives it would introduce. All four were real;
fixed the same day, before this report was filed away.

### Additional root causes found by review

1. `_isUriPathAccess` exempted **any** `Uri.path`, not just HTTP-request
   ones. `Platform.script.path == expectedPath` and `a.uri.path == b.path`
   (where `a`, `b` are `File`s) are filesystem paths wearing a `Uri`, and
   were going silent. It also compared `getDisplayString() == 'Uri'` —
   string-based — so a user class literally named `Uri` would be
   incorrectly exempted too (wrong library, same name).
2. `_findLocalDeclaration` traced through **any** local variable's
   initializer without checking mutability or reassignment. A `var` local
   reassigned before use, or a `final` local whose *base* expression
   (`dir` in `dir.parent`) was reassigned after capture, would still be
   trusted — silently exempting comparisons that were no longer sound.

### Fix (this pass)

- **Narrowed `_isUriPathAccess` → new `_isHttpRequestUri(Expression)`**:
  only exempts a `.path` receiver that is traceably an HTTP request Uri —
  `<request>.uri` / `.requestedUri` / `.url` where the receiver's static
  type name looks like a request object (`HttpRequest`, shelf's `Request`,
  or any `*Request`-suffixed type — see `_looksLikeHttpRequestType`), or a
  bare `Uri`-typed **formal parameter** (the route-handler shape from the
  original report), or a `final`/`const`, unreassigned local traced back
  to either of those. `Platform.script`, `File(...).uri`,
  `Directory(...).uri`, and any other `Uri` not traceable to a request
  object are deliberately left unexempted and keep linting.
- **Added `_isDartCoreUriType(DartType?)`**: checks both `element?.name ==
  'Uri'` AND `element?.library?.name == 'dart.core'`, so a same-named
  user class is never mistaken for `dart:core`'s `Uri`. Checking
  `.element` (not the display string) also means nullability is ignored
  correctly — `Uri?` matches the same as `Uri`.
- **Hardened `_findLocalDeclaration`**: now takes a `useOffset` and (a)
  skips any variable not declared `final`/`const`, and (b) returns `null`
  (refuses to trace) if the element is reassigned anywhere between the
  declaration and `useOffset`. Backed by a new
  `_reassignedBetween(Element, AstNode, int)` helper and a
  `_ReassignmentBetweenVisitor` (`RecursiveAstVisitor`) that scans the
  nearest enclosing `FunctionBody` for an `AssignmentExpression` whose LHS
  resolves to the target element in the given offset window — same
  pattern as the pre-existing `_ReassignmentVisitor` in
  `lib/src/rules/data/type_rules.dart`.
- **`_rootPathSide` additionally verifies the captured base is stable**:
  when tracing `parent.path` back to `dir.parent`, it now also checks that
  `dir` itself isn't reassigned between the `parent` declaration and the
  use site (via the same `_reassignedBetween`) — closing the `final parent
  = dir.parent; dir = other; ... parent.path == dir.path` gap. Only a bare
  `SimpleIdentifier` base is trusted this way; a more complex base
  expression is treated as unverifiable and left unexempted.

Files changed (same file as the original fix, no new files):
`lib/src/rules/platforms/windows_rules.dart` — added imports for
`package:analyzer/dart/ast/visitor.dart` and
`package:analyzer/dart/element/type.dart`; added `_isHttpRequestUri`,
`_isDartCoreUriType`, `_looksLikeHttpRequestType`, `_reassignedBetween`,
and the top-level `_ReassignmentBetweenVisitor` class; changed
`_findLocalDeclaration`'s signature to take `useOffset` and enforce
final/const + no-reassignment; updated all three call sites
(`_rootPathSide`, `_isUriPathAccess`, `_isHttpRequestUri`) accordingly.

### Tests added (this pass)

- `example/lib/windows/avoid_case_sensitive_path_comparison_fixture.dart`:
  six new `LINT` (true-positive) cases — `Platform.script.path`,
  `File(...).uri.path`, root-detection traced through a reassigned `var`
  local, Uri-path traced through a reassigned `var` local, root-detection
  where the captured base (`dir`) is reassigned after capture, and
  mismatched root-detection bases via an intermediate variable.
  `LINT_COUNT` updated from 4 to 10.
- `test/rules/platforms/avoid_case_sensitive_path_comparison_fixture_test.dart`:
  seven new resolved-analyzer tests — the six above plus a user-defined
  class literally named `Uri` (verifying the library check, not just the
  name check).

### Test results (this pass)

- `dart analyze` on `lib/src/rules/platforms/windows_rules.dart`,
  `example/lib/windows/avoid_case_sensitive_path_comparison_fixture.dart`,
  and `test/rules/platforms/avoid_case_sensitive_path_comparison_fixture_test.dart`:
  no issues found.
- `dart test test/rules/platforms/avoid_case_sensitive_path_comparison_fixture_test.dart`:
  **33/33 passed** (26 from the original fix + 7 new).
- `dart test test/rules/platforms/windows_rules_test.dart`: **12/12
  passed** (rule instantiation + fixture-existence checks for all 5
  Windows rules, unaffected by this change).

### Updated CHANGELOG line

- fix: `avoid_case_sensitive_path_comparison` no longer flags `HttpRequest.uri.path`/route-handler `Uri` parameters or the root-walk idiom when `.parent` is captured in an intermediate local variable — narrowly, so filesystem `Uri`s (`Platform.script`, `File(...).uri`) and unsound traces through reassigned locals still lint

---

## Follow-up 2: closing two more false negatives, and a scope narrowing (2026-09-18, same day)

A second Opus re-review, again confirmed by running the suite, found **two
more real false negatives** left by follow-up 1's `_isHttpRequestUri`. Both
verified and fixed the same day.

### Root causes found by this review

1. **Bare `Uri`-typed parameter was still exempt** (`_isHttpRequestUri`,
   the `element is FormalParameterElement && _isDartCoreUriType(...)`
   branch). `void check(Uri fileUri, String expectedPath) { if
   (fileUri.path == expectedPath) {} }` was silent — and the same leak
   through a `final` local. Nothing about a bare `Uri` parameter indicates
   it came from an HTTP request rather than, say, `File(...).uri` handed
   to the function by its caller.
2. **Name-suffix matching was still unsound** (`_looksLikeHttpRequestType`
   used `name.endsWith('Request')`). Any user-defined class whose name
   merely ends in "Request" — `class UploadRequest { Uri uri; }` — was
   treated as an HTTP request object; `r.uri.path == f.path` went silent.

### Fix (this pass)

- **Dropped the bare-parameter exemption entirely.** `_isHttpRequestUri`
  now only recognizes `<request>.uri` / `.requestedUri` / `.url` where
  `<request>`'s static type is identified by [`_isHttpRequestType`], plus
  tracing back through one `final`/`const`, unreassigned local to a
  qualifying expression. A `Uri` on its own — parameter or local — is
  never exempted.
- **`_isHttpRequestType`/`_isDartCoreUriType` switched from name-only (or
  name + `library.name`) checks to name + declaring **library URI**
  (`element.library.uri.toString()`), matching exactly dart:io's
  `HttpRequest` or package:shelf's `Request`/dart:core's `Uri` and
  rejecting same-named user classes outright. One wrinkle found by
  running the tests: `HttpRequest` is actually *declared* in `dart:_http`
  and merely re-exported through `dart:io` (confirmed by inspecting the
  Dart SDK's `lib/_http/http.dart`, which starts with `library
  dart._http;`) — `library.uri` reports the declaring library, not the
  import path callers use, so `_isHttpRequestType` accepts both
  `dart:_http` and `dart:io` for the `HttpRequest` name.
- Net effect: `_isDartCoreUriType` is still used, now as an extra sanity
  guard in `_isUriPathAccess` (the outer `.path` receiver must itself
  resolve to `dart:core`'s `Uri` before `_isHttpRequestUri` is even
  consulted) rather than for a parameter check that no longer exists.

Files changed (same file, no new files): `lib/src/rules/platforms/windows_rules.dart`
— removed the `FormalParameterElement` bare-`Uri` branch from
`_isHttpRequestUri` (and its now-unused `FormalParameterElement` type
reference); renamed `_looksLikeHttpRequestType` → `_isHttpRequestType` and
rewrote it to check `element.library.uri.toString()` against `dart:io` /
`dart:_http` (for `HttpRequest`) and a `package:shelf/` prefix (for
`Request`); rewrote `_isDartCoreUriType` to check
`element.library.uri.toString() == 'dart:core'` instead of the SDK's
informal `library.name`; wired `_isDartCoreUriType` into `_isUriPathAccess`
as a receiver-type guard.

### Does the original bug report's reproducer still hold?

**Checked first, as instructed, before making the change.** The report's
own "Reproducer / Pattern 1" code block is:
```dart
void route(Uri requestUri) {
  final String path = requestUri.path; // e.g. from HttpRequest.uri.path
  if (path == ServerConstants.pathApiHealth) {}
}
```
— a **bare** `Uri`-typed parameter, not an `HttpRequest`. Dropping the
bare-parameter exemption necessarily makes this exact minimal snippet
start linting again, because nothing distinguishes it from `File(...).uri`
handed to the same function signature — that ambiguity is precisely the
false negative this pass closes, and the report's own comment
(`// e.g. from HttpRequest.uri.path`) already hints the real shape is one
level removed from the literal parameter type shown.
Critically, the report's **evidence section is explicit that this
minimized snippet is not the real code**: "119 sites... compare an HTTP
request URL path (`Uri.path` via `HttpRequest.uri.path`)" and "Minimal
reduction of `saropa_drift_advisor/lib/src/server/router.dart:147,157-158`
and `lib/src/server/compare_handler.dart:43`". The actual 119/122
real-world findings go through `HttpRequest.uri.path` (or the local
`Uri.path` result of that chain), not a bare `Uri` parameter — and that
shape **is** soundly and fully covered by the current fix (see the
`goodHttpRoutePathDirect`/`goodHttpRoutePath` fixture cases, now using an
`HttpRequest` parameter, and their matching resolved-analyzer tests, both
passing).
**Verdict: the report is fully fixed for its real underlying pattern
(`HttpRequest.uri.path`, 119/122 + the 3/122 root-walk sites = 122/122),
not just "partially fixed."** Only the report's own minimized
`Uri requestUri`-parameter reproducer — which its own text acknowledges is
a simplification of the real `HttpRequest.uri.path` shape — no longer gets
the exemption, because exempting it soundly is impossible without
resolving the ambiguity the two reviews correctly flagged.

### Tests added (this pass)

- `example/lib/windows/avoid_case_sensitive_path_comparison_fixture.dart`:
  - Changed `goodHttpRoutePathDirect`/`goodHttpRoutePath` from a bare
    `Uri requestUri` parameter to an `HttpRequest request` parameter,
    matching the real-world shape confirmed above (still `LINT_NOT`).
  - Three new `LINT` (true-positive) cases: `badBareUriParameterPath` and
    `badBareUriParameterPathViaLocal` (leak #1), and
    `badUploadRequestUriPath` with a `class UploadRequest { final Uri
    uri; }` (leak #2). `LINT_COUNT` updated from 10 to 13.
- `test/rules/platforms/avoid_case_sensitive_path_comparison_fixture_test.dart`:
  - Updated the two "does NOT fire" HTTP-path tests to use `HttpRequest`
    instead of a bare `Uri` parameter.
  - Four new resolved-analyzer true-positive tests: bare `Uri` parameter
    compared directly, the same leaked through a `final` local, a
    user-defined `UploadRequest` class (name-suffix leak), and a
    hand-rolled `class Request` (exact-name leak, not package:shelf's).

### Test results (this pass)

- `dart analyze` on `lib/src/rules/platforms/windows_rules.dart` and
  `example/lib/windows/avoid_case_sensitive_path_comparison_fixture.dart`:
  no issues found (one intermediate `unused_element` warning on
  `_isDartCoreUriType`, from briefly being orphaned mid-edit, was resolved
  by wiring it into `_isUriPathAccess` as described above).
- `dart test test/rules/platforms/avoid_case_sensitive_path_comparison_fixture_test.dart
  test/rules/platforms/windows_rules_test.dart`: **49/49 passed** (37 from
  the fixture test file + 12 from `windows_rules_test.dart`). First attempt
  caught a real bug in this pass itself — the two `HttpRequest`-based
  `LINT_NOT` tests failed because `_isHttpRequestType` checked
  `libraryUri == 'dart:io'` only, and `HttpRequest` is actually declared in
  `dart:_http`; fixed by accepting both URIs (see Fix section above), then
  the full suite passed.
- Mid-run, `lib/src/rules/security/security_network_input_rules.dart` was
  transiently broken twice by a concurrent agent's edits (unrelated file,
  unrelated rule); did not touch it, waited for it to stabilize, then
  reran.

### Final CHANGELOG line

- fix: `avoid_case_sensitive_path_comparison` no longer flags `HttpRequest.uri.path`/package:shelf `Request.uri.path` comparisons or the root-walk idiom when `.parent` is captured in an intermediate local variable — soundly narrow: identified by declaring library (not name), so filesystem `Uri`s (`Platform.script`, `File(...).uri`), bare `Uri`-typed parameters, same-named user classes (`class UploadRequest`, `class Request`), and unsound traces through reassigned locals all still lint

---

## Environment

- saropa_lints version: 16.2.1 resolved (checkout under investigation: `9456b83e`, `v16.2.1-13-g9456b83e`; rule source unchanged since v16.2.1)
- Dart SDK version: 3.12.2 (stable)
- custom_lint version: n/a — findings from `saropa_lints scan` CLI / VS Code extension
- Triggering project/file: `saropa_drift_advisor` 4.4.1 — `lib/src/server/router.dart` (117 sites), `lib/src/server/compare_handler.dart` (2 sites), `lib/src/server/generation_handler.dart` (3 sites, lines 736-738/763-765/796-798). Scan report: `saropa_drift_advisor/reports/20260918/20260918_081229_findings.json`
