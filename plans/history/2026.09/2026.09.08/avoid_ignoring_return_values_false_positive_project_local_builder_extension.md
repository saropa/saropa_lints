# BUG: `avoid_ignoring_return_values` — hardcoded stdlib allowlist misses project-local builder-pattern extensions

**Status: Fixed**

Created: 2026-09-08
Rule: `avoid_ignoring_return_values`
File: `lib/src/rules/code_quality/code_quality_avoid_rules.dart` (line ~4172)
Severity: False positive
Rule version: v1

---

## Summary

The rule reports any bare `ExpressionStatement` invocation whose return
value isn't consumed, exempting only a fixed `_safeToIgnore` set of ~30
stdlib method NAMES (`add`, `remove`, `setState`, `dispose`, ...). A
project-local extension method that follows the exact same
mutate-in-place-and-return-a-status-bool convention as `List.add` — e.g. an
`_appendNamePart(...)` extension used as a builder-pattern mutator whose
`bool` return (did-it-append) is never needed by any call site because the
emptiness check is already done inline before/after the call — is flagged,
because the allowlist is a closed, hardcoded set of literal method names
with no path for a project to register its own equivalents.

---

## Attribution Evidence

```bash
grep -rn "'avoid_ignoring_return_values'" lib/src/rules/
# lib/src/rules/code_quality/code_quality_avoid_rules.dart:4191:    'avoid_ignoring_return_values',
```

**Emitter registration:** `lib/src/rules/code_quality/code_quality_avoid_rules.dart:4191`
**Rule class:** `AvoidIgnoringReturnValuesRule` — defined at
`lib/src/rules/code_quality/code_quality_avoid_rules.dart:4172`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

```dart
class NameSpans {
  final List<InlineSpan> spans = <InlineSpan>[];
}

extension NameTextSpanExtensions on NameSpans {
  /// Builder-pattern mutator, structurally identical to `List.add`: mutates
  /// `this.spans` in place and returns whether it appended anything. Every
  /// call site already knows the answer via an inline `isNotEmpty`/similar
  /// guard either just before or just after the call, so the bool return is
  /// never consulted anywhere in this class.
  bool appendNamePart(String? part) {
    if (part == null || part.isEmpty) return false;
    spans.add(TextSpan(text: part));
    return true;
  }
}

void example(NameSpans target, String? givenName) {
  if (givenName != null && givenName.isNotEmpty) {
    // Same shape as `list.add(x);` (which IS on the allowlist) — but
    // `appendNamePart` is a project-local extension method, not one of the
    // ~30 hardcoded stdlib names in `_safeToIgnore`, so it's flagged.
    target.appendNamePart(givenName); // LINT — but should NOT lint
  }
}
```

**Frequency:** Always, for any project-defined method/extension whose
return value is a "did the mutation happen" convenience flag in the same
spirit as `List.add`'s bool, since the allowlist only recognizes literal
stdlib names.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic, OR a materially weaker signal — the call follows the exact same ignorable-bool-return convention as the allowlisted `List.add` |
| **Actual** | `[avoid_ignoring_return_values] Return value of this invocation is ignored...` reported on `target.appendNamePart(givenName);` |

---

## AST Context

```
ExpressionStatement
  └─ MethodInvocation (target.appendNamePart(givenName))
      — methodName.name == 'appendNamePart'
      — NOT in _safeToIgnore (fixed set of ~30 stdlib names)
      — staticType of the invocation: bool (non-void, non-Future) -> reported
```

---

## Root Cause

`lib/src/rules/code_quality/code_quality_avoid_rules.dart:4202-4242`:

```dart
static const Set<String> _safeToIgnore = <String>{
  'print', 'debugPrint', 'debugPrintStack', 'log', 'setState',
  'add', 'addAll', 'addEntries', 'remove', 'removeAt', 'removeLast',
  'removeWhere', 'retainWhere', 'clear', 'insert', 'insertAll', 'sort',
  'shuffle', 'fillRange', 'setAll', 'setRange', 'replaceRange',
  'update', 'putIfAbsent', 'updateAll',
  'addPostFrameCallback', 'addPersistentFrameCallback', 'scheduleMicrotask',
  'runZoned', 'close', 'dispose', 'cancel',
  'write', 'writeln', 'writeAll', 'writeCharCode',
};
```

### Hypothesis A (confirmed): closed, non-extensible allowlist

The check further down (not shown here, past line 4260) presumably tests
`methodName != null && _safeToIgnore.contains(methodName)` before falling
through to reporting. Because the set is a hardcoded compile-time
constant, a project's own extension methods (or instance methods on
project-local classes) that follow the identical "mutate in place, return a
convenience bool" contract have no way to be recognized as safe — the rule
can only special-case names it ships with, not a *pattern* (return type is
`bool`/`void`-adjacent convenience flag; the enclosing class is
project-local; the method name matches a mutate-verb heuristic like
`add*`/`append*`/`insert*`/`update*`).

---

## Suggested Fix

Two complementary options, in order of robustness:

1. **Project-configurable allowlist extension.** Let a project add entries
   to `_safeToIgnore` (or a parallel project-level set merged with the
   built-in one) via `saropa_lints` config — the same mechanism already
   suggested for the sibling `require_ios_accessibility_large_text` report
   filed alongside this one. This directly unblocks project-local builder
   extensions without weakening the rule's stdlib coverage.
