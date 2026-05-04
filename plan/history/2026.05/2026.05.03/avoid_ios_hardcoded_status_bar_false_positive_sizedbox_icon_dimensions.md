# BUG: `avoid_ios_hardcoded_status_bar` — False positive on SizedBox icon container dimensions

**Status: Fix Ready**

Created: 2026-05-03
Closed: 2026-05-03
Rule: `avoid_ios_hardcoded_status_bar`
File: `lib/src/rules/platforms/ios_ui_security_rules.dart` (class `AvoidIosHardcodedStatusBarRule`, `runWithReporter` ~161; `_checkNumericArgument` ~195)
Severity: False positive
Rule version: v2 (per `LintCode` message suffix)

---

## Summary

The rule flags `SizedBox(height: 20)` whenever 20 is used as the height — even when the SizedBox is sized to wrap an icon and has nothing to do with the iOS status bar. There is no parent / sibling / surrounding-widget context check; any `SizedBox(height: 20|44|47|59)` lints.

Related (same root mechanism, different surface): `plan/history/2026.04/2026.04.25/avoid_ios_hardcoded_status_bar_false_positive_generic_padding.md` covers the `EdgeInsets.only(top: …)` variant. That doc lives in `plan/history/` rather than `bugs/`, contrary to `bugs/BUG_REPORT_GUIDE.md` policy. This report is the SizedBox-specific instance with a concrete downstream reproducer.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_ios_hardcoded_status_bar'" lib/src/rules/
# lib/src/rules/platforms/ios_ui_security_rules.dart:143:    'avoid_ios_hardcoded_status_bar',
```

**Emitter registration:** `lib/src/rules/platforms/ios_ui_security_rules.dart:143`
**Rule class:** `AvoidIosHardcodedStatusBarRule` — registered in `lib/src/rules/all_rules.dart` via `export 'platforms/ios_ui_security_rules.dart';`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` (owner `_generated_diagnostic_collection_name_#3`)

---

## Reproducer

Minimal pattern — an icon container sized to 20×20:

```dart
import 'package:flutter/widgets.dart';

Widget statusIcon() {
  return SizedBox(
    width: 20,
    height: 20, // LINT — but this is an icon container, not a status bar offset.
    child: Placeholder(),
  );
}
```

**Downstream example:** `contacts/lib/components/primitive/dialog/import_progress_dialog.dart:316` —
`_buildStatusIcon` returns a `SizedBox(width: 20, height: 20, child: CommonIcon(...))`
to host an icon that itself renders at 14 or 16 logical pixels. The `20×20` is the touch / hit
box for the icon glyph — entirely unrelated to a status bar height.

**Frequency:** Always — every `SizedBox(height: 20|44|47|59)` lints regardless of context.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic on icon-sized SizedBox containers. The lint should require some signal that the value is being used as a status-bar offset (e.g. ancestor `SafeArea`, sibling `MediaQuery.padding.top` reference, or root scaffold context). |
| **Actual** | `[avoid_ios_hardcoded_status_bar] Hardcoded status bar height (20, 44, 47, or 59) may cause UI issues on different iOS devices. {v2}` reported on every `SizedBox(height: 20)`. |

---

## AST Context

```
MethodInvocation (returns Widget)
  └─ InstanceCreationExpression (SizedBox)
      └─ ArgumentList
          ├─ NamedExpression (width: 20)
          └─ NamedExpression (height: 20)  ← node reported here
              └─ IntegerLiteral (20)
```

---

## Root Cause

`_checkNumericArgument` at `ios_ui_security_rules.dart:195` reads the `height` argument
on every `SizedBox` and reports if the integer value is in `{20, 44, 47, 59}` — there is
no surrounding-context check at all. See lines 174–177:

```dart
// Check SizedBox(height: XX)
if (node.typeName == 'SizedBox') {
  _checkNumericArgument(node, 'height', reporter);
}
```

20 in particular is a common Material/Cupertino dimension for icon hitboxes, badge sizes,
indicator dots, and small leading widgets. Without context, the rule's recall is fine but
its precision on `20` is poor.

---

## Suggested Fix

1. **Narrow the SizedBox case.** Only flag a SizedBox `height` literal when there is corroborating evidence the SizedBox is acting as a status-bar offset — e.g. it appears as the first child of a `Column` directly under `Scaffold`, or a sibling reads `MediaQuery.padding.top`, or it is named-arg `top:` of a `Stack`. Anything else is too noisy for `20`.
2. **Consider dropping `20` from the SizedBox height match set.** 44/47/59 are unusual outside status-bar contexts, but `20` is a routine icon dimension. Keeping `20` only for the `EdgeInsets.only(top: 20)` shape (where it is plausibly status-bar offset) and removing it from the SizedBox path would cut nearly all the FPs without losing the high-signal cases.
3. **Add a `child:` heuristic** — if the SizedBox's `child` is an `Icon`, `CommonIcon`, `FaIcon`, `ImageIcon`, `CircularProgressIndicator`, or any expression whose name ends in `Icon`, do not lint. The user is sizing the icon's hitbox, not the status bar.

---

## Fixture Gap

The fixture at `example*/lib/ios/avoid_ios_hardcoded_status_bar_fixture.dart` should include:

1. **`SizedBox(width: 20, height: 20, child: Icon(...))`** — expect NO lint (icon container).
2. **`SizedBox(height: 20, child: Placeholder())` directly under `Scaffold` body** — expect LINT (plausible status-bar offset).
3. **`SizedBox(height: 44, child: Icon(...))`** — expect NO lint (Material 44dp touch target).

---

## Environment

- saropa_lints version: (HEAD, 2026-05-03)
- Triggering project/file: `contacts/lib/components/primitive/dialog/import_progress_dialog.dart:316`
- Triggering snippet: `SizedBox(width: 20, height: 20, child: CommonIcon(...))`

---

## Resolution

Implemented suggestion #3 (child heuristic) and a strict version of suggestion #1
(width-set heuristic) in [lib/src/rules/platforms/ios_ui_security_rules.dart](../lib/src/rules/platforms/ios_ui_security_rules.dart).

**Behavior change for `SizedBox`:** the rule now flags only when the SizedBox is
shaped like a pure vertical spacer — `height` set to one of {20, 44, 47, 59} and
**no** `width` parameter and **no** Icon-like `child`. Either signal disqualifies
the lint:

1. `width` is also set → fixed-size container, not a status-bar offset (which
   only sets `height`).
2. `child` is `Icon` / `ImageIcon` / `FaIcon` / `CircularProgressIndicator` /
   `CupertinoActivityIndicator` / `Image` / any class whose name ends with `Icon`
   (covers `CommonIcon`, `MdiIcon`, project-specific wrappers).

`EdgeInsets.only(top:)` and `Container(padding: EdgeInsets.only(top:))` paths
are unchanged — those are addressed by a separate report
([generic padding](../plan/history/2026.04/2026.04.25/avoid_ios_hardcoded_status_bar_false_positive_generic_padding.md)).

### Verification

- `SizedBox(width: 20, height: 20, child: CommonIcon())` — no longer lints (downstream reproducer).
- `SizedBox(width: 20, height: 20, child: Icon(null))` — no longer lints.
- `SizedBox(height: 44, child: Icon(null))` — no longer lints (Material touch target).
- `SizedBox(height: 47)` — still lints (pure spacer, plausible status-bar offset).
- `SizedBox(height: 59)` — still lints (pre-existing BAD case).

Fixture updated: [example/lib/ios/avoid_ios_hardcoded_status_bar_fixture.dart](../example/lib/ios/avoid_ios_hardcoded_status_bar_fixture.dart).
