# BUG: `IgnoreUtils.hasIgnoreComment` — leading `// ignore:` not honored on a doc-commented declaration reported via `atNode`

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-20
Rule: infrastructure — `IgnoreUtils.hasIgnoreComment` (affects every rule that reports a doc-commented declaration via `reporter.atNode`)
File: `lib/src/ignore_utils.dart` (`_nodeHasLeadingIgnore`, line ~406; entry `hasIgnoreComment`, line ~226)
Severity: High — forces unusual `// ignore:` placement (above the doc comment) or a trailing workaround; the conventional below-doc placement silently suppresses nothing
Rule version: n/a (infra) | Since: unknown | Updated: 14.0.5

---

## Summary

A `// ignore: <rule>` written on the line **immediately above a declaration but below that declaration's `///` doc comment** (the conventional, analyzer-standard placement) is **not honored** when the diagnostic is reported via `reporter.atNode(node)` and `node` is an `AnnotatedNode` (declaration with a doc comment). The suppression silently does nothing and the diagnostic still fires.

It should be honored: this is the same `///`-then-`// ignore:`-then-declaration ordering that `hasLeadingIgnoreCommentBeforeToken` (the `atToken` path) and the ancestor-walk in `hasIgnoreComment` already handle correctly. Only the **self-node** leading probe was left with the bug.

---

## Attribution Evidence

The affected logic is infra (`IgnoreUtils`), exercised by these rules in a downstream project (Saropa Contacts). Positive grep proves the rules — and the ignore utility — live in `saropa_lints`:

```bash
grep -rn "'require_file_close_in_finally'" lib/src/rules/
# lib/src/rules/resources/resource_management_rules.dart:65: 'require_file_close_in_finally',

grep -rn "'require_http_status_check'" lib/src/rules/
# lib/src/rules/network/api_network_rules.dart:60: 'require_http_status_check',

grep -rn "'avoid_global_state'" lib/src/rules/
# lib/src/rules/architecture/structure_rules.dart:449: 'avoid_global_state',
```

All three report via `reporter.atNode(node)`:

```bash
grep -n "atNode" lib/src/rules/resources/resource_management_rules.dart
# 148: reporter.atNode(node);  (and 274/454/612/778…)
```

**Emitter:** `lib/src/saropa_lint_rule.dart` `atNode` (line ~3008) → `_isSuppressed` (line ~3081) → `IgnoreUtils.hasIgnoreComment` (`lib/src/ignore_utils.dart:226`).
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` / `_generated_diagnostic_collection_name_#2` (generic analysis-server label — not attribution; grep above is the attribution).
**Negative grep:** these rule names do not resolve in any sibling repo; the ignore utility is unique to `saropa_lints`.

**Ground truth:** reproduced with `dart run saropa_lints scan . --resolve --files <file> --format json` (the standalone scanner; not `flutter analyze`, which does not load the plugin).

---

## Reproducer

Minimal — any rule that reports a doc-commented declaration via `atNode`. Using `avoid_global_state` (single-line top-level var) is the smallest:

```dart
/// Lazy cache built on first access.
// ignore: avoid_global_state -- deliberate library-private lazy cache
List<int>? _cache;   // ACTUAL: still LINTs.  EXPECTED: suppressed.
```

Method form (same bug, and the trailing workaround below does NOT save it):

```dart
/// Raw-Response GET wrapper; callers inspect statusCode.
// ignore: require_http_status_check -- by design, pass-through wrapper
static Future<Response> getResponse(Uri uri) {   // ACTUAL: still LINTs.
  return http.get(uri);
}
```

**Placements observed (all via `--resolve` scan, saropa_lints 14.0.5):**

| Placement | Single-line decl | Multi-line decl (method) |
|---|---|---|
| `// ignore:` on line below doc, above decl (conventional) | **NOT honored** | **NOT honored** |
| Trailing `// ignore:` on the decl's first line | honored (trailing matches `node.end` line, which == decl line for single-line) | **NOT honored** (`node.end` is the closing `}` line, many lines down) |
| `// ignore:` on the line **above the doc comment** | honored | honored |
| No doc comment, `// ignore:` on line above decl | honored | honored |

**Frequency:** Always, when a `///` doc comment immediately precedes a below-doc `// ignore:` on a declaration reported via `atNode`.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | Below-doc `// ignore:` on the line immediately above the declaration suppresses the diagnostic (matches `dart analyze` semantics and the `atToken` path). |
| **Actual** | Diagnostic still fires; suppression silently no-ops. |

---

## AST Context

```
TopLevelVariableDeclaration / MethodDeclaration   ← AnnotatedNode; rule reports here via atNode
  ├─ Comment (///)                                ← node.beginToken; node.offset points HERE
  ├─ (// ignore: ...)                             ← hangs off firstTokenAfterCommentAndMetadata.precedingComments
  └─ keyword `static` / type `List<int>?`         ← firstTokenAfterCommentAndMetadata
```

`atNode` adjusts the **reported** offset to `firstTokenAfterCommentAndMetadata.offset` (line ~3010) so the diagnostic lands on the `static`/type line — but the **suppression** check does not use that adjusted line.

---

## Root Cause

`atNode` → `_isSuppressed(adjustedOffset, node)` → `IgnoreUtils.hasIgnoreComment(node, ruleName)`.

In `hasIgnoreComment` (line ~234):

