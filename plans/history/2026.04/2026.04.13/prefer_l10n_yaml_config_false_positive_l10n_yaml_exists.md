# BUG: `prefer_l10n_yaml_config` — False positive when `l10n.yaml` already exists

**Status: Closed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-04-13
Rule: `prefer_l10n_yaml_config`
File: `extension/src/pubspec-validation.ts` (line ~628)
Severity: False positive
Rule version: v1 | Since: v10.11.0

---

## Summary

The rule fires on `generate: true` under the `flutter:` section of `pubspec.yaml` even when a dedicated `l10n.yaml` file already exists at the project root. The rule's purpose is to encourage moving l10n configuration to `l10n.yaml` — but when that file already exists, `generate: true` is **required** in pubspec.yaml by Flutter tooling. Flagging it is a false positive: the user has already done what the rule recommends, and removing `generate: true` would break their build.

---

## Reproducer

Project layout that triggers the false positive:

```
my_app/
├── l10n.yaml              ← dedicated l10n config (exactly what the rule wants)
├── pubspec.yaml
│     flutter:
│       generate: true      ← LINT fires here — but should NOT
│       uses-material-design: true
└── lib/
      └── l10n/
            └── app_en.arb
```

`pubspec.yaml` excerpt:

```yaml
flutter:
  # Required by Flutter tooling to enable l10n code generation (even though
  # l10n.yaml at the project root holds the actual config).
  generate: true        # LINT — but should NOT lint (false positive)

  uses-material-design: true
```

`l10n.yaml` exists and contains the actual l10n configuration (template ARB file, output class, synthetic package flag, etc.).

**Frequency:** Always — fires on every project that has both `l10n.yaml` and `generate: true`.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — `l10n.yaml` exists, so the project already follows the recommended pattern. `generate: true` is a required Flutter tooling flag, not inline l10n config. |
| **Actual** | `[saropa_lints] inline 'generate: true' under flutter — prefer a dedicated 'l10n.yaml' file for localization config` reported on the `generate` line |

---

## AST Context

Not applicable — this is a VS Code extension diagnostic (text-based YAML line scanning), not a Dart analyzer rule. No AST involved.

The detection logic at `pubspec-validation.ts:628–666` (`checkL10nYamlConfig`) scans lines for `generate: true` under the `flutter:` section using a regex match. It has no awareness of the filesystem.

---

## Root Cause

### Hypothesis A: Missing filesystem check (confirmed)

The function `checkL10nYamlConfig` (line 628) accepts only `lines` and `diagnostics` — it has no access to the pubspec URI or workspace path, so it **cannot** check whether `l10n.yaml` exists alongside `pubspec.yaml`.

```typescript
// Current signature — no filesystem context
function checkL10nYamlConfig(
    lines: string[],
    diagnostics: vscode.Diagnostic[],
): void {
```

The call site at line 703 also passes only `lines` and `diagnostics`:

```typescript
checkL10nYamlConfig(lines, diagnostics);
```

The `update()` method (line 684) receives `uri: vscode.Uri` — the URI of the pubspec.yaml file. This URI is available but never forwarded to `checkL10nYamlConfig`.

The rule unconditionally flags `generate: true` without checking whether the project already has a dedicated `l10n.yaml` file. Since Flutter **requires** `generate: true` in pubspec.yaml even when `l10n.yaml` exists (it's the flag that enables the code generator), the diagnostic is wrong for any project that has already adopted the recommended pattern.

### Not a version mismatch

The CHANGELOG confirms this rule was added in v10.11.0 and has received **no fixes** in v10.12.0 or v10.12.1. The false positive has existed since the rule was introduced.

---

## Suggested Fix

1. **Pass the pubspec URI** to `checkL10nYamlConfig` so it can derive the workspace root.

2. **Check for `l10n.yaml`** in the same directory as `pubspec.yaml`. If the file exists, skip the diagnostic.

```typescript
// Updated signature — receives the pubspec URI for filesystem checks
function checkL10nYamlConfig(
    lines: string[],
    diagnostics: vscode.Diagnostic[],
    pubspecUri: vscode.Uri,
): void {
    // Suppress when l10n.yaml already exists alongside pubspec.yaml
    const workspaceDir = vscode.Uri.joinPath(pubspecUri, '..');
    const l10nYamlUri = vscode.Uri.joinPath(workspaceDir, 'l10n.yaml');
    try {
        // fs.stat throws if file does not exist
        const fs = require('fs');
        if (fs.existsSync(l10nYamlUri.fsPath)) { return; }
    } catch {
        // File does not exist — continue to flag
    }

    // ... existing detection logic unchanged ...
}
```

3. **Update the call site** in `update()` (line 703):

```typescript
checkL10nYamlConfig(lines, diagnostics, uri);
```

**Note:** Using synchronous `fs.existsSync` is acceptable here because `update()` is already synchronous and the pubspec diagnostic pipeline runs on content change with a 300ms debounce. A single `stat` call adds negligible overhead.

---

## Fixture Gap

The test file at `extension/src/test/pubspec-validation.test.ts` (line ~708) has four test cases — none of them test the scenario where `l10n.yaml` exists:

1. **Missing case: `l10n.yaml` exists alongside pubspec** — expect NO diagnostic. This is the primary false positive scenario and the highest-priority test to add.
2. **Missing case: `l10n.yaml` does NOT exist** — expect diagnostic (confirms the rule still fires when appropriate).

Since the test harness calls `runValidation(content)` with only pubspec content (no filesystem context), the tests will need a way to mock or inject the `l10n.yaml` existence check. Options:
- Inject an `l10nYamlExists: boolean` parameter (simplest)
- Use a test helper that creates a temp directory with/without `l10n.yaml`

---

## Changes Made

- **`extension/src/pubspec-validation.ts`**: Added `import * as fs from 'node:fs'`. Added `pubspecUri` parameter to `checkL10nYamlConfig`. Early-returns when `l10n.yaml` exists in the same directory as `pubspec.yaml`. Updated call site in `update()` to pass `uri`.
- **`extension/src/test/pubspec-validation.test.ts`**: Added `fs`, `os`, `path` imports. Extended `runValidation` opts to accept a custom `pubspecUri`. Added two new tests: one with `l10n.yaml` present (expects no diagnostic) and one without (expects diagnostic).

---

## Tests Added

- `does not flag when l10n.yaml exists alongside pubspec` — creates a temp directory with `l10n.yaml`, verifies the rule produces zero diagnostics for `generate: true`.
- `flags when l10n.yaml does not exist alongside pubspec` — creates a temp directory without `l10n.yaml`, verifies the rule fires as expected.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: 10.12.1 (latest)
- Dart SDK version: N/A (VS Code extension rule, not Dart analyzer)
- custom_lint version: N/A
- Triggering project: `d:\src\contacts` — has `l10n.yaml` at project root and `generate: true` under `flutter:` in `pubspec.yaml`
- VS Code diagnostic severity shown: Error (severity 2) in Problems panel, though code sets `DiagnosticSeverity.Information` — may be a separate display issue or VS Code mapping
