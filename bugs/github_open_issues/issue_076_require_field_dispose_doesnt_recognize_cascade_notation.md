# [require_field_dispose] doesn't recognize cascade notation

**GitHub:** [https://github.com/saropa/saropa_lints/issues/76](https://github.com/saropa/saropa_lints/issues/76)

**Opened:** 2026-02-02T09:15:35Z

---

## Detail

```dart
  final ValueNotifier<int?> _selectedIndex = ValueNotifier(0);

...

    _selectedIndex
      ..removeListener(_animateToMiddle)
      ..dispose();
```

Despite the above, [require_field_dispose] is still reported.
