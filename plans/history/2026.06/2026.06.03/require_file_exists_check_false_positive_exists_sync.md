# require_file_exists_check — False Positive when guarded by `existsSync()` (only `.exists()` recognized)

- **Status:** Fixed
- **Created:** 2026-06-03
- **Fixed:** 2026-06-03
- **Rule:** `require_file_exists_check`
- **Rule class:** `RequireFileExistsCheckRule` (`lib/src/rules/resources/file_handling_rules.dart:31`)
- **Registration:** `lib/saropa_lints.dart:1554` (`RequireFileExistsCheckRule.new`)
- **Severity:** INFO
- **Rule version:** v2
- **Reported from:** `D:\src\contacts\lib\service\static_data\remote_static_content_service.dart` (lines 102, 109, 124)

## Summary

The rule flags `file.readAsBytes()` even when it is guarded by `file.existsSync()` in the same expression/block. The guard-detection logic searches the enclosing block source for the literal substring `.exists()` and never matches the synchronous form `.existsSync()`. So code that correctly checks existence with `existsSync()` before reading is wrongly reported.

What should happen: a read guarded by either `exists()` (async) or `existsSync()` (sync) must NOT fire.

## Attribution Evidence

```
$ grep -rn "'require_file_exists_check'" D:/src/saropa_lints/lib/src/rules/
lib/src/rules/resources/file_handling_rules.dart:48:    'require_file_exists_check',
```

Not present as a rule definition in saropa_drift_advisor (only referenced in its `analysis_options.yaml`).

## Reproducer

```dart
import 'dart:io';

// OK — guarded by synchronous existence check.
// Currently FIRES (false positive).
Future<List<int>?> readSync(File f) async {
  return f.existsSync() ? await f.readAsBytes() : null; // LINT (should be OK)
}

// OK — guarded by async existence check. Correctly NOT flagged today.
Future<List<int>?> readAsync(File f) async {
  if (await f.exists()) {
    return await f.readAsBytes(); // OK
  }
  return null;
}

// BAD — unguarded read. Should fire (and does).
Future<List<int>> readUnguarded(File f) async {
  return await f.readAsBytes(); // LINT (correct)
}
```

## Expected vs Actual

| Read guard | Expected | Actual |
|---|---|---|
| `f.existsSync() ? f.readAsBytes() : null` | OK | **LINT (FP)** |
| `if (await f.exists()) f.readAsBytes()` | OK | OK |
| unguarded `f.readAsBytes()` | LINT | LINT |

## AST / source-search context

Real contacts site (`remote_static_content_service.dart:102`):

```dart
if (response.statusCode == 304) {
  await RemoteStaticContentCacheMeta.setSha256(relPath, entry.sha256);
  return cacheFile.existsSync() ? await cacheFile.readAsBytes() : null; // flagged
}
```

`cacheFile` resolves to `dart:io File`, so the type gate at lines 78–79 passes. The read is not inside a `try` (try-catch gate at 82–93 does not apply).

## Root Cause

The exists-guard check (lines 107–116) does:

```dart
final String bodySource = enclosingBody.toSource();
final int readPos = bodySource.indexOf(methodName);
final int existsPos = bodySource.indexOf('.exists()');   // <-- only the async form
if (existsPos >= 0 && existsPos < readPos) return;
```

`'.exists()'` is a literal substring; `'.existsSync()'` does not contain it (the `(` does not follow `exists` directly). So a valid `existsSync()` guard yields `existsPos == -1` and the read is reported.

Secondary weakness: substring matching is brittle (matches `.exists()` in comments/strings, mis-orders when `methodName` text appears earlier than the actual call). But the immediate FP is the missing `existsSync` form.

## Suggested Fix

Recognize the synchronous guard. Minimal change:

```dart
final bool hasGuard =
    bodySource.contains('.exists()') || bodySource.contains('.existsSync()');
final int existsPos = bodySource.indexOf('.exists');   // matches both forms
if (hasGuard && existsPos >= 0 && existsPos < readPos) return;
```

Better: walk the AST for a `MethodInvocation` named `exists` or `existsSync` on the same `File` target dominating the read (handles the ternary-condition case precisely, where the guard and read share one expression and source ordering still holds).

## Fixture Gap

`example/lib/file_handling/require_file_exists_check_fixture.dart` has a GOOD case using `await file.exists()` and a try-catch, but **no** `existsSync()` case. Add:

```dart
// GOOD: synchronous guard
Future<List<int>?> _goodSync(File f) async {
  return f.existsSync() ? await f.readAsBytes() : null; // No lint
}
```

## Environment

- saropa_lints: 13.11.9 (consumed in contacts as `^13.11.9`)
- Dart SDK: `>=3.10.7 <4.0.0`; Flutter `>=3.44.0`
- Plugin mode: native `analysis_server_plugin` (IDE analysis server only)
- Triggering file: `D:\src\contacts\lib\service\static_data\remote_static_content_service.dart`

## Finish Report (2026-06-03)

Replaced the brittle substring guard-detection with an AST walk. The old code
substring-searched the enclosing `BlockFunctionBody` for the literal `.exists()`,
which never matched `.existsSync()` (no `(` directly after `exists`), and could be
fooled by matches in comments/strings or by out-of-order method-name text.

**Change** — `lib/src/rules/resources/file_handling_rules.dart`:
- New `_isGuardedByExistsCheck(MethodInvocation)`: walks ancestors of the read and
  returns true when an `exists`/`existsSync` invocation dominates it via (a) an
  enclosing `if` condition, (b) an enclosing ternary condition, or (c) a statement
  preceding the read in the same block. This is strictly tighter than the old
  whole-body substring scan, so it does not widen false negatives.
- New `_ExistsInvocationFinder` (`RecursiveAstVisitor`) detects `exists`/`existsSync`
  calls in a subtree; added `import 'package:analyzer/dart/ast/visitor.dart'`.
- Bumped rule version `v2` → `v3` (doc header and message `{v3}`).

**Fixture** — added a synchronous-guard GOOD case to
`example/lib/file_handling/require_file_exists_check_fixture.dart`.

**Verification** — `dart analyze --fatal-infos` clean on the rule file. The scan CLI
(`dart run saropa_lints scan`) parses with `parseString` (unresolved AST), so this
rule's `staticType` `File` gate never passes there and it cannot be exercised via
the CLI; it runs only in the analysis-server plugin. Correctness was confirmed by
tracing the AST logic against all four cases (ternary guard, `if` guard, preceding
statement guard, unguarded → still fires).

**Note on target matching** — the guard check does not verify the `exists` call is
on the same `File` as the read. This is intentionally conservative (favors fewer
false positives); the report's "Better" same-target suggestion was not required to
close the reported FP.
