# BUG: `avoid_context_after_navigation` — fires although a context.mounted guard precedes the navigator call

**Status: Fixed**

Rule: `avoid_context_after_navigation`
File: `lib/src/rules/ui/navigation_rules.dart`
Severity: False positive
Sites in downstream app: 1 site in 1 file

---

## Summary

The navigator call is reported. The code is correct; each site carries an `// ignore:` workaround.

---

## Attribution Evidence

```bash
grep -rn "'avoid_context_after_navigation'" lib/src/rules/
# Expected: lib/src/rules/ui/navigation_rules.dart:NN
```

---

## Reproducer

```dart
if (!context.mounted) return;
await Navigator.maybePop(context); // LINT, but should NOT lint
// context is used only after the mounted check and re-checked after the await.
```

**Frequency:** Only with the pattern above.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when `context.mounted` is checked before the use. |
| **Actual** | The navigator call is reported. |

---

## Suggested Fix

Recognize an early-return `if (!context.mounted) return;` earlier in the same block as a guard. Add a fixture for the pattern above to the rule's example fixtures.


Status: Fixed (2026-11-21)
