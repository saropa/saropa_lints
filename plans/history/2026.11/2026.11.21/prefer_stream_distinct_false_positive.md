# BUG: `prefer_stream_distinct` — fires on payload-less refresh signal streams

**Status: Fixed**

Rule: `prefer_stream_distinct`
File: `lib/src/rules/core/async_rules.dart`
Severity: False positive
Sites in downstream app: 5 of 6 sites in 4 files (the sixth is a DB-row stream without cheap equality, not claimed)

---

## Summary

`.distinct()` is suggested, which would break the signal. The code is correct; each site carries an `// ignore:` workaround.

---

## Attribution Evidence

```bash
grep -rn "'prefer_stream_distinct'" lib/src/rules/
# Expected: lib/src/rules/core/async_rules.dart:NN
```

---

## Reproducer

```dart
// Stream where every event is the same value: a "something changed, re-read" signal.
final StreamSubscription<bool> sub =
    prefChanged.stream.listen((_) => _reload()); // LINT, but should NOT lint
// distinct() would drop every event after the first and stop the refresh.
```

**Frequency:** Only with the pattern above.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when the listener ignores its parameter or the element type is `void`/`Null`. |
| **Actual** | `.distinct()` is suggested, which would break the signal. |

---

## Suggested Fix

Skip when the listener callback ignores its parameter or the stream element type is `void`/`Null`. Add a fixture for the pattern above to the rule's example fixtures.


Status: Fixed (2026-11-21)
