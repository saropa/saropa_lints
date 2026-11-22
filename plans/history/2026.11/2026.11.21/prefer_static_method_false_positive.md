# BUG: `prefer_static_method` — fires on methods that call instance members or are called through an instance

**Status: Fixed**

Rule: `prefer_static_method`
File: `lib/src/rules/architecture/structure_rules.dart`
Severity: False positive
Sites in downstream app: 2 sites in 2 files

---

## Summary

The method is reported as if it used no instance state. The code is correct; each site carries an `// ignore:` workaround.

---

## Attribution Evidence

```bash
grep -rn "'prefer_static_method'" lib/src/rules/
# Expected: lib/src/rules/architecture/structure_rules.dart:NN
```

---

## Reproducer

```dart
class _State extends State<W> {
  void _onCachesChanged() => unawaited(_reloadRowsQuietly()); // LINT, but should NOT lint
  Future<void> _reloadRowsQuietly() async { /* uses setState, widget */ }
}
// Variant: a method invoked as widget.button._buildTile(...) from another class
// in the same library; it is an instance call target.
```

**Frequency:** Only with the pattern above.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when the body invokes another instance method, or the method is referenced through an instance receiver elsewhere in the library. |
| **Actual** | The method is reported as if it used no instance state. |

---

## Suggested Fix

Resolve unqualified invocations to instance members of the enclosing class (including mixin members) as instance usage; skip methods with instance-receiver call sites in the library. Add a fixture for the pattern above to the rule's example fixtures.


Status: Fixed (2026-11-21)
