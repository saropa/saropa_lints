# BUG: `avoid_ios_hardcoded_status_bar` — flags plain SizedBox spacing of 20/44

**Status: Open**

Created: 2026-11-23
Rule: `avoid_ios_hardcoded_status_bar`
File: `lib/src/rules/platforms/ios_ui_security_rules.dart` (line ~145)
Severity: False positive
Rule version: v2 | saropa_lints 17.7.0

---

## Summary

The rule reports any numeric literal 20/44/47/59 passed as `height` to a `SizedBox`, even when the widget is plain vertical spacing between form sections and has nothing to do with the status bar. Expected: no report unless the value is used as a top inset / status bar offset (e.g. `Padding(top: 44)` at the screen top, or a SizedBox in a Stack positioned at the top edge).

---

## Attribution Evidence

```bash
grep -rn "'avoid_ios_hardcoded_status_bar'" lib/src/rules/
# lib/src/rules/platforms/ios_ui_security_rules.dart:145
```

---

## Reproducer

```dart
Widget build(BuildContext context) => ListView(
      children: const [
        Text('Name'),
        SizedBox(height: 20), // LINT — but should NOT lint (spacing between rows)
        Text('Search'),
        SizedBox(height: 44), // LINT — but should NOT lint (fixed chip row height)
      ],
    );
```

**Frequency:** Always.

Message: `[avoid_ios_hardcoded_status_bar] Hardcoded status bar height (20, 44, 47, or 59) may cause UI issues on different iOS devices. {v2}`

Observed in jupiter-tablet `lib/ui/class_style_editor.dart` (5 sites).
