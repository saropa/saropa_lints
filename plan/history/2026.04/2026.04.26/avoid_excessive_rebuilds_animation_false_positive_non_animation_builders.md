> **Archived** from `bugs/` on 2026-04-26. **Resolution:** `avoid_excessive_rebuilds_animation` v2 narrows to `AnimatedBuilder` / `ListenableBuilder` with an `Animation` subtype listenable; see [CHANGELOG.md](../../../../CHANGELOG.md) [Unreleased].

# `avoid_excessive_rebuilds_animation` — false positive: rule fires on `FutureBuilder`, `StreamBuilder`, `ValueListenableBuilder` which don't rebuild on animation frames

**Status:** Fixed (saropa_lints: `avoid_excessive_rebuilds_animation` v2 — animation-sourced builders only; see CHANGELOG [Unreleased])

Filed: 2026-04-26
Rule: `avoid_excessive_rebuilds_animation`
File: `lib/src/rules/ui/animation_rules.dart` (line 1765, code at 1781–1838)
Severity: False positive — **structural / classification error**
Rule version: v1 | Severity in code: WARNING | Impact: high

---

## Summary

The rule's stated purpose is to prevent expensive rebuilds in **animation** widgets — its docstring (lines 1740–1764) and message text both reference rebuilds happening "60 times per second" on every animation frame. The detection set, however, includes three widgets that do not rebuild on animation frames at all:

```dart
static const Set<String> _builderWidgets = <String>{
  'AnimatedBuilder',          // ← rebuilds on every Animation tick (≈ 60 Hz). True animation widget.
  'ListenableBuilder',        // ← rebuilds on Listenable notifications. May or may not be animation-driven.
  'ValueListenableBuilder',   // ← rebuilds on value change. Usually not 60Hz; one-shot or coarse-grained.
  'StreamBuilder',            // ← rebuilds on stream events. Typically network/DB; not 60Hz.
  'FutureBuilder',            // ← rebuilds at most 2–3 times total (waiting → done/error).
};
```

`FutureBuilder` rebuilds **at most twice** in its lifetime (waiting → data, or waiting → error). `StreamBuilder` rebuilds when stream events arrive, typically driven by network or database events at human time scales, not animation frames. `ValueListenableBuilder` rebuilds when its value changes — once per user action in the typical case.

Lumping them all under "animation widget" produces warnings whose message ("rebuilds … typically 60 times per second") is **factually wrong** for 4 of the 5 listed widgets. The user is told to extract static content from a `FutureBuilder` to avoid 60fps rebuild cost — but there is no 60fps rebuild happening. The fix the rule recommends is busywork.

---

## Attribution Evidence

```bash
$ grep -rn "'avoid_excessive_rebuilds_animation'" lib/src/rules/
lib/src/rules/ui/animation_rules.dart:1781:    'avoid_excessive_rebuilds_animation',
```

Rule lives here. Confirmed.

**Emitter registration:** `lib/src/rules/ui/animation_rules.dart:1765` (`AvoidExcessiveRebuildsAnimationRule`)
**Rule class:** `AvoidExcessiveRebuildsAnimationRule` — registered in `lib/src/rules/all_rules.dart`
**Diagnostic `source` / `owner`:** `dart` (saropa_lints native plugin)

---

## Reproducer

Consumer project: `D:\src\contacts`. Nine sites currently flagged. Sample of the three patterns:

### Pattern A — `FutureBuilder` flagged as animation (most common)

`lib/components/activity/recent_phone/activity_view_phone_dialer.dart:215`:

```dart
@override
Widget build(BuildContext context) {
  try {
    return FutureBuilder<(ContactModel?, Widget?)>( // LINT — but should NOT lint
      future: _displayInfoFuture,
      builder: (BuildContext context, AsyncSnapshot<(ContactModel?, Widget?)> snapshot) {
        // Future fires once per displayInfoFuture resolution. Not 60Hz.
        // Builder body has Avatar + Text + Padding + GestureDetector + … widgets.
        // The rule counts > 5 known widgets and reports.
        return Row(children: <Widget>[ /* > 5 widgets */ ]);
      },
    );
  } on Object catch (...) { ... }
}
```

### Pattern B — `ValueListenableBuilder` flagged as animation

`lib/components/main_layout/app_tabs/app_bottom_navigation_bar.dart:268`:

