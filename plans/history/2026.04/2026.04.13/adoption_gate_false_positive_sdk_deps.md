# BUG: Adoption Gate — False "Discontinued" on SDK Dependencies

**Status: Fix Ready**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-04-13
Component: VS Code extension — Package Vibrancy Adoption Gate
File: `extension/src/vibrancy/providers/adoption-gate.ts` (line ~131)
Severity: False positive
Since: adoption gate introduction

---

## Summary

The Adoption Gate decorator shows "Discontinued" (red warning badge) on Flutter
SDK dependencies (`flutter`, `flutter_test`, `flutter_localizations`,
`integration_test`). The `flutter` package on pub.dev is genuinely marked as
discontinued (it is an SDK, not a hosted package), so looking it up on pub.dev
produces a misleading result.

A secondary issue: `findPackageLine` matches the **first** `^\s{2}flutter\s*:`
line in the file, which is often the `environment:` section constraint (e.g.
`flutter: ">=3.41.2"`), not the `dependencies:` section entry. This puts the
"Discontinued" badge on the wrong line entirely.

---

## Reproducer

Any `pubspec.yaml` with a standard Flutter SDK dependency:

```yaml
environment:
  sdk: ">=3.10.7 <4.0.0"
  flutter: ">=3.41.2"            # ← "Discontinued" badge appears HERE

dependencies:
  flutter:
    sdk: flutter                 # ← The actual SDK dep entry
  flutter_localizations:
    sdk: flutter
  flutter_test:
    sdk: flutter
```

**Frequency:** Always, on every pubspec.yaml with SDK dependencies.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic or decoration for SDK dependencies — they are not hosted packages |
| **Actual** | "Discontinued" badge (red/warning) appears on the `environment:` `flutter:` line |

---

## Root Cause

Two bugs combine to produce this:

### Bug 1: `findCandidates` does not filter SDK dependencies

`findCandidates()` (adoption-gate.ts:131) calls `parsePubspecYaml()` which
extracts all names under `dependencies:` and `dev_dependencies:`. SDK entries
like `flutter:` with `sdk: flutter` sub-key are included.

The main scan pipeline correctly filters these out because `parsePubspecLock`
assigns `source: "sdk"` and `isScannableSource("sdk")` returns false. But the
adoption gate bypasses the lock file — it only checks which names are NOT in
existing scan results (line 137). Since SDK deps are never scanned, they always
appear as "candidates" and get looked up on pub.dev individually.

Other features already handle this correctly:
- `annotate-command.ts:70` filters with `SDK_PACKAGES` set
- `unused-detector.ts:21` filters with its own `SDK_PACKAGES` set
- `pubspec-sorter.ts:13` has a third `SDK_PACKAGES` set

The adoption gate is the only consumer that forgot to filter.

### Bug 2: `findPackageLine` matches wrong section

`findPackageLine()` (adoption-gate.ts:193) uses `^\s{2}<name>\s*:` which
matches any 2-space-indented `flutter:` line. In a typical pubspec.yaml, the
`environment:` section comes before `dependencies:`, so the first match is:

```yaml
  flutter: ">=3.41.2"   # environment constraint — matched first
```

...instead of:

```yaml
  flutter:               # dependency entry — correct target
    sdk: flutter
```

---

## Suggested Fix

### Fix 1: Filter SDK packages in `findCandidates`

Extract the duplicated `SDK_PACKAGES` set into a shared constant (e.g.
`extension/src/vibrancy/sdk-packages.ts`) and import it in all three current
locations plus `adoption-gate.ts`. Filter candidates before lookup:

```typescript
return allNames.filter(name => !resolved.has(name) && !SDK_PACKAGES.has(name));
```

### Fix 2: Scope `findPackageLine` to dependency sections

Change `findPackageLine` to only match within `dependencies:` or
`dev_dependencies:` sections, not inside `environment:` or other top-level keys.

---

## Changes Made

### File 1: `extension/src/vibrancy/sdk-packages.ts` (new)

Centralized `SDK_PACKAGES` constant used by adoption gate, annotate command,
unused-detector, and pubspec sorter. Includes `integration_test` and
`flutter_driver` which were missing from some previous copies.

### File 2: `extension/src/vibrancy/providers/adoption-gate.ts`

**Bug 1 fix — `findCandidates` now filters SDK packages:**

```typescript
// Before:
return allNames.filter(name => !resolved.has(name));

// After:
return allNames.filter(name => !resolved.has(name) && !SDK_PACKAGES.has(name));
```

**Bug 2 fix — `findPackageLine` now scopes to dependency sections:**

```typescript
// Before: matched any 2-space-indented line in the entire file
function findPackageLine(lines: string[], name: string): number {
    const pattern = new RegExp(`^\\s{2}${name}\\s*:`);
    return lines.findIndex(line => pattern.test(line));
}

// After: only matches within dependencies/dev_dependencies/dependency_overrides
function findPackageLine(lines: string[], name: string): number {
    // ... tracks section state, only matches inside dep sections
}
```

### File 3-5: Deduplicated `SDK_PACKAGES`

- `extension/src/vibrancy/providers/annotate-command.ts` — replaced local set with import
- `extension/src/vibrancy/scoring/unused-detector.ts` — replaced local set with import
- `extension/src/vibrancy/services/pubspec-sorter.ts` — replaced local set with import (also gained `flutter_driver` and `integration_test`)

### File 6: `extension/tsconfig.test.json` + `extension/package.json`

Added `adoption-gate.test.ts` to test compilation includes and mocha runner.

---

## Tests Added

- `extension/src/test/vibrancy/providers/adoption-gate.test.ts`:
  - "should exclude SDK packages (flutter, flutter_test, etc.)" — verifies flutter, flutter_localizations, flutter_test, integration_test are filtered
  - "should exclude flutter_web_plugins and flutter_driver" — verifies remaining SDK deps are filtered

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: 10.11.1
- Flutter SDK: 3.41.6
- Dart SDK: 3.10.7
- Triggering project: D:\src\contacts\pubspec.yaml
