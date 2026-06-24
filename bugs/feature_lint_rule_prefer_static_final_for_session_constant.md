# FEATURE: `prefer_static_final_for_session_constant` — hoist session-constant arithmetic out of `build()`

**Status: Open**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-23
Rule: `prefer_static_final_for_session_constant` (NEW — does not exist yet)
File: proposed `lib/src/rules/core/compound_performance_rules.dart` (new rule)
Severity: Performance (lint, not a bug in an existing rule)
Rule version: n/a (feature request)

---

## Summary

A Flutter `build()` (or any method reached from it) frequently computes a value
whose operands are **all session-constant** — numeric literals plus a *narrow,
verified subset* of design-token getters (e.g. `ThemeCommonSpace.Footer.size`, a
device-scaled map lookup fixed for the whole app session) plus `static const`
fields. The result never changes across rebuilds, yet it is recomputed on every
frame. The rule should flag such an expression and offer to hoist it to a
`static final` field (computed once, lazily, on first access).

**Why not `const`?** `ThemeCommonSpace.X.size` is a runtime getter (it reads a
`static final` cache keyed off `DeviceDisplay.category`, resolved at startup), so
the expression is not a compile-time constant — `static final` is the strongest
form available. This is the exact distinction the rule must teach: authors reach
for `const`, hit a compile error, then leave the value inline in `build()`
instead of hoisting to `static final`.

Seed case that motivated this (downstream app `saropa/contacts`):

```dart
// lib/components/home/home_section_list.dart
class _HomeSectionListState extends State<HomeSectionList> {
  static final double _bottomClearance = ThemeCommonSpace.Footer.size * 2; // hoisted
  ...
  Widget build(BuildContext context) =>
      Padding(padding: EdgeInsetsDirectional.only(bottom: _bottomClearance), ...);
}
```

---

## ⚠️ CRITICAL CAVEAT — not every `ThemeCommon*.size` is session-constant

This is the single most important constraint, learned the hard way while
applying the fix downstream. **Only token getters whose resolved value depends
solely on immutable device facts may be hoisted.** A token that folds in a
runtime-mutable input (a user preference, the system text scale) MUST NOT be
hoisted — freezing it in a `static final` would show a stale value after the user
changes that setting, which is a real regression.

In the motivating app (`saropa/contacts`):

| Token getter | Session-constant? | Backing source |
|---|---|---|
| `ThemeCommonSpace.size` | **YES — safe** | `static final` cache (`_cachedSizesMobile`/`_scaleMultiplier`) keyed off `DeviceDisplay.category` only; no `forced` recompute path, no user-pref, no `MediaQuery` |
| `ThemeCommonSize.size` | **NO — unsafe** | reads `UserPreferenceType.ScaleFactorAvatar`; recomputed by `initThemeCommonSize(forced: true)` when the user changes the avatar scale |
| `ThemeCommonFontSize.size` | **NO — unsafe** | reads `MediaQuery.textScalerOf(context)`; recomputed by `initFontSizes(context)` on system-font-scale change |
| `ThemeCommonElevation.size`, others | **UNKNOWN — verify first** | must be checked per token before allowlisting |

**Allowlist policy for the rule:** the set of hoistable token enums is
**opt-in per token via config**, NOT "any `ThemeCommon*`". The rule author adds a
token only after verifying its getter has no user-pref / `MediaQuery` /
text-scale input. Safe heuristic: a token qualifies only if its backing cache is
itself a `static final` with **no `forced`-recompute entry point**. When in
doubt, exclude — a missed hoist is harmless; a wrong hoist is a stale-UI bug.

---

## Attribution Evidence

This is a **feature request for a NEW rule**, so the positive grep is expected to
be empty by design (the rule does not exist yet). Confirming it is unclaimed:

```bash
grep -rn "'prefer_static_final_for_session_constant'" lib/src/rules/
# Expected: 0 matches (this is a feature request)
```

Precedent — saropa_lints already ships build-phase performance rules this would
sit beside:

```bash
grep -rnoE "'avoid_(stream|future|async)_in_build'" lib/src/rules/core/async_rules.dart
# avoid_stream_in_build, avoid_future_in_build, avoid_async_in_build
```

