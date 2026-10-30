# BUG: `require_file_close_in_finally` — `File.openRead()` consumed by `await for` is treated as an unclosed handle

**Status: Fixed**

Created: 2026-10-29
Rule: `require_file_close_in_finally`
File: `lib/src/rules/resources/resource_management_rules.dart` (line ~65)
Severity: False positive
Rule version: v4 | Since: unknown | Updated: 17.0.1-beta.2

---

## Summary

`File.openRead()` returns a `Stream<List<int>>` that closes its file descriptor when the stream completes, errors or is canceled (including by `break`/`return` out of an `await for`). There is no handle and no `close()` to call. The rule matches `.openRead(` by regex and reports the method.

---

## Attribution Evidence

```bash
grep -rn "'require_file_close_in_finally'" lib/src/rules/
lib/src/rules/resources/resource_management_rules.dart:65:    'require_file_close_in_finally',
```

Negative grep not applicable: no sibling analyzer repo is checked out beside this one that defines this code; the rule is only defined here.

**Emitter registration:** `lib/src/rules/resources/resource_management_rules.dart:65`
**Rule class:** `RequireFileCloseInFinallyRule` — registered in `923:  RequireFileCloseInFinallyRule.new,`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints` / `saropaLintsLsp`

---

## Reproducer

Standalone. Copied from the real project source (path and lines below) with project-specific types replaced by the real package types where one exists.

Project source: `lib/database/file_backup/file_backup_utils.dart` lines 221-255 (`getVCardContactCount`), flagged at the method name (221:3-221:4).

```dart
import 'dart:convert';
import 'dart:io';

class VCardCounter {
  static Future<int> count(String filePath) async {
    final File file = File(filePath);
    int count = 0;
    // Stream closes the descriptor itself on completion, error or cancel.
    await for (final String line
        in file.openRead().transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.toUpperCase().contains('BEGIN:VCARD')) count++;
    }
    return count;
  }
}  // LINT on `count` -- but should NOT lint
```

**Frequency:** Always for this pattern.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic (code is correct) |
| **Actual** | `[require_file_close_in_finally] Unclosed file handle on exception leaks file descriptor, exhausting system limits. {v4}` reported at 221:3-221:4 of file_backup_utils.dart (method declaration) |

---

## AST Context

```
ClassDeclaration (DBFileBackupUtils)
  └─ MethodDeclaration (getVCardContactCount)  <- reporter.atNode(node)
      └─ BlockFunctionBody > Block
          └─ TryStatement > Block
              └─ ForStatement (await for)
                  └─ MethodInvocation (file.openRead)  <- matched by regex on body source
```

---

## Root Cause

`resource_management_rules.dart:77-79` `_fileOpenMethodPattern = RegExp(r'\.(?:openRead|openWrite|openSync)\s*\(')` puts `openRead` in the same class as `openWrite` (an `IOSink`) and `openSync` (a `RandomAccessFile`). `runWithReporter` (line 118+) sets `hasFileOpen` from that regex on `body.toSource()` (line 123), skips only field-assigned opens (`_fieldAssignedOpenPattern`), and reports at line 147 (`if (!closed)`) when the body has no `.close(` and no `readAsString/readAsBytes/writeAsString/writeAsBytes` (`_closesFile`). `openRead` neither needs nor offers a close.

### Why the code is correct

`File.openRead()` is a stream; the VM closes the underlying descriptor when the stream is done or its subscription is canceled. The method streams on purpose so that a large photo-bearing vCard export is never held in memory as one string, so the convenience readers (`readAsString`) are not an alternative.

---

## Affected project locations (project: contacts, line numbers before the session's other edits)

- `lib/database/file_backup/file_backup_utils.dart:221`
- `lib/database/file_backup/backup_vcard_marker.dart:51:3` (method `fileHasMarker`, range 51:3-66:4; `await for` over `file.openRead(0, headBytes)`)

---

## Suggested Fix

Remove `openRead` from `_fileOpenMethodPattern`, or only count it when its result is assigned to a variable that is then used with `.listen`/`.pipe` without a paired cancel. Keep `openWrite` (IOSink) and `openSync`/`open` (RandomAccessFile).

---

## Fixture Gap

The fixture for `require_file_close_in_finally` should include:

1. `await for (final c in file.openRead()) {}` -- expect NO lint
2. `final sink = file.openWrite(); sink.write(x);` with no close -- expect LINT
3. `final raf = file.openSync(); raf.readSync(1);` with no close -- expect LINT

---

## Changes Made

None yet.

---

## Tests Added

None yet.

---

## Commits

None yet.

---

## Environment

- saropa_lints version: 17.0.1-beta.2
- Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- custom_lint version: not used (analyzer plugin via saropaLintsLsp)
- Triggering project/file: /Users/craighathaway/Documents/src/contacts — lib/database/file_backup/file_backup_utils.dart:221
