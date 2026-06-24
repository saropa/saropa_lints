# FEATURE: `prefer_static_final_for_session_constant` — hoist session-constant arithmetic out of `build()`

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->


Created: 2026-06-23
Rule: `prefer_static_final_for_session_constant` (NEW — does not exist yet)
File: proposed `lib/src/rules/core/compound_performance_rules.dart` (new rule)
Severity: Performance (lint, not a bug in an existing rule)
Rule version: n/a (feature request)

---

## Summary

A Flutter `build()` (or any method reached from it) frequently computes a value
whose operands are **all session-constant** — numeric literals plus
design-token getters like `ThemeCommonSpace.Footer.size` (a device-scaled map
lookup that is fixed for the whole app session) plus `static const` fields. The
result never changes across rebuilds, yet it is recomputed on every frame.

The rule should flag such an expression and offer to hoist it to a
`static final` field on the State/Widget class (computed once, lazily, on first
access).

**Why not `const`?** `ThemeCommonSpace.X.size` is a runtime getter (it reads a
`static final` cache keyed off `DeviceDisplay.category`, resolved at startup), so
the expression is not a compile-time constant — `static final` is the strongest
form available. This is the exact distinction the rule must teach, because
authors reach for `const`, get a compile error, and then leave the value inline
in `build()` instead of hoisting to `static final`.

Seed case that motivated this (downstream app `saropa/contacts`):

```dart
// lib/components/home/home_section_list.dart
class _HomeSectionListState extends State<HomeSectionList> {
  // The fix this rule should produce: hoisted, computed once.
  static final double _bottomClearance = ThemeCommonSpace.Footer.size * 2;
  ...
  Widget build(BuildContext context) {
    ...
    return Padding(
      padding: EdgeInsetsDirectional.only(bottom: _bottomClearance), // was: ThemeCommonSpace.Footer.size * 2 inline
    );
  }
}
```

---

## Attribution Evidence

This is a **feature request for a NEW rule**, so the positive grep is expected to
be empty by design (the rule does not exist yet). Confirming it is unclaimed:

```bash
# Rule does NOT yet exist anywhere in saropa_lints
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
`lib/src/rules/core/compound_performance_rules.dart`
(`avoid_opacity_in_animated_builder`, `avoid_clip_path_in_animated_builder`).
None of these cover plain session-constant arithmetic recomputed per build.

---

## Reproducer

Minimal cases marking where the rule should and should not fire.

```dart
class _Body extends State<Body> {
  static const double _kCard = 198; // static const field — session-constant

  @override
  Widget build(BuildContext context) {
    // LINT — all operands session-constant (token getter + literal),
    // no context/widget/param/local dependency. Hoist to `static final`.
    final double pad = ThemeCommonSpace.Footer.size * 2;

    // LINT — token getter + static const field; still fully session-constant.
    final double h = _kCard + ThemeCommonSpace.Medium.size * 2;

    // LINT — two token getters combined; same value the design system
    // resolves once per session.
    final double box = ThemeCommonSize.Small.size + ThemeCommonSpace.Small.size;

    // OK — depends on `context` (MediaQuery), changes with viewport. Must NOT
    // be hoisted to a static field.
    final double safe = MediaQuery.viewPaddingOf(context).bottom + 20;

    // OK — depends on a method parameter / local, not session-constant.
    final double scaled = widget.sizeCommon.size * 1.4;

    // OK — single bare token getter, no arithmetic. Trivial; hoisting adds
    // a field for no measurable gain (see scoping below — rule should skip).
    final double m = ThemeCommonSpace.Medium.size;

    return SizedBox(height: h + box + pad);
  }
}
```

**Frequency:** Always, for the LINT cases — they recompute every rebuild.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected (today)** | No rule exists; session-constant arithmetic sits inline in `build()` and recomputes every frame. Authors who try `const` hit a compile error (token getter is not const) and leave it inline. |
| **Desired** | `[prefer_static_final_for_session_constant] This expression only uses session-constant values; hoist it to a `static final` field so it is computed once, not on every rebuild.` reported on the expression, with a quick fix that extracts a `static final`. |

---

## Detection logic (proposed)

Fire when ALL of the following hold for an expression node:

1. **Location** — the expression is lexically inside a `build()` method, or a
   method/closure transitively invoked from `build()` (conservatively: any
   instance method of a `State` / `StatelessWidget` subclass, and any
   `*Builder` closure). Exclude `initState`, `didChangeDependencies`, field
   initializers, and `static`/top-level contexts (already computed once).
2. **Compound** — the expression is a `BinaryExpression` (or nested binary)
   with **at least one operator** combining ≥2 operands. A single bare getter
   (`ThemeCommonSpace.Medium.size`) does NOT fire — the gain is immeasurable and
   the noise is large (hundreds of inline `.size` paddings exist downstream).
3. **All operands session-constant** — every leaf is one of:
   - a numeric literal (`IntegerLiteral` / `DoubleLiteral`);
   - a `static const` field reference (resolved element `isStatic && isConst`);
   - a **session-constant token getter**: a `PropertyAccess` whose target is an
     enum value of a configured allowlist of token enums (`ThemeCommonSpace`,
     `ThemeCommonSize`, `ThemeCommonFontSize`, `ThemeCommonElevation`, …) and
     whose getter name is in a configured allowlist (`size`). The allowlist is
     config-driven so the rule is not hardcoded to one app's token classes;
   - a top-level `const` such as `kBottomNavigationBarHeight`.
4. **No volatile dependency** — the expression references NONE of: `context`,
   `widget.*`, instance (non-static-const) fields, method parameters, or local
   variables. Any one of these means the value can change between rebuilds and
   the expression must stay inline.

The quick fix extracts the expression to a `static final <T> _name = <expr>;` on
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

The walk must classify each leaf of the `BinaryExpression` operand tree
(rule fires only if EVERY leaf is session-constant per criterion 3).

---

## Risks / scoping (read before implementing)

This rule is **high-noise if scoped loosely**. The motivating app has hundreds
of inline `ThemeCommonSpace.X.size + <literal>` paddings; flagging all of them
would bury the genuinely useful cases and force mass `// ignore:`. Bounding
levers, in priority order:

