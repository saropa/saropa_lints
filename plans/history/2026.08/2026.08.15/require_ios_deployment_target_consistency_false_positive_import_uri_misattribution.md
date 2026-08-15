# BUG: `require_ios_deployment_target_consistency` — Matches `import 'dart:async'`'s URI String Against the "Swift `async`" API Heuristic

**Status: Fixed**

Created: 2026-08-15
Rule: `require_ios_deployment_target_consistency`
File: `lib/src/rules/platforms/ios_platform_lifecycle_rules.dart` (line ~1763)
Severity: False positive
Rule version: v2 | Since: v2.4.0 | Updated: v4.13.0

---

## Summary

The rule's detection is a plain substring match (`value.contains(api)`)
against every `SimpleStringLiteral` in the file, including import/export URI
strings — it never excludes directive URIs the way sibling rules
(`no_magic_string`, via `isInImportOrExport`) do. Because `'async'` is one of
the tracked "iOS 15+ Swift concurrency" markers, the literal Dart import
`import 'dart:async';` — whose URI string is `'dart:async'`, which contains
the substring `"async"` — is misread as Swift's `async`/`await` keyword usage
and flagged as an iOS-15-requiring API call. The diagnostic lands directly on
the import URI string node, which sits near the top of the import block
(explaining the "misattributed to line 1/2" symptom), not anywhere near an
actual iOS API call site.

---

## Attribution Evidence

```bash
grep -rn "'require_ios_deployment_target_consistency'" lib/src/rules/
# lib/src/rules/platforms/ios_platform_lifecycle_rules.dart:1786:    'require_ios_deployment_target_consistency',
```

**Emitter registration:** `lib/src/rules/platforms/ios_platform_lifecycle_rules.dart:1786`
**Rule class:** `RequireIosDeploymentTargetConsistencyRule` — registered in `lib/src/rules/all_rules.dart`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

Verified directly against `lib/main.dart:119`:

```dart
// LINT — but should NOT lint: this is the Dart core `dart:async` library
// import (Future, Stream, Timer, unawaited, ...), not a reference to Swift's
// iOS 15+ structured-concurrency `async`/`await` keyword. The rule's
// substring check against the literal text 'async' matches the import URI
// string 'dart:async' regardless.
import 'dart:async';

void doWork() {}
```

**Frequency:** Always, for any file that imports `dart:async` (or any package
whose URI happens to contain "SharePlay", "GroupActivities",
"AttributedString", or "async" as a substring) and does not separately
contain the string `'@available'`, `'ProcessInfo'`, or
`'operatingSystemVersion'` anywhere in the file (the rule's only escape
hatch, checked once at file level).

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — a `dart:async` import has nothing to do with iOS deployment targets or Swift concurrency |
| **Actual** | `[require_ios_deployment_target_consistency] API requiring iOS 15+ detected. Ensure minimum deployment target matches or add version guards.` reported at the import URI string literal (`'dart:async'`), which sits at/near the top of the file's import block |

---

## AST Context

```
CompilationUnit
  └─ ImportDirective ('dart:async')
      └─ uri: SimpleStringLiteral ('dart:async')   ← context.addSimpleStringLiteral visits this;
                                                        node.value == 'dart:async'; .contains('async') == true
                                                        reporter.atNode(node) reports HERE — the import
                                                        statement itself, not any iOS API call site
```

---

## Root Cause

`RequireIosDeploymentTargetConsistencyRule.runWithReporter`
(`lib/src/rules/platforms/ios_platform_lifecycle_rules.dart:1802-1825`):

```dart
context.addSimpleStringLiteral((SimpleStringLiteral node) {
  final String value = node.value;
  for (final String api in _ios15PlusApis.keys) {
    if (value.contains(api)) {
      reporter.atNode(node);
      return;
    }
  }
});
```

with `_ios15PlusApis` (lines 1795-1800) including the bare key `'async'`
mapped to `'iOS 15+ (Swift concurrency)'`. Two compounding gaps:

1. **No directive exclusion.** `context.addSimpleStringLiteral` registers for
   every `SimpleStringLiteral` node in the file, and an `ImportDirective`'s
   `uri` IS a `SimpleStringLiteral` in the analyzer AST. The rule never
   checks `node.thisOrAncestorOfType<ImportDirective>()` (or
   `ExportDirective`/`PartDirective`) to skip directive URIs, unlike
   `NoMagicStringRule`, which explicitly guards with `isInImportOrExport(node)`
   (`lib/src/rules/data/numeric_literal_rules.dart` — see the sibling
   `no_magic_string` report for that helper's usage).
2. **Substring match, not identifier/keyword match.** `value.contains(api)`
   for `api == 'async'` matches ANY string containing that four-letter
   sequence — `'dart:async'`, but equally `'package:async/async.dart'`, a
   comment-derived string like `'Waiting for async operation'`, or any other
   incidental occurrence. The check has no way to distinguish "the Dart
   keyword/library named async" from "Swift's `async` keyword used as an iOS
   15+ API," because it never inspects Swift source or a
   platform-appropriate context at all — it's scanning arbitrary Dart string
   literal contents for an English word.

The file-level escape hatch (lines 1809-1814: skip entirely if the file
contains `'@available'`, `'ProcessInfo'`, or `'operatingSystemVersion'`) does
not help here, since a typical Dart file has no reason to contain any of
those Swift/Obj-C tokens.

---

## Suggested Fix

At minimum, exclude directive URIs the same way `no_magic_string` does:

```dart
context.addSimpleStringLiteral((SimpleStringLiteral node) {
  if (node.thisOrAncestorOfType<UriBasedDirective>() != null) return;
  ...
});
```

Longer-term: this rule's premise (grep Dart string literals for iOS
API/keyword names) cannot reliably detect Swift API usage from Dart source at
all — Dart code calling into iOS APIs does so through platform channels or
plugin method names, not literal occurrences of Swift keywords in Dart
strings. Narrowing `_ios15PlusApis` to remove the bare `'async'` entry (or
requiring a word-boundary match anchored to a platform-channel method-name
context) would remove this specific false-positive class without waiting for
a full redesign.

