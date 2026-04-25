# BUG: `avoid_ios_hardcoded_status_bar` — False positive on generic top padding

**Status: Open**

Created: 2026-04-25  
Rule: `avoid_ios_hardcoded_status_bar`  
File: `lib/src/rules/platforms/ios_ui_security_rules.dart` (class `AvoidIosHardcodedStatusBarRule`, `runWithReporter` ~161)  
Severity: False positive  
Rule version: v2 (per `LintCode` message suffix)

---

## Summary

The rule treats any literal **20**, **44**, **47**, or **59** in a few widget argument positions as a hardcoded iOS status-bar height. That matches ordinary spacing (especially **20** for padding/margins) when `EdgeInsets.only(top: …)` is used for layout unrelated to the status bar or safe area.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_ios_hardcoded_status_bar'" lib/src/rules/
# lib/src/rules/platforms/ios_ui_security_rules.dart:143:    'avoid_ios_hardcoded_status_bar',
```

**Emitter registration:** `lib/saropa_lints.dart` (plugin rule list includes `AvoidIosHardcodedStatusBarRule.new`)  
**Rule class:** `AvoidIosHardcodedStatusBarRule` — module exported from `lib/src/rules/all_rules.dart` via `export 'platforms/ios_ui_security_rules.dart';`

---

## Reproducer

Minimal pattern (same shape as generic card/section padding; should ideally **not** lint if the rule gains context):

```dart
import 'package:flutter/widgets.dart';

Widget paddedCard() {
  return Padding(
    // LINT today — but this is symmetric vertical spacing, not status-bar offset.
    padding: const EdgeInsets.only(left: 16, top: 20, right: 16, bottom: 20),
    child: const Placeholder(),
  );
}
```

**Downstream example:** `contacts/lib/components/home/components/welcome_screen.dart` used `EdgeInsets.only(... top: 20, bottom: 20, ...)` for generic layout; the rule flagged `top: 20`.

**Frequency:** Always, whenever `top` (or `SizedBox` height, or `Container` + `EdgeInsets.only` top) uses one of the four magic integers.

---

## Expected vs Actual

- **Expected:** Flag literals that plausibly substitute for `MediaQuery.padding.top` / safe-area inset (e.g. root scaffold padding, app-bar overlap workarounds), not every `top: 20` in arbitrary UI.
- **Actual:** `_checkNumericArgument` flags solely on numeric value membership in `{20, 44, 47, 59}` for `EdgeInsets.only(top:)`, `SizedBox(height:)`, and `Container` padding with `EdgeInsets.only(top:)` — no parent or sibling context.

**Scope note:** The rule does **not** inspect `EdgeInsets.symmetric(vertical: 20)` or `EdgeInsets.all(20)`; only the named-parameter paths above.

---

## Suspected Root Cause

`AvoidIosHardcodedStatusBarRule` maps status-bar heights to a fixed set of integers and matches literals in a narrow AST shape without checking whether the widget sits under a `SafeArea`, uses `MediaQuery` elsewhere, or is clearly non-root spacing (heuristic).

---

## Suggested Fix

1. Add conservative context before reporting (e.g. ancestor `SafeArea`, `MediaQuery`-derived padding on the same subtree, or restrict to patterns strongly associated with status-bar offset — document trade-offs to avoid false negatives).
2. Consider narrowing or de-emphasizing **20**: it overlaps common design-token spacing; **44/47/59** are rarer in generic UI but still not proof of status-bar intent.
3. Add an example fixture where generic `EdgeInsets.only(top: 20, bottom: 20, …)` is **OK** once behavior is adjusted; keep existing BAD examples for true status-bar hardcodes.
