# BUG: `require_platform_check` — Fires on `dart:io` API inside the IO branch of a conditional import (`*_io.dart`)

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-19
Rule: `require_platform_check`
File: `lib/src/rules/config/platform_rules.dart` (line ~57, class at line 41)
Severity: False positive — High
Rule version: v2 | Since: v4.1.6 | Updated: v4.13.0

---

## Summary

`require_platform_check` flags `dart:io` class usage (`File`, `Directory`, `HttpServer`, etc.) as "used without a platform guard" inside files that are the IO branch of a Dart conditional import/export (named `*_io.dart` by convention). Those files are only ever loaded on native platforms — the web build resolves to a separate stub via `if (dart.library.io)` — so the `dart:io` code can never execute on web and needs no runtime `kIsWeb` / `Platform` guard. The file split itself is the guard. Expected: no diagnostic in such a file. Actual: the rule fires on every `dart:io` use.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'require_platform_check'" lib/src/rules/
# lib/src/rules/config/platform_rules.dart:57:    'require_platform_check',

# Negative — rule is NOT in the triggering project
grep -rn "require_platform_check" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# 0 matches (the name appears only in that project's analysis_options.yaml)
```

**Emitter registration:** `lib/src/rules/config/platform_rules.dart:57`
**Rule class:** `RequirePlatformCheckRule` (`lib/src/rules/config/platform_rules.dart:41`)
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` (saropa_lints `custom_lint` plugin)

---

## Reproducer

Minimal Dart code that triggers the bug. The public entry selects the implementation at compile time; the IO file is only loaded when `dart:io` exists.

```dart
// drift_debug_server.dart (public entry) — conditional EXPORT picks the impl:
export 'src/drift_debug_server_stub.dart'
    if (dart.library.io) 'src/drift_debug_server_io.dart';

// src/drift_debug_server_io.dart — only loaded when dart.library.io is defined:
import 'dart:io';

Future<void> serve(InternetAddress address, int port, String packageRoot) async {
  final server = await HttpServer.bind(address, port, shared: true); // LINT require_platform_check — but this file NEVER loads on web
  final file = File('$packageRoot/assets/web/style.css');            // LINT — same false positive
  // ... server code that is unreachable on web by construction
}
```

**Frequency:** Always, in conditional-import / conditional-export IO implementation files (the `*_io.dart` branch).

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic. The file is the `if (dart.library.io)` branch of a conditional import/export; the web build uses a separate stub, so `dart:io` here is unreachable on web and needs no `kIsWeb` guard. |
| **Actual** | `[require_platform_check] Platform-specific API from dart:io used without a platform guard.` reported on every `File(...)` / `Directory(...)` / dart:io constructor in the file. |

---

## AST Context

The rule registers on `InstanceCreationExpression` and reports the node directly. There is no parent-chain condition that can recognize the conditional-import branch context — that information lives in *other* files (the entry that exports this one), not in this file's AST.

```
CompilationUnit (src/drift_debug_server_io.dart)
  └─ FunctionDeclaration (serve)
      └─ BlockFunctionBody
          └─ Block
              └─ VariableDeclarationStatement (file)
                  └─ VariableDeclaration (file)
                      └─ InstanceCreationExpression  File('...')  ← reported here (line 92: node.constructorName.type.name.lexeme == 'File')
```

`_hasPlatformGuard` (line 102) only walks ancestor `IfStatement` nodes looking for `Platform.` / `kIsWeb` / `defaultTargetPlatform` in the condition source. A conditional-import branch has no such `if` in its own body, so the walk reaches the root and returns `false`.

---

## Root Cause

The rule has **no awareness of conditional imports, `*_io.dart` naming, or a sibling stub.** Its only suppression is `ProjectContext.hasWebSupport(context.filePath)` (line 90) plus the ancestor-`IfStatement` walk in `_hasPlatformGuard` (lines 102–116). For a `*_io.dart` file in a web-supporting project with no enclosing `if (!kIsWeb)`, both gates pass and the rule fires.

The package already has the exact machinery to suppress this — it is simply not wired into this rule:

### Hypothesis A (confirmed): `RequirePlatformCheckRule` never calls `isNativeOnlyConditionalImportTarget`

`lib/src/conditional_import_utils.dart` defines `isNativeOnlyConditionalImportTarget(filePath)` (line 51). It scans `lib/`, parses each file's import directives, collects the URIs guarded by `dart.library.io` / `dart.library.ffi` (line 36–39), resolves them to absolute paths, and caches per project. Its own dartdoc (lines 5–12) states the purpose precisely: files only loaded when `dart.library.io` is defined "are never loaded on web, so requiring a `kIsWeb` guard inside them is a false positive."

The sibling rule `PreferPlatformIoConditionalRule` calls this guard at `lib/src/rules/config/platform_rules.dart:182`:

