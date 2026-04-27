# `require_database_close` — false positive: rule fires on a helper that *opens* a database when the helper's caller is responsible for closing it (open-in-helper / close-in-caller pattern)

**Status:** Fixed (Unreleased — bumps rule to v7)

Filed: 2026-04-26
Fixed: 2026-04-26
Rule: `require_database_close`
File: `lib/src/rules/resources/resource_management_rules.dart` (line 146, code at 163–222)
Severity: False positive (lifetime-scope analysis)
Rule version: v6 → v7 | Severity in code: WARNING | Impact: critical

## Resolution

Implemented Fix 1 from this report. The rule now exempts methods whose name
starts with `init` / `_init` / `open` / `_open` / `setup` / `_setup` AND whose
declared return type is `Future<bool>` / `Future<void>` / `bool` / `void`
(success-flag returns). Methods that hand back a connection
(`Future<Database>`, etc.) still trigger because the return type transfers
ownership. Fix 2 (cross-method flow analysis) remains a longer-term option.

The downstream `// ignore: require_database_close` in
`contacts/lib/service/backup/backup_workmanager_service.dart` at the
`_initBackground` declaration can be removed once `saropa_lints` is upgraded
past this change.

---

## Summary

The rule scans a single `MethodDeclaration` for `openDatabase` / `Database()` / `SqliteDatabase()` invocations and requires a matching `.close()` / `.dispose()` call within **the same method body**. It does not analyze caller chains.

This produces a false positive on a common production pattern: a helper method (typically named `_initBackground`, `_setupConnection`, `openWithRetry`) opens databases and returns control to its caller, which then orchestrates the work inside a try-block and closes the connection in a `finally` clause. The helper's job is *to open*, not to manage the full lifetime — the caller's `try { use; } finally { close; }` is the lifetime contract.

This pattern is correct, idiomatic, and necessary in cases where:

- the helper is shared by multiple callers, each with different work to do between open and close;
- the helper is recursive across migration / retry / fallback paths and must not close the connection it just opened until the caller signals success;
- the helper runs in a different sync context (e.g., WorkManager isolate startup) where the caller decides which close path to take based on outcome.

---

## Attribution Evidence

```bash
$ grep -rn "'require_database_close'" lib/src/rules/
lib/src/rules/resources/resource_management_rules.dart:164:    'require_database_close',
```

Rule lives here. Confirmed.

**Emitter registration:** `lib/src/rules/resources/resource_management_rules.dart:146` (`RequireDatabaseCloseRule`)
**Rule class:** `RequireDatabaseCloseRule` — registered in `lib/src/rules/all_rules.dart`
**Diagnostic `source` / `owner`:** `dart` (saropa_lints native plugin)

---

## Reproducer

Consumer project: `D:\src\contacts`. Site: `lib/service/backup/backup_workmanager_service.dart:146`.

```dart
/// Initializes databases and preference caches in the background isolate.
/// Returns true on success. The caller (executeBackup) is responsible for
/// invoking DriftConfig.close() / IsarConfig.close() in a finally block.
static Future<bool> _initBackground() async {           // LINT — but should NOT lint
  try {
    final bool driftOk = await DriftConfig.initDriftDatabase(caller: 'BackupWorkmanager');
    if (!driftOk) return false;

    if (await IsarToDriftMigrator.isIsarNeeded()) {
      if (!await IsarConfig.initIsarDatabase(caller: 'BackupWorkmanager')) {
        return false;
      }
    }

    if (!await UserPreferenceCacheService.instance.initUserPreferenceCache()) {
      return false;
    }
    await UserPermissionCacheService.instance.initUserPermissionCache();
    await UserEnvOverrideCacheService.instance.initUserEnvOverrideCache();
    return true;
  } on Object catch (error, stack) {
    debugException(error, stack);
    return false;
  }
}
```

The caller is at `lib/service/backup/backup_workmanager_service.dart` `executeBackup()`:

```dart
Future<bool> executeBackup(...) async {
  try {
    if (!await _initBackground()) return false;        // ← OPENS via helper

    try {
      // ... do the actual backup work using the open Drift / Isar handles ...
    } finally {
      await DriftConfig.close();                       // ← CLOSES in caller's finally
      await IsarConfig.close();
    }
    return true;
  } on Object catch (...) { ... }
}
```

The close lifecycle is correct and complete — but it is split across two methods, and the rule sees only one method at a time.

**Frequency:** Always — every helper method that opens a database without closing it in the same body, regardless of whether a caller correctly manages the lifetime.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when the open is in a helper whose caller closes the connection. The lint cannot statically prove the caller is correct in all cases, but should at minimum exempt the explicit `init*` / `open*` / `setup*` naming convention that signals "open-in-helper". A more robust fix: walk known call sites and accept any caller-side `try { … } finally { close(); }`. |
| **Actual** | `[require_database_close]` fires unconditionally on any single method whose body opens but does not close. The rule cannot recognize the open-in-helper / close-in-caller pattern. |