2. **Heuristic pattern match as a secondary signal.** For a method not in
   the fixed allowlist, additionally allow when: (a) it's declared as an
   `extension` method (not a raw top-level/library function) AND (b) its
   name starts with a known mutate-verb prefix (`add`, `append`, `insert`,
   `remove`, `update`, `set`) AND (c) its return type is `bool` or the
   declared type of `this`/the extended type (self-returning builder
   chains). This is heuristic and could still miss cases, so option 1 is
   the primary recommendation.

---

## Fixture Gap

The fixture (find via `grep -rn 'AvoidIgnoringReturnValuesRule' example_packages/`) should include:

1. **An extension method matching the `List.add`-style
   mutate-and-return-bool convention, called as a bare
   `ExpressionStatement`** — expect NO lint once a project-allowlist or
   heuristic fix lands (currently LINTs, this report's reproducer).
2. Keep existing **arbitrary non-allowlisted method with an ignored,
   meaningfully-informative return value** (e.g. a parse result, an HTTP
   response) — expect LINT (already covered, must still fire — this is the
   rule's actual bug-catching case and must not regress).

---

## Changes Made

Implemented Suggested Fix option 2 (heuristic pattern match), not option 1
(project-configurable allowlist) — no config plumbing needed for this class
of false positive.

`lib/src/rules/code_quality/code_quality_avoid_rules.dart`
(`AvoidIgnoringReturnValuesRule`):

- Added `_mutateVerbPrefixes` (`add`, `append`, `insert`, `remove`, `update`,
  `set`) and `_isMutateVerbName()`, a camelCase-boundary-aware prefix check
  (so `setup`/`additional` don't false-match).
- Added `_isDeclaredOnLocalExtension(Element?, String filePath)`, checking
  `element.enclosingElement is ExtensionElement` AND that the extension's
  library is in the current project's own package (same package-name
  comparison as `AvoidDeprecatedUsageRule._isSamePackage` elsewhere in this
  file) — a code-review pass on this fix flagged that an extension-name/
  bool-return check alone would also exempt third-party package extensions
  whose ignored `bool` is a genuine validation result, not a mutate-and-
  forget convenience flag.
- In `runWithReporter`, after the existing `_safeToIgnore` and cascade
  checks: skip when the invocation is a `MethodInvocation` with a `bool`
  return type, a mutate-verb name, and is declared on a same-package
  `extension`.
- Bumped rule version marker `{v1}` → `{v2}` and doc comment (`Updated:
  v16.2.1`, new **Exempt**/**GOOD** text).

## Tests Added

`example/lib/code_quality/avoid_ignoring_return_values_fixture.dart`: added
a `_NameSpans`/`_NameTextSpanExtensions` GOOD case reproducing the exact
`appendNamePart` shape from the bug report (extension, mutate-verb name,
`bool` return) — expected to NOT lint.

## Verification

`dart run saropa_lints scan example --tier comprehensive --resolve --files
lib/code_quality/avoid_ignoring_return_values_fixture.dart --format json`:
`avoid_ignoring_return_values` fires exactly once, on line 8 (`list.map(...)`
in the pre-existing `_bad` case). The new `appendNamePart` GOOD case at
line ~40 does not fire. Confirms the fix suppresses the false positive
without weakening the rule's real bug-catching case.

---

## Finish Report (2026-09-08)

`avoid_ignoring_return_values` reported a false positive on any project-local
`extension` method following the `List.add` mutate-and-return-bool
convention, because its exemption list was a closed set of ~30 hardcoded
stdlib method names with no path to recognize an equivalent project-defined
pattern.

The fix adds a structural exemption alongside the existing name-based
allowlist: a bare-statement invocation is also skipped when it is a
`MethodInvocation` with a `bool` return type, a mutate-verb name (`add*`,
`append*`, `insert*`, `remove*`, `update*`, `set*`, matched with a
camelCase-boundary check so `setup`/`additional` don't false-match), and the
invoked method is declared inside an `extension` block defined in the
current project's own package. The package-scoping check reuses the same
`package:` URI comparison as `AvoidDeprecatedUsageRule._isSamePackage`
elsewhere in the same file.

A same-package restriction was added after an independent code-review pass
on the initial implementation: an extension-name/bool-return check alone
would also have exempted third-party package extensions whose ignored
`bool` is a genuine result the rule is designed to catch, not a
mutate-and-forget convenience flag.

Verified via `dart run saropa_lints scan example --tier comprehensive
--resolve --files lib/code_quality/avoid_ignoring_return_values_fixture.dart
--format json`: the rule fires exactly once, on the pre-existing real
violation (`list.map(...)` discarded), and does not fire on the new
extension-mutator fixture case. `dart test
test/integrity/anti_pattern_detection_test.dart
test/integrity/saropa_lints_test.dart
test/rules/code_quality/code_quality_rules_test.dart` — 250/250 passed.

Rule version bumped `{v1}` → `{v2}`; doc comment `Updated` stamp set to
`v16.2.1` (the in-progress unreleased version per `CHANGELOG.md`).

---

## Commits

<!-- Add commit hash when committed. -->

---

## Environment

- saropa_lints version: v1 (rule version)
- Triggering project/file: `d:/src/contacts` —
  `lib/components/contact/contact_display_name.dart:203,209,217,284,293,298,305,314,324,329`
  (10 call sites, all `_appendNamePart`-family builder-pattern mutators on
  `NameTextSpanExtensions`).