```dart
if (isNativeOnlyConditionalImportTarget(context.filePath)) return;
```

`RequirePlatformCheckRule.runWithReporter` (lines 82–100) does **not** make this call. That single missing line is the over-fire: the helper already knows the file is native-only, but the rule never asks.

### Hypothesis B (confirmed gap): the conditional-import scanner only handles `import`, not `export`

Even once `RequirePlatformCheckRule` calls the helper, the reproducer uses a conditional **`export`**, not a conditional `import`. `_collectNativeOnlyTargetsFromFile` iterates `unit.directives` and skips anything that is not an `ImportDirective` (line 116: `if (directive is! ImportDirective) continue;`). A `package:foo/foo.dart` library that does `export '...' if (dart.library.io) '..._io.dart';` would therefore NOT register `..._io.dart` as a native-only target, so the helper returns `false` for it and the suppression still misses.

Net: two defects compound. Wiring the helper into the rule fixes the conditional-`import` form; the conditional-`export` form additionally needs the scanner to handle `ExportDirective`. The `*_io.dart`-with-sibling-stub heuristic (below) is a cheap fallback that covers both without parsing.

---

## Suggested Fix

Three options, in order of preference. Reference line numbers are in `lib/src/rules/config/platform_rules.dart` and `lib/src/conditional_import_utils.dart`.

### (a) Skip files reachable only via a `dart.library.io` conditional-import/export branch — REUSE the existing helper

Add the same early return the sibling rule already uses, inside `RequirePlatformCheckRule.runWithReporter` after the `hasWebSupport` gate at `platform_rules.dart:90`:

```dart
context.addInstanceCreationExpression((InstanceCreationExpression node) {
  if (!ProjectContext.hasWebSupport(context.filePath)) return;
  // File is the io/ffi branch of a conditional import/export — never loaded
  // on web, so the file split IS the platform guard. Same suppression the
  // sibling prefer_platform_io_conditional rule applies at line 182.
  if (isNativeOnlyConditionalImportTarget(context.filePath)) return;
  // ... existing logic
});
```

Requires importing the helper (the file already imports `../../conditional_import_utils.dart` at line 7). This is the root-cause fix for the conditional-`import` form and reuses tested infrastructure.

### (b) Extend the scanner to recognize conditional `export` directives

For the reproducer's `export '...' if (dart.library.io) '..._io.dart';` form, extend `_collectNativeOnlyTargetsFromFile` in `conditional_import_utils.dart` (line 116) to also accept `ExportDirective`. Both `ImportDirective` and `ExportDirective` expose `.configurations`; the condition/URI handling at lines 117–138 is otherwise identical. Generalize the type check so the same loop collects from either directive type. This makes option (a) work for conditional exports as well, not just imports.

### (c) Cheap fallback: skip `*_io.dart` files that have a sibling `*_stub.dart` (or sibling conditional export)

When the full scan is unavailable or the entry uses an unusual form, a no-parse heuristic: if `context.filePath` ends with `_io.dart` and a sibling file ending `_stub.dart` exists in the same directory (e.g. `drift_debug_server_io.dart` + `drift_debug_server_stub.dart`), treat the file as native-only and return early. This mirrors the directory-probe style already used by `RequireDesktopWindowSetupRule._hasDesktopRunnerFiles` (line 423). Use as a fallback only — options (a)+(b) are the accurate path; (c) covers the naming convention without resolving directives.

A related minimal variant: treat an unconditional `import 'dart:io';` at the top of a file that has a conditional-export sibling as itself the guard, since a file that hard-imports `dart:io` cannot compile for web and is necessarily only reached through the native branch.

---

## Fixture Gap

The fixture for this rule should add cases under a conditional-import structure:

1. **`*_io.dart` that is the `if (dart.library.io)` IMPORT branch** — `File('x')` / `HttpServer.bind(...)` with no `kIsWeb` guard — expect NO lint
2. **`*_io.dart` that is the `if (dart.library.io)` EXPORT branch** (entry uses `export '...' if (dart.library.io) '..._io.dart';`) — expect NO lint (covers Hypothesis B)
3. **`*_io.dart` with a sibling `*_stub.dart`** — expect NO lint (covers option (c) heuristic)
4. **Regular `lib/` file with unguarded `File('x')` and web support** — expect LINT (guards against over-suppression)
5. **`*_io.dart` reachable from BOTH a conditional and an unconditional import** — expect LINT (file can load on web via the unconditional path, so the guard is still required)

---

## Changes Made

All three suggested options were implemented; (a)+(b)+(c) together cover the conditional-import form, the conditional-export form, and the naming-convention fallback, plus a new guard against over-suppression (case 5).

