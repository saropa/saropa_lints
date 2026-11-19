# BUG: `avoid_memory_intensive_operations` - `line += stringBuffer.toString()` flush inside a nested loop (per-iteration local declared in the outer loop)

**Status: Fixed** (isStringBufferDrain suppression in performance_rules.dart; resolved scan confirms no lint at 60 or 77)

Supersedes: /Users/craighathaway/src/saropa_lints/plans/history/2026.10/2026.10.29/avoid_memory_intensive_operations_false_positive_single_append_after_stringbuffer_collect.md; finding still fires on 17.0.1-beta.4 in the reporter's project (location 60:13 is also reported by the beta.4 source; location 77:31 is NOT reported by the beta.4 source and the export for it predates the beta.4 install, see Version Caveat).

Created: 2026-10-29
Rule: `avoid_memory_intensive_operations`
File: `lib/src/rules/core/performance_rules.dart` (class 3014, code 3031, visitor 3085)
Severity: False positive (line 60), stale export (line 77)
Rule version: v2

---

## Summary

`VCardImportLineParser.unfold` (the method that unfolds vCard lines) builds each logical line in `String line` and collects fold pieces in a `StringBuffer pending`. Two `line += pending.toString()` statements flush the buffer: one at 60:13 inside the inner `while`, one at 77:31 directly in the outer `while` body. The export contains both.

- 77:31: `line` is declared inside the outer loop body (line 48) and the statement is in the outer loop, so the per-iteration-local exemption (`isDeclaredInsideNearestLoop`, present in beta.3/beta.4) suppresses it. Not reported by beta.4 source.
- 60:13: the nearest enclosing loop of the statement is the INNER `while` (line 56) but `line` is declared in the OUTER `while` (line 48), outside the inner loop's range. `isDeclaredInsideNearestLoop` returns false and the rule reports. **Reported by beta.4 source.** It is the same node that `avoid_string_concatenation_loop` reports (see the companion report).

---

## Version Caveat (read first)

The reporter states these diagnostics still fire on saropa_lints 17.0.1-beta.4. The files on disk show the diagnostics were exported BEFORE the project resolved to beta.4:

| Evidence | Value |
|---|---|
| `bugs/issues.json` (the diagnostics export) modified | Oct 29 2026 19:53:44 |
| `pubspec.yaml` modified (dependency changed to `saropa_lints: ^17.0.1-beta.4`) | Oct 29 2026 19:56:29 |
| `pubspec.lock` and `.dart_tool/package_config.json` modified (first resolve to beta.4) | Oct 29 2026 19:57:50 |
| `pubspec.lock` at git HEAD (0a20d04ed2) | saropa_lints `17.0.0`, analyzer `14.6.0` |
| `pubspec.lock` in working tree | saropa_lints `17.0.1-beta.4`, analyzer `14.7.0` |
| `.dart_tool/package_config.json` | `saropa_lints` rootUri `file:///Users/craighathaway/.pub-cache/hosted/pub.dev/saropa_lints-17.0.1-beta.4` |
| `analysis_options.yaml` lines 1170-1173 | plugin block is commented out under "saropa_lints integration turned OFF by the VS Code extension", its commented `version:` is `"17.0.0"` |
| `owner` of every diagnostic | `saropaLintsLsp` (the VS Code extension `saropa.saropa-lints-17.0.13` language server, `dist/extension.js` contains the string) |

Consequence: the engine that produced `issues.json` is not proven to be beta.4. The exemption code for each rule below was checked per release tag with `git show <tag>:<file> | grep -c <marker>`:

| Rule fix marker | beta.2 | beta.3 | beta.4 |
|---|---|---|---|
| `NeverType` in `code_quality_avoid_rules.dart` (avoid_ignoring_return_values) | 0 | 1 | 1 |
| `_isAccumulatorTypeName` in `code_quality_variables_rules.dart` (avoid_parameter_mutation) | 0 | 2 | 2 |
| `isDeclaredInsideNearestLoop` in `performance_rules.dart` (string concat rules) | 0 | 3 | 3 |
| `_isGuardedByShortCircuit` in `collection_rules.dart` (avoid_unsafe_collection_methods) | 0 | 2 | 2 |

