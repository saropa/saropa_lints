# BUG: `dependencies_ordering` — False positive on SDK dependencies

**Status: Fix Ready**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-04-13
Rule: `dependencies_ordering`
File: `extension/src/pubspec-validation.ts` (line ~194)
Severity: False positive
Rule version: v10.11.0

---

## Summary

The `dependencies_ordering` rule flags SDK dependencies (`flutter`, `flutter_localizations`, `flutter_test`, `integration_test`) as out of alphabetical order when they appear before pub-hosted packages. SDK dependencies are conventionally placed first in their section because everything else depends on them — the rule should exempt them from alphabetical sorting.

---

## Reproducer

Minimal `pubspec.yaml` that triggers the bug:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter

  airplane_mode_checker: ^3.2.0
  http: ^1.6.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter

  analyzer: any
  build_runner: ^2.7.1
```

**Frequency:** Always — any project with SDK deps before pub deps.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — SDK deps at top of section is conventional and correct |
| **Actual** | `'dependencies' are not sorted alphabetically — 'flutter' should come after 'airplane_mode_checker'` and `'dev_dependencies' are not sorted alphabetically — 'flutter_test' should come after 'analyzer'` |

---

## Root Cause

`checkDependencyOrdering()` at line ~194 collects all entry names with `section.entries.map(e => e.name)`, sorts them alphabetically, and compares. It makes no distinction between SDK dependencies (those with `sdk: flutter` as their constraint) and pub-hosted dependencies.

The entry parser already recognizes SDK deps — they appear as entries with a multi-line `sdk: flutter` value. The ordering check just doesn't use this information.

---

## Suggested Fix

Filter SDK dependencies out before the alphabetical comparison, or partition entries into two groups (SDK first, then pub-hosted sorted) before comparing order.

Pseudocode:

```typescript
function checkDependencyOrdering(...): void {
    for (const section of sections) {
        // Partition: SDK deps first (preserve original order), then pub deps sorted
        const sdkEntries = section.entries.filter(e => e.constraint === 'sdk: flutter');
        const pubEntries = section.entries.filter(e => e.constraint !== 'sdk: flutter');

        // Only check alphabetical order among pub-hosted entries
        const pubNames = pubEntries.map(e => e.name);
        const sorted = [...pubNames].sort((a, b) =>
            a.toLowerCase().localeCompare(b.toLowerCase()),
        );

        // Compare and report as before, but only for pub entries
        // ...
    }
}
```

The exact SDK detection depends on how `entry.constraint` is stored — may need to check for `sdk:` prefix or a dedicated `isSdk` flag on the parsed entry.

---

## Fixture Gap

The test fixture at `extension/src/test/pubspec-validation.test.ts` should include:

1. **SDK deps before pub deps** — expect NO diagnostic
2. **SDK deps after pub deps** — expect NO diagnostic (SDK position is flexible)
3. **Pub deps unsorted with SDK at top** — expect diagnostic only on the pub dep, not the SDK dep
4. **Multiple SDK deps** (`flutter` + `flutter_localizations`) — expect NO diagnostic regardless of their mutual order

---

## Environment

- saropa_lints version: 10.11.0
- Dart SDK version: 3.11.4
- Flutter SDK version: 3.41.6
- Triggering project: `d:\src\contacts\pubspec.yaml`
