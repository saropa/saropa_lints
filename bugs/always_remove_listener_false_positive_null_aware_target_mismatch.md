# BUG: `always_remove_listener` — false positive when add/remove targets differ only by null-aware operator (`!` vs `?`)

**Status: Open**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-10
Rule: `always_remove_listener`
File: `lib/src/rules/widget/widget_lifecycle_rules.dart` (line ~2302, matcher at ~2383, finders at ~2404 / ~2422)
Severity: False positive / High (forces `// ignore:` on a correct dispose that DOES remove the listener)
Rule version: v3 | Since: unknown | Updated: 13.12.3 (current source)

---

## Summary

The rule pairs an `addListener(cb)` in `initState` with a `removeListener(cb)` in `dispose` by comparing the **source text** of each call's receiver (`node.realTarget?.toSource()`). When the add and remove sites reach the same listenable through different null-aware operators — `widget.destRectNotifier!.addListener(...)` vs `widget.destRectNotifier?.removeListener(...)` — the two source strings (`widget.destRectNotifier!` and `widget.destRectNotifier?`) are not equal, so the matcher finds no corresponding remove and reports a leak that does not exist.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'always_remove_listener'" lib/src/rules/
# lib/src/rules/widget/widget_lifecycle_rules.dart:2322:    'always_remove_listener',

# Negative — NOT in the sibling drift-advisor repo (source/owner label was ambiguous)
grep -rn "always_remove_listener" ../saropa_drift_advisor/lib/
# 0 matches
```

**Emitter registration:** `lib/src/rules/widget/widget_lifecycle_rules.dart:2322` (`AlwaysRemoveListenerRule`)
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` / `_generated_diagnostic_collection_name_#5`

---

## Reproducer

```dart
import 'package:flutter/material.dart';

class Example extends StatefulWidget {
  const Example({required this.notifier, super.key});
  final ValueNotifier<int>? notifier;
  @override
  State<Example> createState() => _ExampleState();
}

class _ExampleState extends State<Example> {
  VoidCallback? _listener;

  @override
  void initState() {
    super.initState();
    _listener = () {};
    // Receiver source text: "widget.notifier!"
    widget.notifier!.addListener(_listener!); // LINT — but listener IS removed below
  }

  @override
  void dispose() {
    // Receiver source text: "widget.notifier?" — differs from "widget.notifier!"
    widget.notifier?.removeListener(_listener!);
    super.dispose();
  }
}
```

**Frequency:** Always, whenever the `addListener` receiver and the `removeListener` receiver are spelled with a different null-aware operator (`!` add / `?` remove is the common, idiomatic pairing — you assert non-null when you know it is set in `initState`, and null-guard in `dispose` because the field may be gone).

Real-world site: `d:/src/contacts/lib/utils/system/shared_avatar_overlay.dart`
- add (initState, line 82): `widget.destRectNotifier!.addListener(_notifierListener!);`
- remove (dispose, line 142): `widget.destRectNotifier?.removeListener(_notifierListener!);`

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the listener added in `initState` IS removed in `dispose` (and additionally in the listener body and `didUpdateWidget`). |
| **Actual** | `[always_remove_listener] Listener added via addListener() but no matching removeListener() call found in dispose().` reported on the `addListener` call. |

---

## AST Context

```
ClassDeclaration (_ExampleState)
  ├─ MethodDeclaration (initState)
  │   └─ ... MethodInvocation (addListener)
  │           └─ realTarget: PrefixedIdentifier/PropertyAccess with PostfixExpression `!`
  │              toSource() => "widget.notifier!"          ← _ListenerInfo.target (add)
  └─ MethodDeclaration (dispose)
      └─ ... MethodInvocation (removeListener)
              └─ realTarget: ... with null-aware `?`
                 toSource() => "widget.notifier?"          ← _ListenerInfo.target (remove)
```

`added.target ("widget.notifier!") != removed.target ("widget.notifier?")` → `hasRemove == false` → report.

---

## Root Cause

`_AddListenerFinder.visitMethodInvocation` and `_RemoveListenerFinder.visitMethodInvocation` both capture the receiver as raw source text:

```dart
final String target = node.realTarget?.toSource() ?? '';
```

The matcher (line ~2383) then requires exact string equality on `target` (and `callback`):

```dart
final bool hasRemove = removedListeners.any(
  (_ListenerInfo removed) =>
      removed.target == added.target &&
      removed.callback == added.callback,
);
```

`toSource()` preserves the trailing `!` (PostfixExpression / null-assertion) on the add receiver and the `?` (null-aware) on the remove receiver. Those are different tokens, so two expressions that refer to the *same listenable object* compare unequal. The comparison is over syntactic spelling, not the resolved element the receiver points at.

This is the "Checking `node.name` instead of resolved element" pitfall from the guide: the matcher should compare the underlying element/normalized receiver, not the verbatim source including null-aware sugar.

### Hypothesis A (confirmed): null-aware operator difference defeats string equality

`widget.destRectNotifier!` and `widget.destRectNotifier?` are the same access through different null-handling. Normalizing both (strip a trailing `!`/`?` on the receiver, or compare `realTarget`'s resolved element / static element + property name) would match them.

---

## Suggested Fix

In `_ListenerInfo` construction, normalize the receiver source before comparison, or compare the resolved binding instead of the raw text. Minimal, low-risk normalization in both finders:

```dart
// Strip trailing null-aware/null-assertion sugar so the SAME listenable
// reached via `x!` (add) and `x?` (remove) compares equal. Without this,
// the idiomatic `field!.addListener` / `field?.removeListener` pairing
// is read as an unremoved listener (false positive).
String _normalizeReceiver(Expression? target) {
  final String raw = target?.toSource() ?? '';
  // Remove a single trailing '!' (PostfixExpression) — the '?' of a
  // null-aware method call is on the invocation, not in realTarget's
  // toSource for most shapes, but normalize defensively for both.
  return raw.endsWith('!') || raw.endsWith('?')
      ? raw.substring(0, raw.length - 1)
      : raw;
}
```

Stronger fix: resolve `realTarget` to its `staticElement` (for a field/property access) and key the match on that element plus the callback's resolved element, rather than on source text — this also fixes renamed-import and `this.field` vs `field` mismatches. Keep the source-text path as a fallback when the element cannot be resolved.

---

## Fixture Gap

The fixture at `example*/lib/widget/always_remove_listener_fixture.dart` should include:

1. **add via `field!.addListener`, remove via `field?.removeListener`** — expect NO lint (same listenable, different null-aware operator).
2. **add via `this.field.addListener`, remove via `field.removeListener`** — expect NO lint (same field, `this.` prefix difference).
3. **add via `field.addListener(cb)`, NO remove anywhere in dispose** — expect LINT (genuine leak, regression guard).
4. **add via `a.addListener(cb)`, remove via `b.removeListener(cb)` (different objects)** — expect LINT (genuinely different targets must still flag).

---

## Changes Made

<!-- Fill in when a fix is written. -->

---

## Tests Added

<!-- Fill in when a fix is written. -->

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: plugin pinned `13.12.1` in the triggering project's `analysis_options.yaml`; resolved `13.12.2` in `pubspec.lock`. Current source under investigation: `13.12.3`. The matcher logic is unchanged across these versions, so the FP reproduces on all three.
- Dart SDK version: `>=3.10.7 <4.0.0` (project constraint)
- analyzer version: `12.1.0`
- custom_lint version: n/a — saropa_lints is a native analysis_server plugin (top-level `plugins:` block)
- Triggering project/file: `d:/src/contacts/lib/utils/system/shared_avatar_overlay.dart:82`