```dart
ValueListenableBuilder<RenderQuality>( // LINT — but should NOT lint
  valueListenable: AdaptiveQualityManager.instance.quality,
  builder: (BuildContext context, RenderQuality quality, Widget? _) {
    // RenderQuality changes when device load changes — minutes apart.
    // Not 60Hz. Not animation.
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: screenWidth),
      child: ClipRSuperellipse(
        borderRadius: const BorderRadius.only(...),
        child: Stack(children: <Widget>[ /* > 5 widgets */ ]),
      ),
    );
  },
);
```

### Pattern C — Same file, multiple `FutureBuilder` / `ValueListenableBuilder` sites compounding

`lib/components/map/calendar_event_location_map.dart:209` (FutureBuilder) and `:261` (ValueListenableBuilder driven by a `LatLng?` notifier from map gestures — fires per pan/zoom, ~10Hz peak, not animation).

Other affected sites: `lib/components/home/section/home_section_map.dart:203`, `lib/components/map/map_explorer_widget.dart:248,284`, `lib/components/map/single_contact_address_map.dart:174`, `lib/views/event/event_list_screen.dart:1298`, `lib/views/home/emergency_tab.dart:354,368`, `lib/views/home/social_wall_tab.dart:375`.

Of the nine flagged sites, **zero** are inside an `AnimatedBuilder` or `ListenableBuilder` driven by an `Animation<T>`. All are `FutureBuilder` (one-shot async UI) or `ValueListenableBuilder` (reactive UI to coarse-grained events).

**Frequency:** Always, on any of the five widget types when the builder body contains > 5 nodes from the rule's `_knownWidgets` set.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | Diagnostic limited to widgets whose builder is invoked at animation frame rate: `AnimatedBuilder`, and `ListenableBuilder` *only when the listenable is an `Animation<T>`*. `FutureBuilder` / `StreamBuilder` / non-animation `ValueListenableBuilder` should not be flagged because no per-frame rebuild occurs. |
| **Actual** | All five widget types treated identically. Builders with > 5 widget constructors emit `[avoid_excessive_rebuilds_animation]` claiming "rebuilds … 60 times per second" regardless of whether that is true. |

---

## AST Context

```
InstanceCreationExpression (FutureBuilder<…>)
  └─ ConstructorName ("FutureBuilder")           ← reported here
  └─ ArgumentList
      ├─ NamedExpression (future: _foo)
      └─ NamedExpression (builder: …)
          └─ FunctionExpression
              └─ FunctionBody
                  └─ … widget constructors counted via _WidgetCountVisitor
```

Detection at `runWithReporter` (lines 1812–1830):

```dart
context.addInstanceCreationExpression((InstanceCreationExpression node) {
  final String typeName = node.constructorName.type.name.lexeme;
  if (!_builderWidgets.contains(typeName)) return; // ← any of the 5 types passes

  for (final Expression arg in node.argumentList.arguments) {
    if (arg is! NamedExpression) continue;
    if (arg.name.label.name != 'builder') continue;
    final Expression builderExpr = arg.expression;
    if (builderExpr is! FunctionExpression) continue;
    final int count = _countWidgetsInBody(builderExpr.body);
    if (count > _widgetCountThreshold) {
      reporter.atNode(node.constructorName, code); // ← unconditional once threshold passed
    }
    return;
  }
});
```

There is no check on whether the widget is genuinely animation-driven. Type-name match alone gates the entire rule.

---

## Root Cause

### Hypothesis (high confidence): rule's set incorrectly conflates "builder-pattern widgets" with "animation widgets"

The Flutter framework distinguishes:

- **Animation builders** that rebuild on every animation tick: `AnimatedBuilder`, `ListenableBuilder` *with `Animation<T>` source*, `AnimatedSwitcher`, `AnimatedContainer` (sort of — has its own builder semantics).
- **Async/reactive builders** that rebuild on data events: `FutureBuilder`, `StreamBuilder`, `ValueListenableBuilder`, `ListenableBuilder` *with non-animation `Listenable`*.

The 60Hz rebuild cost the rule message warns about applies only to the first group. The second group has its own performance characteristics (they re-create their `widget.builder` closure every parent rebuild, causing some allocation overhead — a real concern but **not** a 60fps concern).

