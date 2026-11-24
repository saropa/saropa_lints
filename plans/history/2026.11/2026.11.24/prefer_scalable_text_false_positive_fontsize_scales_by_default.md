# BUG: `prefer_scalable_text` — Flags any TextStyle(fontSize:) although Flutter scales it by default

**Status: Open**

Created: 2026-11-23
Rule: `prefer_scalable_text`
File: `lib/src/rules/ui/accessibility_rules.dart` (line ~1883)
Severity: False positive
Rule version: unknown | Since: unknown | Updated: unknown

---

## Summary

Flutter's `Text` multiplies `TextStyle.fontSize` by the ambient `MediaQuery.textScaler` unless `textScaler: TextScaler.noScaling` (or `textScaleFactor: 1`) is set. A literal `fontSize` therefore still respects the user's accessibility font size. The rule should flag only a Text that opts out of scaling.

---

## Attribution Evidence

```bash
grep -rn "'prefer_scalable_text'" lib/src/rules/
# lib/src/rules/ui/accessibility_rules.dart:1883
```

---

## Reproducer

```dart
Widget build(BuildContext context) {
  // LINT — but should NOT lint: no textScaler override, fontSize is scaled by MediaQuery.
  return Text('Send to', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700));
}
```

**Frequency:** Always (about 14 hits in one 380-line file, lib/ui/sheets.dart of the downstream app).

## Expected

No diagnostic unless `textScaler` is `TextScaler.noScaling` / `textScaleFactor: 1.0` or the text sits under a `MediaQuery` that clamps the scaler to 1.

## Environment

saropa_lints 4.15.1 (pubspec.lock of the downstream app).