- **Option (a) — `lib/src/rules/config/platform_rules.dart`:** `RequirePlatformCheckRule.runWithReporter` now calls `isNativeOnlyConditionalImportTarget(context.filePath)` and returns early, the same suppression the sibling `prefer_platform_io_conditional` rule already applied. The helper was already imported.
- **Option (b) — `lib/src/conditional_import_utils.dart`:** the scanner now iterates `NamespaceDirective` (the common supertype of `ImportDirective` and `ExportDirective`) instead of `ImportDirective` only, so a conditional `export '...' if (dart.library.io) '..._io.dart';` registers its io branch as native-only. (Renamed `_collectNativeOnlyTargetsFromFile` → `_collectTargetsFromFile`.)
- **Option (c) — `lib/src/conditional_import_utils.dart`:** new `_collectSiblingStubTarget` marks any `*_io.dart` that has a sibling `*_stub.dart` in the same directory as native-only, covering the naming convention without resolving a directive.
- **Case 5 over-suppression guard — `lib/src/conditional_import_utils.dart`:** the scanner additionally collects every file reached by an *unconditional* `import`/`export` (the directive's default URI) and subtracts that set from the native-only set, so a file reachable on web via a plain import is still flagged.

---

## Tests Added

- **`test/utils/conditional_import_utils_test.dart`** — four new cases against isolated temp packages: conditional `export` io branch → native-only (Hypothesis B); `*_io.dart` with sibling `*_stub.dart` → native-only (option c); `*_io.dart` with no sibling → not native-only; target reached by both a conditional io branch and an unconditional import → not native-only (case 5). All 11 tests in the file pass.
- **`example/lib/platform/conditional_io/`** — documentation fixtures for cases 1–3 and 5 (conditional import branch, conditional export branch, sibling-stub pair, and the dual conditional+unconditional case that must still lint).

Note: the `dart run saropa_lints scan` CLI does not surface `require_platform_check` for the example project (the rule fires zero times even on the pre-existing known-bad fixture under that engine), so verification is via the unit test that exercises the scanner logic directly.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: 14.0.3
- Dart SDK version: 3.12.1
- custom_lint version: via CLI
- Triggering project/file: `saropa_drift_advisor` — `lib/src/.../drift_debug_server_io.dart` (the `if (dart.library.io)` branch of a conditional export)

---

## Finish Report (2026-06-19)

### Defect

`require_platform_check` reported `dart:io` constructor usage (`File`, `Directory`, etc.) as unguarded inside files that are the native (`if (dart.library.io)`) branch of a Dart conditional import or export. Those files never load on web — the web build resolves to a separate stub — so the file split itself is the platform guard and no `kIsWeb` check is required. The rule had no conditional-import awareness; its only suppressions were the `hasWebSupport` gate and an ancestor-`IfStatement` walk, neither of which can recognize a branch whose selecting directive lives in another file.

### Resolution

The package already contained `isNativeOnlyConditionalImportTarget` (`lib/src/conditional_import_utils.dart`), used by the sibling `prefer_platform_io_conditional` rule but never called by `require_platform_check`. Four coordinated changes close the gap:

1. `RequirePlatformCheckRule.runWithReporter` now calls `isNativeOnlyConditionalImportTarget(context.filePath)` and returns early, mirroring the sibling rule — the root-cause fix for the conditional-`import` form.
2. The conditional-import scanner now walks `NamespaceDirective` (supertype of both `ImportDirective` and `ExportDirective`) rather than `ImportDirective` only, so a conditional `export '...' if (dart.library.io) '..._io.dart';` registers its io branch as native-only. This covers the actual trigger, which used a conditional export.
3. A naming-convention fallback (`_collectSiblingStubTarget`) marks any `*_io.dart` with a sibling `*_stub.dart` as native-only without resolving a directive.
4. To prevent over-suppression, the scanner now also collects every file reached by an unconditional `import`/`export` (the directive's default URI) and subtracts that set from the native-only set. A file reachable on web through a plain import is therefore still flagged even if some other directive references it conditionally.

### Verification

`test/utils/conditional_import_utils_test.dart` gained four cases (conditional export, sibling-stub present, sibling-stub absent, dual conditional+unconditional) — 11/11 pass. `dart analyze` is clean on the changed sources and test. Documentation fixtures were added under `example/lib/platform/conditional_io/`.

A limitation surfaced during verification: the `dart run saropa_lints scan` CLI fires `require_platform_check` zero times — even on the pre-existing known-bad fixture — because scan mode parses with an unresolved AST in which implicit (no-`new`) constructor calls are `MethodInvocation` nodes, never `InstanceCreationExpression`. The rule's behavior was therefore verified through the unit test that drives the scanner logic directly. That scan-engine limitation is tracked separately in `bugs/infra_scan_cli_misses_instance_creation_rules_unresolved_ast.md`.