The rule's `_builderWidgets` set treats both groups as a single category. The rule's *message text* (lines 1782–1788) and *docstring* (lines 1740–1764) describe only the first group. Either the detection needs to narrow, or the rule needs to be split / renamed.

### A subtler issue: `ListenableBuilder` is genuinely ambiguous

`ListenableBuilder` accepts any `Listenable`. If fed an `Animation<T>` (which extends `Listenable`), it rebuilds at frame rate. If fed a `ValueNotifier<int>`, it rebuilds on `notifyListeners()` calls. The rule cannot tell statically without a type check on the `listenable:` argument. For pragmatism, leaving `ListenableBuilder` in the set is defensible; flagging `FutureBuilder` is not.

---

## Suggested Fix

Two-part fix; do both:

### Fix 1 — Narrow `_builderWidgets` to actual animation builders

```dart
static const Set<String> _builderWidgets = <String>{
  'AnimatedBuilder',
  'ListenableBuilder', // kept; animation-or-not is statically ambiguous, conservative.
};
```

Remove `FutureBuilder`, `StreamBuilder`, `ValueListenableBuilder`. They warrant their own rule (e.g. `avoid_large_async_builders`) with appropriate severity (low/INFO) and a different message that accurately describes the cost (allocation/closure churn, not 60fps rebuilds).

### Fix 2 — Optionally inspect `ListenableBuilder` source

When the rule sees `ListenableBuilder`, peek at the `listenable:` argument's static type. If it resolves to a subtype of `Animation`, fire. If it resolves to `ValueNotifier`, `ChangeNotifier`, or another non-Animation `Listenable`, do not fire (or fire with a separate, lower-severity rule). This requires `staticType` resolution, which the analyzer plugin supports.

If Fix 2 is too involved, Fix 1 alone restores correctness for the worst false positives.

### Optional Fix 3 — Update message text

If the rule keeps `ValueListenableBuilder` / `FutureBuilder` / `StreamBuilder` for consistency with current scope, the message must stop claiming "60 times per second" — those widgets do not rebuild that often. Replace with: *"This builder body contains many widget constructors. They are reconstructed on every rebuild and bypass `const` caching. Pass static subtrees through the `child:` parameter where possible."* That is an accurate (lower-severity) diagnostic.

---

## Fixture Gap

The fixture at `example*/lib/ui/avoid_excessive_rebuilds_animation_fixture.dart` should include:

1. **`AnimatedBuilder` driven by `AnimationController`, body has > 5 widgets** — expect LINT
2. **`ListenableBuilder(listenable: animationController, ...)` (Animation source), > 5 widgets** — expect LINT
3. **`ListenableBuilder(listenable: valueNotifier, ...)` (non-Animation), > 5 widgets** — expect NO lint *(currently false positive)*
4. **`FutureBuilder` body has > 5 widgets** — expect NO lint *(currently false positive)*
5. **`StreamBuilder` body has > 5 widgets** — expect NO lint *(currently false positive)*
6. **`ValueListenableBuilder<int>` body has > 5 widgets** — expect NO lint *(currently false positive)*
7. **`AnimatedBuilder` body has 5 or fewer widgets** — expect NO lint
8. **`AnimatedBuilder` using `child:` parameter for static subtree, body small** — expect NO lint (good pattern)

---

## Downstream

Tracked in `contacts/`. Once this report exists, nine sites get `// ignore: avoid_excessive_rebuilds_animation` with a comment pointing here. Sites:

- `lib/components/activity/recent_phone/activity_view_phone_dialer.dart:215` (FutureBuilder)
- `lib/components/home/section/home_section_map.dart:203` (FutureBuilder)
- `lib/components/main_layout/app_tabs/app_bottom_navigation_bar.dart:268` (ValueListenableBuilder)
- `lib/components/map/calendar_event_location_map.dart:209,261`
- `lib/components/map/map_explorer_widget.dart:248,284`
- `lib/components/map/single_contact_address_map.dart:174`
- `lib/views/event/event_list_screen.dart:1298`
- `lib/views/home/emergency_tab.dart:354,368`
- `lib/views/home/social_wall_tab.dart:375`

---

## Environment

- saropa_lints version: 12.4.0
- Dart SDK: 3.9.x
- Triggering project: `d:/src/contacts`
- Platform: Windows 11