1. **Require a compound expression (criterion 2).** Skip bare single getters.
   This alone removes the bulk of the noise.
2. **Optionally require non-trivial cost OR reuse.** Strongest signal: the same
   session-constant expression appears ≥2 times in one class (a real
   DRY + perf win — observed downstream at
   `contact_focus_mode_dialog.dart:347` and `:366`, identical
   `ThemeCommonSize.Small.size + ThemeCommonSpace.Small.size` computed twice).
   Consider shipping the duplicate-detection variant first as the
   high-confidence tier, and the single-use variant as an opt-in/`info` tier.
3. **Per-getter map lookup is cheap.** Be honest in the rule's docs: the win per
   site is small (a map lookup), so default severity should be `info`, not
   `warning`. The value is cumulative + teaches the `static final` (not `const`)
   idiom, not a hot-path emergency.

If tiers 2/3 can't be made low-noise, ship ONLY the duplicate-expression variant
— it is unambiguously worth hoisting and easy to defend.

---

## Fixture Gap

A new fixture (e.g. `example*/lib/core/prefer_static_final_for_session_constant_fixture.dart`)
should cover:

1. Token-getter × literal in `build()` — expect LINT.
2. `static const` field + token getter in `build()` — expect LINT.
3. Two token getters combined — expect LINT.
4. Same session-constant expression used twice in one class — expect LINT
   (duplicate-detection tier), and the quick fix produces ONE shared field.
5. Expression using `MediaQuery.of(context)` / `MediaQuery.sizeOf` — expect NO lint.
6. Expression using `widget.foo` — expect NO lint.
7. Expression using a method parameter (`sizeCommon.size * 1.4`) — expect NO lint.
8. Bare single getter, no arithmetic — expect NO lint (criterion 2).
9. Expression already in a `static`/top-level initializer — expect NO lint.
10. Expression in `initState` / `didChangeDependencies` — expect NO lint.

---

## Downstream candidate sites (saropa/contacts — seed evidence, NOT exhaustive)