```dart
final int nodeStartLine = lineInfo?.getLocation(node.offset).lineNumber ?? -1;
// For an AnnotatedNode, node.offset == doc-comment offset (the `///` line),
// NOT the declaration keyword line.
if (_nodeHasLeadingIgnore(node, ruleName, nodeStartLine, lineInfo)) return true;
```

`_nodeHasLeadingIgnore` (line ~406) DOES probe the post-doc token for an `AnnotatedNode`:

```dart
if (node is AnnotatedNode) {
  final Token postDoc = node.firstTokenAfterCommentAndMetadata;
  if (!identical(postDoc, node.beginToken) &&
      _hasValidLeadingIgnoreComment(postDoc, ruleName, nodeStartLine, lineInfo)) { // <-- BUG
```

It passes `nodeStartLine` (the **doc-comment** line) for the post-doc token. Inside `_hasValidLeadingIgnoreComment` the guard is `commentLine == nodeStartLine || commentLine == nodeStartLine - 1`. The `// ignore:` is on `declLine - 1`, but it is compared against `docLine - 1`, so it never matches.

The ancestor-walk already computes the corrected line:

```dart
final int referenceOffset = current is AnnotatedNode
    ? current.firstTokenAfterCommentAndMetadata.offset
    : current.offset;
```

…but the **self-node** call at line ~239 does not — it reuses the doc-based `nodeStartLine`. `hasLeadingIgnoreCommentBeforeToken` (the `atToken` path) recomputes from the token and is correct, which is why `atToken`-reporting rules are unaffected.

---

## Suggested Fix

In `_nodeHasLeadingIgnore`, when probing the post-doc token of an `AnnotatedNode`, compute the reference line from the **post-doc token's** offset, not the passed-in `nodeStartLine`:

```dart
if (node is AnnotatedNode) {
  final Token postDoc = node.firstTokenAfterCommentAndMetadata;
  if (!identical(postDoc, node.beginToken)) {
    // The leading `// ignore:` sits immediately above the declaration keyword,
    // not above the `///` doc comment. node.offset (and thus nodeStartLine)
    // points at the doc comment, so the post-doc probe must key off the
    // declaration token's OWN line — matching the ancestor-walk and
    // hasLeadingIgnoreCommentBeforeToken.
    final int postDocLine =
        lineInfo?.getLocation(postDoc.offset).lineNumber ?? nodeStartLine;
    if (_hasValidLeadingIgnoreComment(postDoc, ruleName, postDocLine, lineInfo)) {
      return true;
    }
  }
}
```

This widens nothing else: the `///` lines never contain `ignore:`, and the guard remains `== line` / `== line - 1`. It only fixes the line the post-doc token is compared against.

Alternatively (broader): have `_isSuppressed` / `hasIgnoreComment` accept the adjusted offset that `atNode` already computed, and key `nodeStartLine` off that for `AnnotatedNode`s.

---

## Fixture Gap

The ignore-utils fixture/tests should include, for a rule that reports via `atNode`:

1. Doc-commented top-level variable, `// ignore:` below doc / above decl — expect SUPPRESSED.
2. Doc-commented method, `// ignore:` below doc / above signature — expect SUPPRESSED.
3. Doc-commented method, trailing `// ignore:` on the signature's first line — document whether this is intended to work (currently does not, because `node.end` is the `}` line).
4. Same declarations with NO doc comment — already SUPPRESSED (guard against regression).

---

## Downstream workaround in place

Saropa Contacts (the triggering project) currently places the `// ignore:` **above the doc comment** for the two method sites and uses a **trailing** ignore for the single-line variable, with a comment pointing at this bug:

- `lib/service/web_service/web_service_utils.dart` (`require_http_status_check`)
- `lib/service/backup/backup_cloud_google_drive_adapter.dart` (`require_file_close_in_finally`)
- `lib/utils/event/astronomical/lat_lng_to_timezone/_decision_tree.dart` (`avoid_global_state`, trailing)

Once this is fixed, those can move back to the conventional below-doc placement.

---

## Environment

- saropa_lints version: 14.0.5
- Dart SDK version: 3.12.1 (stable)
- custom_lint version: n/a (native analysis_server_plugin)
- Triggering project/file: Saropa Contacts — the three files listed above

---

## Finish Report (2026-06-20)

`_nodeHasLeadingIgnore` in `lib/src/ignore_utils.dart` now computes the
reference line for the post-doc probe from the post-doc token's OWN offset
(`firstTokenAfterCommentAndMetadata`), not the passed-in `nodeStartLine` (which
for an `AnnotatedNode` is the `///` doc-comment line). This matches the
ancestor-walk's `referenceOffset` and `hasLeadingIgnoreCommentBeforeToken`, so a
below-doc `// ignore:` directly above the declaration keyword is now honored when
the diagnostic is reported on the declaration node itself via `atNode`. Took the
narrow suggested fix; nothing else widened — the `///` lines never contain
`ignore:`, and the `== line` / `== line - 1` guard is unchanged.

Tests: new group `leading comments on doc-commented declarations` in
`test/utils/ignore_utils_test.dart` covers below-doc ignore on a doc-commented
top-level variable and method (the self-node `atNode` cases that were broken),
plus above-doc, no-doc, and unrelated-rule regression guards. The pre-existing
`// ignore: below a /// doc comment` group covers child-node diagnostics (the
ancestor-walk path, which was already correct) — distinct from this fix.

Full `dart test test/utils/ignore_utils_test.dart` passes (74 tests).

The Saropa Contacts downstream workaround sites listed above can move back to the
conventional below-doc placement once they pick up a release with this fix.