The pub-cache copy `~/.pub-cache/hosted/pub.dev/saropa_lints-17.0.1-beta.4/lib` is identical to `/Users/craighathaway/src/saropa_lints/lib` (`diff -rq` lists only three extra untracked paths in the repo: `lib/src/cli/project_health/reports`, `lib/src/reports`, `lib/src/rules/visitor_import_patch.txt`).

**What was NOT verified:** which rule engine and version produced the export. No scan, analyze or test was run for this report (the reporter's machine is memory-limited and the owner forbade it). The "Root Cause" section below states, per location, whether the beta.4 SOURCE would report it.

---

## Attribution Evidence

```bash
grep -rn "'avoid_memory_intensive_operations'" lib/src/rules/
# lib/src/rules/core/performance_rules.dart:3031:    'avoid_memory_intensive_operations',
```

**Emitter registration:** `lib/src/rules/core/performance_rules.dart:3031`
**Rule class:** `AvoidMemoryIntensiveOperationsRule` - registered in `lib/saropa_lints.dart:1289`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints` / `saropaLintsLsp`
Negative grep not needed: the code name occurs only in this repository's `lib/src/rules/`.

---

## Diagnostics From The Reporter's Project (exact JSON from `bugs/issues.json`)

2 entries, all in `lib/database/file_backup/import/vcard_import_line_parser.dart`:

- `lib/database/file_backup/import/vcard_import_line_parser.dart` 60:13 to 60:39

```json
{
  "resource": "/Users/craighathaway/Documents/src/contacts/lib/database/file_backup/import/vcard_import_line_parser.dart",
  "owner": "saropaLintsLsp",
  "code": "avoid_memory_intensive_operations",
  "severity": 4,
  "message": "[avoid_memory_intensive_operations] String concatenation using += inside a loop creates a new String object on every iteration, resulting in O(n squared) memory allocations. Each iteration copies the entire accumulated string, causing excessive garbage collection pressure, UI thread pauses, and visible jank in animations or scrolling. {v2}",
  "source": "saropa_lints",
  "startLineNumber": 60,
  "startColumn": 13,
  "endLineNumber": 60,
  "endColumn": 39,
  "origin": "extHost1"
}
```

- `lib/database/file_backup/import/vcard_import_line_parser.dart` 77:31 to 77:57

```json
{
  "resource": "/Users/craighathaway/Documents/src/contacts/lib/database/file_backup/import/vcard_import_line_parser.dart",
  "owner": "saropaLintsLsp",
  "code": "avoid_memory_intensive_operations",
  "severity": 4,
  "message": "[avoid_memory_intensive_operations] String concatenation using += inside a loop creates a new String object on every iteration, resulting in O(n squared) memory allocations. Each iteration copies the entire accumulated string, causing excessive garbage collection pressure, UI thread pauses, and visible jank in animations or scrolling. {v2}",
  "source": "saropa_lints",
  "startLineNumber": 77,
  "startColumn": 31,
  "endLineNumber": 77,
  "endColumn": 57,
  "origin": "extHost1"
}
```

---

## Real Code At HEAD (`git show HEAD:lib/database/file_backup/import/vcard_import_line_parser.dart`, file unmodified in the working tree)

### Import list (verbatim)

```dart
  1  import 'dart:convert';
  3  import 'package:saropa/utils/_dev/debug.dart';
  4  import 'package:saropa/utils/contact/vcard_text_codec.dart';
```

### Enclosing method (verbatim, real line numbers) - `VCardImportLineParser.unfold`, lines 38-81

```dart
38    static String unfold(String content) {
39      final List<String> physical = content.split(RegExp(r'\r\n|\n'));
40      final List<String> logical = <String>[];
41  
42      // One pass over the raw physical lines. A QP soft break (`=` at the
43      // end of a QP property line) is checked BEFORE the space/tab fold, so
44      // a continuation that starts with whitespace keeps that whitespace as
45      // data instead of losing it to the fold.
46      int i = 0;
47      while (i < physical.length) {
48        String line = physical[i];
49        i++;
50        // Fold pieces not yet appended to `line`. Appending each piece to
51        // the String copies the whole line every time, which is quadratic
52        // on a large folded base64 photo (thousands of 75-char lines).
53        final StringBuffer pending = StringBuffer();
54        // Tracks the last character of `line` + `pending` without building it.
55        bool endsWithEquals = line.endsWith('=');
56        while (i < physical.length) {
57          final String next = physical[i];
58          if (endsWithEquals) {
59            if (pending.isNotEmpty) {
60              line += pending.toString();
61              pending.clear();
62            }
63            if (isQuotedPrintableLine(line)) {
64              line = line.substring(0, line.length - 1) + next;
65              endsWithEquals = line.endsWith('=');
66              i++;
67              continue;
68            }
69          }
70          if (!next.startsWith(' ') && !next.startsWith('\t')) break;
71          // Standard fold: exactly one leading whitespace character goes.
72          final String piece = next.substring(1);
73          pending.write(piece);
74          if (piece.isNotEmpty) endsWithEquals = piece.endsWith('=');
75          i++;
76        }
77        if (pending.isNotEmpty) line += pending.toString();
78        logical.add(line);
79      }
80      return logical.join('\n');
81    }
```

### Declarations of every non-SDK symbol involved

| Symbol | Declared in | Signature |
|---|---|---|
| `VCardImportLineParser` | same file line 7 | `abstract final class VCardImportLineParser` |
| `VCardImportLineParser.isQuotedPrintableLine` | same file line 85 | `static bool isQuotedPrintableLine(String line)` |
| `StringBuffer` (`write`, `isNotEmpty`, `clear`, `toString`) | SDK `dart:core` | `pending.toString()` returns `String` |
| `String.split`, `substring`, `endsWith`, `startsWith`, `List.join` | SDK `dart:core` | - |
| `debugException`, `VCardTextCodec` | imported at lines 3-4 but not used in `unfold` | - |

No extension method and no project helper is called inside `unfold`.

---

## Resolved Static Types

- `line` (declared line 48, `String line = physical[i];`): `String`, non-nullable, a local variable (`LocalVariableElement`), declared inside the OUTER `while (i < physical.length)` (starts line 47) and OUTSIDE the inner `while (i < physical.length)` (starts line 56).
- `node.readType` of `line += pending.toString()` (lines 60 and 77): `String`.
- `pending.toString()`: `String`. `pending`: `StringBuffer`, declared line 53 inside the outer `while`, outside the inner `while`.
- `node.writeElement` for both compound assignments: the local `line` (offset of its name = line 48, column 12).

---

## Project Settings That Affect The Rule

Reporter project: `/Users/craighathaway/Documents/src/contacts` (git HEAD `0a20d04ed2`; the flagged files are unmodified in the working tree, so line numbers equal `git show HEAD:<path>`).

- `pubspec.yaml` (working tree) `environment`: `sdk: ">=3.13.0 <4.0.0"` (line 31), `flutter: ">=3.47.7"` (line 32). Installed Dart: `3.13.7 (stable) macos_arm64`.
- `pubspec.yaml` line 732 (working tree): `saropa_lints: ^17.0.1-beta.4` in `dev_dependencies`. At HEAD line 733: `saropa_lints: ^17.0.0`.
- `custom_lint`: not a dependency (only commented text at `pubspec.yaml` lines 713-714). `analyzer`: not declared directly, comment at lines 722-724; resolved transitively. `docs/guides/tooling/TOOLING.md` line 13: "saropa_lints is a native `analysis_server_plugin`, not custom_lint."
- `pubspec.lock` (working tree): `saropa_lints 17.0.1-beta.4` (sha256 `a59924e4e1c2d0102618a43057e3b153933c848954acb0416cc4a056003330a7`), `analyzer 14.7.0`, `_fe_analyzer_shared 111.0.0`, `analysis_server_plugin 0.3.26`.
- `saropa_lints` own constraint: `analyzer: ">=13.0.0 <15.0.0"` (`/Users/craighathaway/src/saropa_lints/pubspec.yaml` line 99), sdk `>=3.11.0 <4.0.0`.
- `analysis_options_custom.yaml` lines 131 and 133: `saropa_tier: recommended`, `runtime_tier: recommended`. `lint_baseline.yaml` lists `// ignore:` directives only (header lines 1-8); it has no entry for any file named in this report. No `// ignore` is used or proposed.
- `analysis_options.yaml`: the `plugins: saropa_lints:` block is commented out (lines 1170-1173 and following); the per-rule lines below are inside that commented block, so they are the generated defaults, not live config.
- `avoid_memory_intensive_operations`: `analysis_options.yaml` line 921 (`avoid_memory_intensive_operations: true  # [WARNING] ... {v2}`, commented block) and line 1599; `analysis_options_custom.yaml` has no override line (tier default applies)
- No `lint_baseline.yaml` entry for this file.

---

## Reproducer

This is the real method `unfold` copied verbatim (lines 38-81) into a class of the same name, with the real helper `isQuotedPrintableLine` (lines 85-89). Nothing was removed: the nesting (outer `while` > `String line` > `StringBuffer pending` > inner `while` > two `+=` flushes), the `endsWithEquals` variable and the other assignments (`line = line.substring(...) + next` at line 64, which the binary-expression handler must not report) are all kept. Not compiled or run by me (no analyze allowed).

```dart
abstract final class VCardImportLineParser {
  static String unfold(String content) {
    final List<String> physical = content.split(RegExp(r'\r\n|\n'));
    final List<String> logical = <String>[];

    // One pass over the raw physical lines. A QP soft break (`=` at the
    // end of a QP property line) is checked BEFORE the space/tab fold, so
    // a continuation that starts with whitespace keeps that whitespace as
    // data instead of losing it to the fold.
    int i = 0;
    while (i < physical.length) {
      String line = physical[i];
      i++;
      // Fold pieces not yet appended to `line`. Appending each piece to
      // the String copies the whole line every time, which is quadratic
      // on a large folded base64 photo (thousands of 75-char lines).
      final StringBuffer pending = StringBuffer();
      // Tracks the last character of `line` + `pending` without building it.
      bool endsWithEquals = line.endsWith('=');
      while (i < physical.length) {
        final String next = physical[i];
        if (endsWithEquals) {
          if (pending.isNotEmpty) {
            line += pending.toString();
            pending.clear();
          }
          if (isQuotedPrintableLine(line)) {
            line = line.substring(0, line.length - 1) + next;
            endsWithEquals = line.endsWith('=');
            i++;
            continue;
          }
        }
        if (!next.startsWith(' ') && !next.startsWith('\t')) break;
        // Standard fold: exactly one leading whitespace character goes.
        final String piece = next.substring(1);
        pending.write(piece);
        if (piece.isNotEmpty) endsWithEquals = piece.endsWith('=');
        i++;
      }
      if (pending.isNotEmpty) line += pending.toString();
      logical.add(line);
    }
    return logical.join('\n');
  }

  /// True when the text before the first `:` of [line] declares
  /// QUOTED-PRINTABLE (case-insensitive, `ENCODING=` or bare form).
  static bool isQuotedPrintableLine(String line) {
    final int colonIndex = line.indexOf(':');
    if (colonIndex <= 0) return false;
    return line.substring(0, colonIndex).toUpperCase().contains('QUOTED-PRINTABLE');
  }
}

void main() {
  print(VCardImportLineParser.unfold('A:1\r\n  b\r\nB;ENCODING=QUOTED-PRINTABLE:x=\r\ny'));
}
```

Locations in this copy: the `+=` inside the inner `while` is the `avoid_memory_intensive_operations` finding at (real file) 60:13; the `+=` after the inner `while` is the finding at 77:31.

---

## AST Context

```
MethodDeclaration (unfold)  static String
  BlockFunctionBody > Block
    WhileStatement (outer, line 47: i < physical.length)          <- nearest loop for the statement at 77
      Block
        VariableDeclarationStatement  String line = physical[i];     (line 48; declaration offset inside outer loop, OUTSIDE inner loop)
        VariableDeclarationStatement  final StringBuffer pending
        WhileStatement (inner, line 56)                              <- nearest loop for the statement at 60
          Block
            IfStatement (endsWithEquals)
              Block
                IfStatement (pending.isNotEmpty)
                  Block
                    ExpressionStatement
                      AssignmentExpression  line += pending.toString()   <- 60:13-60:39 reported
        IfStatement (pending.isNotEmpty)
          ExpressionStatement
            AssignmentExpression  line += pending.toString()           <- 77:31-77:57, not reported by beta.4 source
```

---

## Root Cause (traced in `lib/src/rules/core/performance_rules.dart`)

Class `AvoidMemoryIntensiveOperationsRule` (line 3014; code at line 3031, registered `lib/saropa_lints.dart:1289`).

1. `runWithReporter` (line ~3047) registers `context.addForStatement`, `addForElement` and `addWhileStatement`; each runs `node.body.visitChildren(_StringConcatVisitor(reporter, code))`. For the nested loops in `unfold` the inner `while` body is visited twice (once through the outer `while`'s `visitChildren`, once through its own handler); both visits reach the same `AssignmentExpression` node.
2. `_StringConcatVisitor.visitAssignmentExpression` (line ~3085) reports when ALL hold: `operator.type == TokenType.PLUS_EQ`; `_isStringLikeExpression(leftHandSide, fallback: true)` (true: static type `String`, and `fallback: true` even if the type were unknown); `_isStringLikeExpression(rightHandSide)` (true: `pending.toString()` is `String`); `!isDeclaredInsideNearestLoop(node)`.
3. `isDeclaredInsideNearestLoop` (top-level function, line ~3057): walks `node.parent` up to the nearest `ForStatement`/`ForElement`/`WhileStatement`/`DoStatement`; `node.writeElement` must be a `LocalVariableElement`; returns `declOffset > loop.offset && declOffset < loop.end`.
   - Statement at 77: nearest loop = outer `while` (line 47). `line` is declared at line 48, inside it. Returns true -> not reported.
   - Statement at 60: nearest loop = inner `while` (line 56). `line` is declared at line 48 = before `loop.offset` of the inner loop. Returns false -> **reported**. This is the exact condition that fires: the variable is declared in a loop enclosing the nearest loop but not in the nearest loop itself, i.e. it IS carried across inner iterations.
4. Whether 60 is a genuine accumulation: `line` IS read and rewritten across inner-loop iterations (line 64 `line = line.substring(0, line.length - 1) + next;` and line 60 both copy the whole string per iteration of the QP soft-break branch), so a strict reading says the rule is right. What makes it a false positive for this code is that the code already applies the rule's own recommendation: fold pieces go into `StringBuffer pending` (line 53) and the `+=` at 60 only flushes that buffer once per QP soft break (guarded by `pending.isNotEmpty`, followed by `pending.clear()`), so the `+=` is `String += <StringBuffer>.toString()`, not a per-element append.

Hypotheses:
- Hypothesis A (location 77, supported by timestamps): export from an older engine (marker `isDeclaredInsideNearestLoop` absent in beta.2).
- Hypothesis B (location 60): real behavior of beta.3/beta.4; the report stands for this location.
- Not verified: the rule's behavior when `node.writeElement` is not a `LocalVariableElement` for a compound assignment on a local (analyzer 14.7.0 should return the local); if it returned null the exemption would also skip 77 and the export entry for 77 would be explained by beta.4 as well. The `--resolve` scan output settles this.

---

## How To Reproduce In The Reporter's Project

1. `cd /Users/craighathaway/Documents/src/contacts`. The saropa_lints dependency is live in the working tree (`pubspec.yaml` line 732) but the `plugins:` block in `analysis_options.yaml` is commented out (lines 1170+), so the IDE shows nothing until the VS Code "Lint integration" toggle is turned On (`docs/guides/tooling/TOOLING.md` lines 13-15). Run `flutter pub get` (lock must show `saropa_lints 17.0.1-beta.4`), then restart the Dart analysis server so no 17.0.0 process is left running.
2. Open the file at lines 60 and 77 and read the Problems panel. Expected text: `[avoid_memory_intensive_operations] String concatenation using += inside a loop creates a new String object on every iteration ...`.
3. Headless scan, scoped to the file(s) (command form from `docs/guides/tooling/TOOLING.md` line 209 and `bin/scan.dart` help lines 748-973; the default scan is a SYNTACTIC parse where `staticType` is null, so type-based rules need `--resolve`; `--tier` overrides the commented-out config):

```bash
dart run saropa_lints scan . --tier recommended --resolve --format json --files lib/database/file_backup/import/vcard_import_line_parser.dart
```

   Expected from beta.4 source: ONE diagnostic for this rule (60:13-60:39); none at 77. Any entry at 77:31 means the engine does not contain the `isDeclaredInsideNearestLoop` exemption.
4. Compare with the diagnostics listed in "Diagnostics From The Reporter's Project". If the scan reports none of the locations marked "not reported by beta.4 source" below, the export was produced by an older engine (see Version Caveat) and the exemption in the rule works; only the locations marked "reported by beta.4 source" are open bugs.

---

## Suggested Fix

Add one more suppression in `_StringConcatVisitor.visitAssignmentExpression` (and the same line of logic in `AvoidStringConcatenationLoopRule`): skip a `+=` whose right-hand side is `<expr>.toString()` where `<expr>.staticType` is `StringBuffer` (the buffer-drain pattern the rule's own correction message recommends). Optional narrower variant: only when the same block also calls `<expr>.clear()` after the append. Do not change `isDeclaredInsideNearestLoop`; its inner-loop semantics are correct for real accumulators (for example `for (...) { for (...) { out += x; } }` with `out` declared before both loops must still lint).

## Fixture Gap

The fixture `example/lib/core/avoid_memory_intensive_operations_fixture.dart` (or equivalent) should include:

1. Nested `while` loops, `String line` declared in the outer body, `line += buffer.toString();` in the outer body after the inner loop - expect NO lint (per-iteration local; location 77).
2. Same, but the `+=` inside the inner `while` guarded by `if (buffer.isNotEmpty)` and followed by `buffer.clear()` - expect NO lint (buffer drain; location 60) once the fix lands.
3. `String out = ''; for (final s in items) { out += s; }` - expect LINT.
4. `String out = ''; for (...) { for (...) { out += s; } }` with `out` declared before both loops and a plain `String` RHS - expect LINT.
5. `var total = 0; while (...) { total += 1; }` - expect NO lint (not a String).

---

## Environment

- saropa_lints (rule source examined): 17.0.1-beta.4 at `/Users/craighathaway/src/saropa_lints` commit `72e3cdd5` ("Release v17.0.1-beta.4"); identical `lib/` in `~/.pub-cache/hosted/pub.dev/saropa_lints-17.0.1-beta.4`.
- saropa_lints in the reporter's `pubspec.lock`: 17.0.1-beta.4 (resolved 19:57:50, after the diagnostics export at 19:53:44).
- Dart SDK: 3.13.7 (stable) macos_arm64; analyzer 14.7.0; custom_lint: not used.
- Triggering project: `/Users/craighathaway/Documents/src/contacts`, VS Code extension `saropa.saropa-lints-17.0.13`.
