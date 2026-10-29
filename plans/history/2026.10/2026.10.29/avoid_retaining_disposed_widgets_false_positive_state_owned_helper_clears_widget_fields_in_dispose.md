# BUG: `avoid_retaining_disposed_widgets` — flags `Widget` fields of a helper that its owning `State` creates, disposes, and that nulls those fields in `dispose()`

**Status: Open**

Created: 2026-10-29
Rule: `avoid_retaining_disposed_widgets`
File: `lib/src/rules/resources/memory_management_rules.dart` (class 1753, code 1773, `runWithReporter` ~1816-1855, `_isWidgetClass` 1878)
Severity: False positive
Rule version: v2 | Since: see rule dartdoc | Updated: 17.0.1-beta.2

Related (different shapes, open): `bugs/avoid_retaining_disposed_widgets_false_positive_const_row_descriptor_with_widget_fields.md`, `..._flow_delegate_context_field.md`, `..._widget_subclass_via_flutter_base.md`.

---

## Summary

`InFocusCardExit` is a plain class that a `State` owns (`late final ... = InFocusCardExit(vsync: this)`) and disposes in its own `dispose()`. It remembers the last built card list and one "ghost" card so the card that just left can fade out in place for ~300 ms. It must hold the real `Widget` to paint the ghost. Its `dispose()` sets both fields to `null`. The helper is created and destroyed with the `State`, so nothing outlives the widget lifecycle. The rule still reports both fields.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_retaining_disposed_widgets'" lib/src/rules/
# lib/src/rules/resources/memory_management_rules.dart:1773:    'avoid_retaining_disposed_widgets',
```

**Emitter registration:** `lib/src/rules/resources/memory_management_rules.dart:1773`; list entry `lib/saropa_lints.dart:2573`
**Rule class:** `AvoidRetainingDisposedWidgetsRule` (`memory_management_rules.dart:1753`)
**Diagnostic `source` / `owner` as seen in Problems panel:** `source: saropa_lints`, `owner: saropaLintsLsp`

---

## Reproducer

Needs the Flutter SDK (`package:flutter`). Real code: `lib/components/home/section/in_focus_card_exit.dart` lines 68-69 (fields), 106-118 (`track`), 228-235 (`dispose`); owner `lib/components/home/section/home_section_in_focus_scroller.dart` lines 93 and 737.

```dart
import 'package:flutter/widgets.dart';

class CardExit {
  CardExit({required TickerProvider vsync}) : controller = AnimationController(vsync: vsync);

  final AnimationController controller;

  List<Widget>? _lastCards; // LINT — should NOT lint (cleared in dispose)
  Widget? _ghost; // LINT — should NOT lint (cleared in dispose)

  Widget? get ghost => _ghost;

  void track(List<Widget> cards) {
    final List<Widget>? last = _lastCards;
    _lastCards = cards;
    if (last != null && last.length > cards.length) {
      _ghost = last.first;
    }
  }

  void dispose() {
    _ghost = null;
    _lastCards = null;
    controller.dispose();
  }
}

class Scroller extends StatefulWidget {
  const Scroller({super.key});

  @override
  State<Scroller> createState() => _ScrollerState();
}

class _ScrollerState extends State<Scroller> with SingleTickerProviderStateMixin {
  late final CardExit _exit = CardExit(vsync: this);

  @override
  void dispose() {
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _exit.track(const <Widget>[Text('a')]);
    return _exit.ghost ?? const SizedBox();
  }
}
```

**Frequency:** Always for a non-widget class with a `Widget` / `List<Widget>` field.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: the helper's lifetime equals its owner `State`, and `dispose()` releases the references |
| **Actual** | `[avoid_retaining_disposed_widgets] Non-widget class stores a reference to a Widget or State object. ...` at `68:3-68:28` (`List<Widget>? _lastCards;`) and `69:3-69:18` (`Widget? _ghost;`) |

---

## AST Context

```
CompilationUnit
  └─ ClassDeclaration (InFocusCardExit)           ← no extends clause, so _isWidgetClass is false
      ├─ FieldDeclaration (List<Widget>? _lastCards)  ← node reported here (reporter.atNode(member), line 1837)
      ├─ FieldDeclaration (Widget? _ghost)            ← node reported here
      └─ MethodDeclaration (dispose)
          └─ Block: _ghost = null; _lastCards = null;
```

---

## Root Cause

`runWithReporter` (`memory_management_rules.dart` ~1816):

1. `_isWidgetClass(node)` (line 1878) returns false because the class has no `extends` clause naming a widget base.
2. Each `FieldDeclaration` is visited. `type.type` resolves; `_isWidgetRelatedType` (line 1862) unwraps `List<Widget>` and accepts `Widget` from the Flutter SDK.
3. `reporter.atNode(member)` (line 1837) fires. Nothing checks whether the class has a `dispose()` that clears the field, or whether the class is owned by a `State`.

The rule assumes any non-widget holder leaks. A holder whose own `dispose()` nulls the field does not.

---

## Why the code is correct

- The only owner is `_cardExit` in `HomeSectionInFocusScroller`'s `State`; it is `late final` and disposed at `home_section_in_focus_scroller.dart:737`.
- `InFocusCardExit.dispose()` (`in_focus_card_exit.dart:228-235`) sets `_ghost = null` and `_lastCards = null`.
- The ghost needs the real `Widget`. A key list alone cannot paint the leaving card.

---

## Affected project locations

- `lib/components/home/section/in_focus_card_exit.dart:68` (`_lastCards`)
- `lib/components/home/section/in_focus_card_exit.dart:69` (`_ghost`)

---

## Suggested Fix

Skip a field when the enclosing class declares a method named `dispose` (or `close` / `cancel`) whose body assigns `null` (or `clear()`s) that field. Optionally also skip when the class is instantiated only from a `State` field initializer in the same library.

---

## Fixture Gap

`example*/lib/resources/avoid_retaining_disposed_widgets_fixture.dart` should include:

1. Class with `Widget? _ghost;` and `void dispose() { _ghost = null; }` — expect NO lint.
2. Same class without the `_ghost = null` assignment — expect LINT.
3. Class with `List<Widget>? _cards;` and `dispose() { _cards = null; }` — expect NO lint.
4. Class with `static Widget? shared;` and no clearing — expect LINT.

---

## Environment

- saropa_lints version: 17.0.1-beta.2 (installed in `~/.pub-cache`; the rule logic at these lines matches the repo source)
- Dart SDK version: Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- Triggering project: Saropa contacts app (`/Users/craighathaway/Documents/src/contacts`)

## Status 2026-10-29

Fixed in 17.0.1-beta.4 (see CHANGELOG).