---

## AST Context

```
MethodDeclaration (_initBackground) — async
  └─ BlockFunctionBody
      └─ TryStatement
          ├─ Block
          │   ├─ ExpressionStatement (await DriftConfig.initDriftDatabase(...))   ← detected as DB open
          │   ├─ IfStatement (... return false)
          │   ├─ IfStatement (await IsarConfig.initIsarDatabase(...))             ← also detected as DB open
          │   ├─ IfStatement (cache init checks)
          │   └─ ReturnStatement (true)
          └─ CatchClause (debugException; return false)
```

The rule walks the body, finds at least one DB-open invocation, walks the body again for `.close(` / `.dispose(`, finds none, reports.

---

## Root Cause

### Hypothesis A: lifetime is split across method boundaries; rule cannot see it

The rule's analysis scope is a single method body. There is no caller-chain walk, no project-wide flow analysis, no annotation that would let the helper say "I open; my caller closes". The helper looks like a leak; the rule reports the leak.

### Hypothesis B: naming convention not exempted

The Saropa Drift / Isar codebase uses `_initX`, `initX`, `openX`, `setupX` naming for helpers that open. A simple safer-default heuristic: if the method name starts with `_init` / `init` / `open` / `setup` AND it returns `Future<bool>` or `Future<void>` (i.e., its purpose is signaling success rather than handing back the connection), the rule could exempt it.

This is a heuristic and would have a small false-negative cost (a genuinely-leaky `_initFoo` would not be flagged), but the current signal-to-noise ratio is poor: every WorkManager / BackgroundService isolate setup helper in the codebase trips the rule.

### Hypothesis C: explicit annotation / pragma

Long-term: a pragma like `@pragma('vm:lifetime-managed-by-caller')` on the helper, with the rule respecting it. This requires support across the analyzer, which is heavyweight for a single rule. Not the right fix.

---

## Suggested Fix

Two layered options:

### Fix 1 — Exempt `_init` / `init` / `open` / `setup` helpers that return `Future<bool>` / `Future<void>`

```dart
@override
void runWithReporter(SaropaDiagnosticReporter reporter, SaropaContext context) {
  // …existing setup…
  context.addMethodDeclaration((MethodDeclaration node) {
    final String methodName = node.name.lexeme;
    final TypeAnnotation? returnType = node.returnType;

    // Helper-style methods that hand off lifetime management to their caller:
    // their bool/void return signals success/failure, the connection is held
    // open for the caller to use and close.
    final bool looksLikeOpenHelper =
        (methodName.startsWith('_init') ||
         methodName.startsWith('init') ||
         methodName.startsWith('open') ||
         methodName.startsWith('setup'));
    final String? returnSource = returnType?.toSource();
    final bool returnsBoolOrVoid =
        returnSource == 'Future<bool>' || returnSource == 'Future<void>';

    if (looksLikeOpenHelper && returnsBoolOrVoid) return;

    // …existing detection…
  });
}
```

### Fix 2 — Cross-method analysis

When a method opens but does not close, walk caller AST nodes (within the same compilation unit at minimum) for any `try { …call(method)… } finally { …close() … }` shape. Exempt if found. This is more correct but more expensive.

Fix 1 closes the contacts case immediately. Fix 2 is the longer-term improvement.

---

## Fixture Gap

The fixture should include:

1. **Method opens DB and never closes; no caller closes either** — expect LINT (current correct case)
2. **Method opens DB and closes in same body's finally** — expect NO lint (current correct case)
3. **Method named `_initBackground`, opens DB, returns Future<bool>; caller closes in finally** — expect NO lint *(currently false positive)*
4. **Method named `getUserById`, opens DB, returns Future<User?>; caller does NOT close** — expect LINT (genuine leak)
5. **Method named `setupDatabase`, opens DB, returns Future<void>; caller closes** — expect NO lint *(currently false positive)*
6. **Method named `openConnection`, opens DB, returns the connection** — exempt or not depending on Fix 1 vs Fix 2; document the chosen behavior.

---

## Downstream

Tracked in `contacts/`. `// ignore: require_database_close` added at `lib/service/backup/backup_workmanager_service.dart:146` (the `_initBackground` declaration line) with a comment pointing here.

Sibling existing reports closed in saropa_lints history:

- `plan/history/2026.03/20260303/require_database_close_false_positive_string_literal_rule_files.md` — different scope (rule files self-trigger). Already fixed.
- `bugs/avoid_platform_specific_imports_false_positive_mobile_only_no_web_dir.md` — unrelated (mobile-only).

This caller-managed-lifetime FP is distinct from both.

---

## Environment

- saropa_lints version: 12.5.1+
- Dart SDK: 3.9.x
- Triggering project: `d:/src/contacts`
- Platform: Windows 11