Closest existing neighbors (review for overlap before implementing): the
`avoid_*_in_build` family in `lib/src/rules/core/async_rules.dart`, and the
animated-builder cost rules in
`lib/src/rules/core/compound_performance_rules.dart`. None cover plain
session-constant arithmetic recomputed per build.

---

## Reproducer

```dart
class _Body extends State<Body> {
  static const double _kCard = 198; // static const field — session-constant

  @override
  Widget build(BuildContext context) {
    // LINT — operands all session-constant (allowlisted token getter + literal),
    // no context/widget/param/local dependency. Hoist to `static final`.
    final double pad = ThemeCommonSpace.Footer.size * 2;

    // LINT — allowlisted token getter + static const field.
    final double h = _kCard + ThemeCommonSpace.Medium.size * 2;

    // OK — `ThemeCommonSize.size` is NOT allowlisted (folds the avatar-scale
    // user pref); hoisting would freeze it. MUST NOT lint.
    final double box = ThemeCommonSize.Small.size + ThemeCommonSpace.Small.size;

    // OK — `ThemeCommonFontSize.size` folds system text scale. MUST NOT lint.
    final double font = ThemeCommonFontSize.Largest.size * 1.5;

    // OK — depends on `context` (MediaQuery), changes with viewport.
    final double safe = MediaQuery.viewPaddingOf(context).bottom + 20;

    // OK — depends on a method parameter / local.
    final double scaled = widget.sizeCommon.size * 1.4;

    // OK — single bare getter, no arithmetic. Trivial; rule skips (criterion 2).
    final double m = ThemeCommonSpace.Medium.size;

    return SizedBox(height: h + pad);
  }
}
```

**Frequency:** Always, for the LINT cases — they recompute every rebuild.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected (today)** | No rule exists; session-constant arithmetic sits inline in `build()` and recomputes every frame. Authors who try `const` hit a compile error and leave it inline. |
| **Desired** | `[prefer_static_final_for_session_constant] This expression only uses session-constant values; hoist it to a `static final` field so it is computed once, not on every rebuild.` reported on the expression, with a quick fix that extracts a `static final`. |

---

## Detection logic (proposed)

Fire when ALL of the following hold for an expression node:

1. **Location** — lexically inside a `build()` method, or a method/closure
   transitively invoked from `build()` (conservatively: any instance method of a
   `State` / `StatelessWidget` subclass, and any `*Builder` closure). Exclude
   `initState`, `didChangeDependencies`, field initializers, and
   `static`/top-level contexts (already computed once).
2. **Compound** — a `BinaryExpression` (or nested binary) with **≥1 operator**
   combining ≥2 operands. A single bare getter does NOT fire (gain immeasurable,
   noise large — hundreds of inline `.size + literal` paddings exist downstream).
3. **All operands session-constant** — every leaf is one of:
   - a numeric literal (`IntegerLiteral` / `DoubleLiteral`);
   - a `static const` field reference (resolved element `isStatic && isConst`);
   - an **allowlisted** session-constant token getter (see the CRITICAL CAVEAT
     above — allowlist is opt-in per token, verified free of user-pref /
     `MediaQuery` / text-scale input; in `saropa/contacts` only
     `ThemeCommonSpace.size` qualifies);
   - a top-level `const` such as `kBottomNavigationBarHeight`.
4. **No volatile dependency** — references NONE of: `context`, `widget.*`,
   instance (non-static-const) fields, method parameters, local variables. Any
   one means the value can change between rebuilds and must stay inline.

The quick fix extracts the expression to `static final <T> _name = <expr>;` on
the enclosing class and replaces the use site with `_name`.

---

## AST Context

```
ClassDeclaration (_Body, extends State<Body>)
  └─ MethodDeclaration (build)
      └─ Block
          └─ VariableDeclarationStatement
              └─ VariableDeclaration (pad)
                  └─ BinaryExpression (*)              ← node reported here
                      ├─ PropertyAccess (.size)
                      │    └─ PrefixedIdentifier (ThemeCommonSpace.Footer)
                      └─ IntegerLiteral (2)
```

The walk must classify each leaf of the operand tree; the rule fires only if
EVERY leaf is session-constant per criterion 3 (with the allowlist gate).

---

## Risks / scoping (read before implementing)

High-noise if scoped loosely. The motivating app has hundreds of inline
`ThemeCommon*.size + <literal>` paddings; flagging all would bury the useful
cases and force mass `// ignore:`. Bounding levers, in priority order:

1. **Require a compound expression (criterion 2).** Removes the bulk of noise.
2. **Token allowlist (the CRITICAL CAVEAT).** This is BOTH a correctness gate and
   a noise gate — restricting to `ThemeCommonSpace`-only already excludes the
   majority of `.size` sites (most are `ThemeCommonSize`/`ThemeCommonFontSize`).
3. **Optionally require non-trivial cost OR reuse.** Strongest signal: the same
   session-constant expression appears ≥2 times in one class (a DRY + perf win).
   Consider shipping the duplicate-detection variant first as the high-confidence
   tier and the single-use variant as opt-in / `info`.
4. **Per-getter map lookup is cheap.** Be honest in the rule docs: the win per
   site is small. Default severity `info`, not `warning`. The value is cumulative
   plus teaching the `static final` (not `const`) idiom — not a hot-path
   emergency.

If tiers 3/4 can't be made low-noise, ship ONLY the duplicate-expression variant.

---

## Fixture Gap

New fixture (e.g.
`example*/lib/core/prefer_static_final_for_session_constant_fixture.dart`) should
cover:

1. Allowlisted token getter × literal in `build()` — expect LINT.
2. `static const` field + allowlisted token getter — expect LINT.
3. **Non-allowlisted token (`ThemeCommonSize`/`ThemeCommonFontSize`) in the
   expression — expect NO lint** (the regression guard).
4. Same session-constant expression used twice in one class — expect LINT
   (duplicate tier); quick fix produces ONE shared field.
5. Expression using `MediaQuery.of(context)` / `MediaQuery.sizeOf` — NO lint.
6. Expression using `widget.foo` — NO lint.
7. Expression using a method parameter (`sizeCommon.size * 1.4`) — NO lint.
8. Bare single getter, no arithmetic — NO lint (criterion 2).
9. Expression already in a `static`/top-level initializer — NO lint.
10. Expression in `initState` / `didChangeDependencies` — NO lint.

---

## Downstream evidence (saropa/contacts) — applied + rejected

**Applied (3 sites, `ThemeCommonSpace`-only, hoisted to `static final` 2026-06-23):**

| File:line | Expression |
|---|---|
| `lib/views/home/map_tab.dart` | `kBottomNavigationBarHeight + ThemeCommonSpace.Medium.size` |
| `lib/components/home/section/home_section_in_focus.dart` | `_kCardBodyHeight + ThemeCommonSpace.Medium.size * 2` (`_kCardBodyHeight` static const) |
| `lib/components/home/components/language_picker_dialog.dart` | `ThemeCommonSpace.Larger.size + ThemeCommonSpace.Small.size` |
| `lib/components/home/home_section_list.dart` | `ThemeCommonSpace.Footer.size * 2` (the original seed) |

**Rejected (5 sites — would have been bugs; NOT hoisted) because the expression
folds a non-session-constant token:**

| File:line | Expression | Why rejected |
|---|---|---|
| `lib/components/contact_focus/contact_focus_mode_dialog.dart:347` & `:366` | `ThemeCommonSize.Small.size + ThemeCommonSpace.Small.size` | `ThemeCommonSize` folds avatar-scale pref |
| `lib/components/contact/avatar/avatar_sheet_style_section.dart:100` | `ThemeCommonSize.Large.size + ThemeCommonSpace.Large.size` | same |
| `lib/components/timeline/timeline_stats_header.dart:238` & `:247` | `ThemeCommonSize.Huge.size * 3` / `* 2` | same |
| `lib/views/contact/contact_avatar_crop_screen.dart:327` | `ThemeCommonSize.Huge.size * 2` | same |
| `lib/components/user/achievements/user_achievement_section.dart:321` | `ThemeCommonFontSize.Largest.size * 1.5` | `ThemeCommonFontSize` folds system text scale |

The rejected set is the proof that a naive "hoist any `ThemeCommon*.size` math"
rule would ship regressions. The token allowlist is mandatory, not optional.

---

## Environment

- saropa_lints version: (current main as of 2026-06-23)
- Triggering project: `saropa/contacts` (d:\src\contacts)
- Motivating site: `lib/components/home/home_section_list.dart` — `_bottomClearance` hoist (2026-06-23)