---

## Fixture Gap

The fixture at
`example*/lib/platforms/require_ios_deployment_target_consistency_fixture.dart`
should include:

1. `import 'dart:async';` at the top of a file with no other iOS-related
   content — expect NO lint (current: LINT)
2. `import 'package:async/async.dart';` — expect NO lint (same substring
   trap, different package)
3. A genuine Swift-bridging string used in a `MethodChannel` call name
   containing `'SharePlay'` or similar — current intended behavior,
   documented for whoever redesigns the detection, not necessarily "expect
   LINT" until a better signal than substring-in-Dart-string exists

---

## Changes Made

`RequireIosDeploymentTargetConsistencyRule.runWithReporter`
(`lib/src/rules/platforms/ios_platform_lifecycle_rules.dart`) now calls the
existing `isInImportOrExport` helper (from `literal_context_utils.dart`, the
same helper `no_magic_string` uses) at the top of the
`addSimpleStringLiteral` callback and returns early for any string literal
inside an `ImportDirective`/`ExportDirective` URI, before running the
substring check against `_ios15PlusApis`.

---

## Tests Added

`example/lib/ios/require_ios_deployment_target_consistency_fixture.dart`:
imports `dart:async` and `package:async/async.dart` at file scope (expect NO
lint) and a genuine `'SharePlay.startSession'` method-channel-style string
literal (expect LINT). Verified directly with the scan CLI against a
throwaway file outside `example/` (the CLI's file-list resolver hardcodes an
`/example` exclusion, so `example/` fixtures can't be scanned that way,
per `saropa-lints-diagnostics-and-tooling`/prior triage) — the import-only
case produces zero diagnostics and the `SharePlay` case fires exactly this
rule (and `require_ios_minimum_version_check`, an unrelated sibling rule
matching the same string).

---

## Commits

_Pending — not yet committed._

---

## Environment

- saropa_lints version: (repo HEAD at filing time)
- Dart SDK version: n/a
- custom_lint version: n/a
- Triggering project/file: downstream Flutter/Dart app (contacts),
  `lib/main.dart:119` (`import 'dart:async';`) — confirmed the one substring
  match present in that file at filing time; prior triage reported 3
  occurrences of this rule firing in the file, consistent with the same
  import-URI mechanism recurring wherever `dart:async` (or another
  substring-matching import URI) appears across the affected files.

---

## Finish Report (2026-08-15)

`require_ios_deployment_target_consistency` reported an iOS-15+ Swift
concurrency warning on any Dart file importing `dart:async` (or any URI
containing the substring "async", e.g. `package:async/async.dart`), because
its detection walked every `SimpleStringLiteral` in the file — including
`ImportDirective`/`ExportDirective` URIs — without excluding directive
context the way sibling rules already do.

The fix adds a single early-return guard in
`RequireIosDeploymentTargetConsistencyRule.runWithReporter`
(`lib/src/rules/platforms/ios_platform_lifecycle_rules.dart`): before running
the substring check against `_ios15PlusApis`, the callback now calls the
existing `isInImportOrExport` helper (`lib/src/literal_context_utils.dart`)
and skips any string literal that is part of an import or export directive.
No other rule behavior changed — a genuine iOS 15+ API name/keyword
occurring anywhere else in the file (e.g. inside a `MethodChannel` call
name) still fires the rule.

`example/lib/ios/require_ios_deployment_target_consistency_fixture.dart`
previously contained stub `_bad891`/`_good891` functions with no actual
triggering code, so the rule was never exercised by a real fixture. It now
imports `dart:async` and `package:async/async.dart` at file scope (expect no
lint) and includes a `'SharePlay.startSession'` string literal (expect
lint), giving the false-positive class and the true-positive class explicit
coverage.

Verification: the project's standard `dart test` fixture-verification suite
only checks file existence, not rule firing (per prior repo convention), and
the scan CLI's file-list resolver hardcodes an `/example` path exclusion, so
`example/` fixtures cannot be scanned directly. Behavior was instead
confirmed by copying the same import-only and `SharePlay`-literal cases into
a throwaway file outside `example/` and running
`dart run bin/scan.dart <dir> --tier comprehensive --format json` against
it: the import-only file produced zero diagnostics from any rule, and the
`SharePlay` file produced exactly one `require_ios_deployment_target_consistency`
diagnostic (plus one from the unrelated sibling rule
`require_ios_minimum_version_check`, which matches the same string by
design). `dart test test/rules/platforms/ios_rules_test.dart` (179 tests)
passed unchanged.