Confirmed fully-session-constant compound expressions recomputed in widget build
paths (the rule's true positives). Each verified to use only token getters +
literals + `static const`, with no `context`/`widget`/param/local operands:

| File:line | Expression | Note |
|---|---|---|
| `lib/components/contact_focus/contact_focus_mode_dialog.dart:347` & `:366` | `ThemeCommonSize.Small.size + ThemeCommonSpace.Small.size` | **Same value computed twice** — strongest tier-2 case |
| `lib/views/home/map_tab.dart:123` | `kBottomNavigationBarHeight + ThemeCommonSpace.Medium.size` | top-level const + token getter |
| `lib/components/home/section/home_section_in_focus.dart:1510` | `_kCardBodyHeight + ThemeCommonSpace.Medium.size * 2` | `static const` + token getter |
| `lib/components/contact/avatar/avatar_sheet_style_section.dart:100` | `ThemeCommonSize.Large.size + ThemeCommonSpace.Large.size` | two token getters |
| `lib/views/contact/contact_avatar_crop_screen.dart:327` | `ThemeCommonSize.Huge.size * 2` | getter × literal |
| `lib/components/timeline/timeline_stats_header.dart:238` & `:247` | `ThemeCommonSize.Huge.size * 3` / `* 2` | getter × literal |
| `lib/components/user/achievements/user_achievement_section.dart:321` | `ThemeCommonFontSize.Largest.size * 1.5` | getter × literal |
| `lib/components/home/components/language_picker_dialog.dart:181` | `ThemeCommonSpace.Larger.size + ThemeCommonSpace.Small.size` | two token getters |

Explicitly **excluded** as true negatives (must NOT fire) — verified to depend on
volatile inputs:

| File:line | Why excluded |
|---|---|
| `lib/views/home/timeline_tab.dart:480`, `event_tab.dart:319` | `MediaQuery.viewPaddingOf(context).bottom + …` — context-dependent |
| `lib/components/device_home_screen_widget/quick_launch_bar.dart:282` | `avatarSize.size + … + textHeight` — param + local |
| `lib/components/contact/contact_status_list.dart:1680` | depends on `avatarPx` local |
| `lib/components/home/section/home_section_in_focus.dart:1620` | `constraints.maxWidth - …` — LayoutBuilder local |
| the many `iconSize.size / 3`, `sizeCommon.size * 1.4` sites | `iconSize`/`sizeCommon` are method parameters |

---

## Environment

- saropa_lints version: (current main as of 2026-06-23)
- Triggering project: `saropa/contacts` (d:\src\contacts)
- Motivating commit/site: `lib/components/home/home_section_list.dart` —
  `_bottomClearance` hoist (2026-06-23)

---

## Finish Report (2026-06-23)

The `prefer_static_final_for_session_constant` rule was implemented as
`PreferStaticFinalForSessionConstantRule` in
`lib/src/rules/core/compound_performance_rules.dart`, alongside the existing
context-aware performance rules. It reports an `info` diagnostic when a compound
arithmetic expression inside a non-static `build()` method is built entirely from
session-constant operands and is therefore recomputed on every rebuild.

### Detection

Registered on `BinaryExpression`. A node is reported when all of the following
hold:

1. It is the outermost arithmetic node (parent, ignoring parentheses, is not a
   `BinaryExpression`) — prevents double-reporting nested sub-expressions.
2. The nearest enclosing `MethodDeclaration` is a non-static `build`. Closures
   nested in `build` (LayoutBuilder / itemBuilder) resolve to that same method;
   field initializers, `initState`, `didChangeDependencies`, and static / top
   level contexts are excluded because they already evaluate once.
3. Every leaf of the operand tree is session-constant: a numeric literal, a
   design-token getter (`Enum.Value.size` where the enum is in the built-in
   `_tokenEnumTypes` allowlist), or a constant referenced by Dart/Flutter naming
   convention (`kName`, `_kName`, or `SCREAMING_SNAKE_CASE`).
4. At least one leaf is a non-trivial constant (token getter or named constant),
   so a literal-only expression such as `2 * 2` — already const-folded — does not
   qualify.

The "no volatile dependency" requirement is the contrapositive of (3): any
reference to `context`, `widget.*`, an instance field, a parameter, or a local
fails leaf classification, so the whole expression is rejected.

### Design decisions

- **Severity is `info`, tier is Professional.** The per-site win is a single map
  lookup; the value is cumulative and pedagogical (teaching `static final`, not
  `const`, because token getters resolve at runtime). The compound-expression
  requirement (criterion 2) is the primary noise lever, so the single-use variant
  ships rather than the duplicate-only fallback the request floated.
- **Const detection is name-convention based, not element-based.** This keeps the
  rule resolution-independent so it behaves identically under the IDE's resolved
  tree and the unresolved `parseString` tree used by the scan and health CLIs
  (where element data is absent). The only miss is a volatile local that follows
  the k-prefix / all-caps convention, which is rare.
- **No quick fix.** A safe extract-to-`static final` needs field-name collision
  handling the unresolved scan tree cannot provide; an incorrect fix is worse
  than none, so detection ships alone (consistent with other fixless rules).
- **Token-enum allowlist is a built-in default set** (the named `ThemeCommon*`
  classes), not config-plumbed; adding rule-options infrastructure for one rule
  was out of proportion.

### Wiring

- Factory `PreferStaticFinalForSessionConstantRule.new` registered in
  `lib/saropa_lints.dart`.
- Rule code added to `professionalOnlyRules` in `lib/src/tiers.dart`.
- The generated rule-pack registry was regenerated
  (`dart run tool/generate_rule_pack_registry.dart`), adding the code to the
  derived `performance` theme pack in `lib/src/config/rule_pack_codes_generated.dart`
  and `extension/src/rulePacks/rulePackDefinitions.ts`. `tool/rule_pack_audit.dart`
  reports no drift.

### Verification

- Fixture `example/lib/performance/prefer_static_final_for_session_constant_fixture.dart`
  covers 6 LINT cases (token×literal, static const + getter, two getters, top
  level const + getter, duplicate expression twice) and the negative cases
  (`MediaQuery`, `widget.*`, parameter, bare single getter, static initializer,
  `initState`).
- Scan CLI against a copy of the fixture: the rule fires exactly 6 times on the
  LINT lines, with zero hits on any negative case.
- `dart test` for plugin registration, rule-pack registry parity, and the
  compound-performance instantiation/fixture pins all pass.
