# BUG: `prefer_layout_builder_for_constraints` — false positive on legitimate window-extent `MediaQuery.sizeOf` use

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

> **Fix applied (2026-06-13)** in `lib/src/rules/widget/widget_layout_constraints_rules.dart`:
> - **Pattern A** — new `_isConstraintFinitenessFallback` early-return skips a
>   `MediaQuery` read that is the then/else branch of a conditional whose
>   condition tests `.isFinite`/`.isInfinite` on a constraint extent
>   (`maxWidth`/`maxHeight`/`minWidth`/`minHeight`), detected via
>   `_ConstraintFinitenessVisitor`.
> - **Pattern B** — `_isMediaQuerySizeDimensionInLiteralScaleOrBreakpoint`
>   renamed to `_isMediaQuerySizeDimensionScaledOrBreakpoint`; the `*`/`/` scale
>   case no longer requires a numeric-literal factor (named fractions like
>   `* fraction` are now exempt). Breakpoint comparisons still require a literal.
> - Fixtures added: `OkConstraintFinitenessFallback`, `OkViewportFractionVariable`.
>
> **Runtime verification PASSED (2026-06-14):** the build blocker is resolved
> (`navigation_rules.dart` now defines `_literalPathText` in scope; the package
> loads 2075 rules cleanly). Scanned the fixture via `dart run saropa_lints scan`
> at the comprehensive tier. `prefer_layout_builder_for_constraints` fires on
> exactly the 8 BAD `expect_lint` markers (fixture lines 18, 33, 35, 47, 60, 62,
> 112, 127) and on neither new GOOD case — line 284 (`OkConstraintFinitenessFallback`,
> the constraint-finiteness fallback) and line 304 (`OkViewportFractionVariable`,
> the named-factor viewport fraction) are both clean. No regression on the
> existing GOOD cases (screen fraction, breakpoint, viewInsets, static utilities,
> positional breakpoint helper).

Created: 2026-06-13
Rule: `prefer_layout_builder_for_constraints`
File: `lib/src/rules/widget/widget_layout_constraints_rules.dart` (line ~2569, `runWithReporter` ~2595)
Severity: False positive
Rule version: v? | Since: unknown | Updated: unknown

---

## Summary

The rule flags every `MediaQuery.sizeOf(context).width/.height` (and
`.of(context).size.width/.height`) used for sizing, exempting only positional
call arguments and literal scale/breakpoint use. It has **no exemption for the
two cases where `MediaQuery` is the correct tool and `LayoutBuilder` is not**:

- **Pattern A — fallback inside an existing `LayoutBuilder`.** The widget already
  measures `constraints.maxWidth`; `MediaQuery.sizeOf` is only the else-branch of
  a `constraints.<dim>.isFinite ? constraints.<dim> : MediaQuery…` ternary, used
  *only* when the parent gives unbounded constraints (where `LayoutBuilder`
  constraints are `Infinity` and unusable). Switching to LayoutBuilder is what
  the code already did; the flagged line is the mandatory fallback.
- **Pattern B — deliberate viewport-proportional sizing.** A height computed as
  `MediaQuery.sizeOf(context).height * fraction` inside a `SingleChildScrollView`
  (or any unbounded-main-axis parent), where the intent is "a fraction of the
  screen/window," not "a fraction of the parent box." `LayoutBuilder` there
  yields unbounded vertical constraints — the wrong signal. The rule's own
  dartdoc (lines ~2541-2550) acknowledges `MediaQuery.size` is "the screen or
  window extent … not interchangeable with `LayoutBuilder` constraints," yet the
  rule still flags this case.

Both force a `// ignore:` on correct, idiomatic responsive code.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'prefer_layout_builder_for_constraints'" lib/src/rules/
# lib/src/rules/widget/widget_layout_constraints_rules.dart:2588: 'prefer_layout_builder_for_constraints',

# Negative — NOT in the sibling drift-advisor repo
grep -rn "'prefer_layout_builder_for_constraints'" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# 0 matches
```

**Emitter registration:** `lib/src/rules/widget/widget_layout_constraints_rules.dart:2570` (`PreferLayoutBuilderForConstraintsRule()` constructor)
**Rule class:** `PreferLayoutBuilderForConstraintsRule`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` (`_generated_diagnostic_collection_name_#5`)

---

## Reproducer

```dart
// Pattern A — MediaQuery is the infinite-constraint fallback INSIDE a LayoutBuilder.
Widget buildA() {
  return LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      // OK — should NOT lint: LayoutBuilder IS used; MediaQuery is only the
      // fallback when the parent passes unbounded width (constraints == Infinity).
      final double maxWidth = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : MediaQuery.sizeOf(context).width; // LINT (false positive)
      return SizedBox(width: maxWidth);
    },
  );
}

// Pattern B — deliberate viewport-fraction height inside an unbounded scroller.
Widget buildB(BuildContext context, bool expanded) {
  return SingleChildScrollView(
    child: SizedBox(
      // OK — should NOT lint: a fraction of the SCREEN is intended; LayoutBuilder
      // here gives unbounded vertical constraints (wrong tool).
      height: expanded
          ? MediaQuery.sizeOf(context).height * 0.85 // LINT (false positive)
          : 160,
    ),
  );
}
```

**Frequency:** Always, for these two structural patterns.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — `MediaQuery.sizeOf` is the correct/only tool in both cases |
| **Actual** | `[prefer_layout_builder_for_constraints] Use LayoutBuilder for constraint-aware layout instead of MediaQuery for widget sizing.` reported on the `MediaQuery.sizeOf(context).width/.height` node |

---

## AST Context

```
Pattern A:
MethodInvocation (LayoutBuilder)
  └─ FunctionExpression (builder)
      └─ VariableDeclaration (maxWidth)
          └─ ConditionalExpression
              ├─ condition: PropertyAccess constraints.maxWidth.isFinite
              ├─ then:      PrefixedIdentifier constraints.maxWidth
              └─ else:      PropertyAccess  ← node reported here
                              .width  (target: MethodInvocation MediaQuery.sizeOf(context))

Pattern B:
VariableDeclaration (mapHeight)
  └─ ConditionalExpression
      └─ then: BinaryExpression (*)
                ├─ left:  PropertyAccess  ← node reported here
                │           .height (target: MethodInvocation MediaQuery.sizeOf(context))
                └─ right: SimpleIdentifier fraction
```

---

## Root Cause

`runWithReporter` (lines ~2600-2631) registers `addPropertyAccess` and reports on
`MediaQuery.sizeOf(context).width/.height` whenever it is not:

1. `_isMediaQuerySizeDimensionInLiteralScaleOrBreakpoint(node)` (line 2618), or
2. `_isPositionalCallArgument(node)` (line 2627), or
3. `_isInNonBuildScope(node)` (line 2628).

Neither exemption recognizes the two legitimate cases:

### Hypothesis A (Pattern A): no enclosing-LayoutBuilder / conditional-fallback check

The rule never inspects whether the flagged node is the else-branch of a
`ConditionalExpression` whose condition tests `<something>.isFinite` (or whether
an enclosing `LayoutBuilder.builder` already binds `constraints`). When the code
*does* use `LayoutBuilder` and only falls back to `MediaQuery` for the unbounded
case, the rule's premise ("you should use LayoutBuilder instead") is already
satisfied — but it still fires on the fallback.

### Hypothesis B (Pattern B): no viewport-fraction / unbounded-parent check

The rule treats `MediaQuery.sizeOf().height * fraction` as widget sizing, but a
screen-fraction inside an unbounded-main-axis parent is exactly the
"screen/window extent" use the rule's own dartdoc says is *not* interchangeable
with `LayoutBuilder` constraints. The sibling rule `PreferFractionalSizingRule`
(`prefer_fractional_sizing`, same file ~line 2451) already owns the
`MediaQuery.size * 0.x` pattern and steers it to `FractionallySizedBox`; this
rule double-flags it, and `FractionallySizedBox` needs a *bounded* parent (a
scroll view does not provide one), so neither LayoutBuilder nor
FractionallySizedBox is applicable.

---

## Suggested Fix

In `runWithReporter`, before `reporter.atNode(node, _code)` for the
`.width`/`.height` branch (line ~2629), add early-returns:

1. **Conditional fallback:** if the node is (transitively) the `elseExpression`
   of a `ConditionalExpression` whose `condition` references `.isFinite` on a
   `maxWidth`/`maxHeight` (i.e., a constraints-finiteness guard), skip.
2. **Enclosing LayoutBuilder fallback:** if an ancestor is a `LayoutBuilder`
   `builder` `FunctionExpression` AND the node sits on the non-primary branch of
   a constraints-guarded conditional, skip — the code already uses LayoutBuilder.
3. **Viewport fraction:** if the node is an operand of a `BinaryExpression` whose
   operator is `*` and the other operand is a `< 1.0` fraction (mirroring
   `PreferFractionalSizingRule`'s detection), defer to `prefer_fractional_sizing`
   and skip here to avoid double-flagging.

---

## Fixture Gap

The fixture at `example*/lib/widget/prefer_layout_builder_for_constraints_fixture.dart`
should include:

1. **`MediaQuery.sizeOf` as the else-branch of a `constraints.maxWidth.isFinite`
   ternary inside a `LayoutBuilder.builder`** — expect NO lint.
2. **`MediaQuery.sizeOf(context).height * fraction` inside a
   `SingleChildScrollView`** — expect NO lint (owned by `prefer_fractional_sizing`).
3. **Plain `width: MediaQuery.sizeOf(context).width` with no LayoutBuilder and no
   fraction** — expect LINT (regression guard, the true-positive case must stay).

---

## Root-cause downstream sites (Saropa Contacts)

- `lib/components/home/section/in_focus_full_screen.dart:117` — Pattern A.
- `lib/views/home/favorite_tab.dart:358` — Pattern B.

Both carry a `// ignore: saropa_lints/prefer_layout_builder_for_constraints`
referencing this report until the rule is narrowed.

**Secondary finding (suppression placement):** in the headless scanner
(`dart run saropa_lints scan`), a standalone `// ignore:` comment placed on its
own line BETWEEN the operands of a `ConditionalExpression` (i.e. immediately
above the flagged `: MediaQuery…` / `? MediaQuery…` operand line) is **not
honored** — the diagnostic still fires. A **trailing** `// ignore:` on the same
line as the flagged operand IS honored. This held for both the bare
(`prefer_layout_builder_for_constraints`) and prefixed
(`saropa_lints/prefer_layout_builder_for_constraints`) forms. The scanner's
ignore-line mapping appears to attribute a mid-ternary comment to the wrong
line; worth a separate look at the ignore-info computation.

---

## Environment

- saropa_lints version: native analyzer plugin (v5 ignore-comment format)
- Dart SDK version: bundled with current Flutter toolchain
- custom_lint version: n/a (analysis_server_plugin)
- Triggering project/file: Saropa Contacts — `in_focus_full_screen.dart`, `favorite_tab.dart`

---

## Finish Report (2026-06-14)

### Scope

(A) Dart lint rule / analyzer plugin. Touched `lib/src/rules/widget/widget_layout_constraints_rules.dart`, the rule's fixture under `example/lib/widget_layout/`, and `CHANGELOG.md`. No extension/TypeScript change.

### What changed

`prefer_layout_builder_for_constraints` gained two false-positive exemptions in `runWithReporter`, evaluated before the diagnostic is reported on a `MediaQuery.sizeOf(...).width/.height` (or `.of(...).size.width/.height`) read:

- **Constraint-finiteness fallback (Pattern A).** `_isConstraintFinitenessFallback` walks the ancestor chain to an enclosing `ConditionalExpression`, confirms the flagged node sits on a value branch (`thenExpression`/`elseExpression`, not the condition), and that the condition tests `.isFinite`/`.isInfinite` on a constraint extent. The condition is scanned by `_ConstraintFinitenessVisitor` (a `RecursiveAstVisitor`) which matches an `.isFinite`/`.isInfinite` property read whose receiver's final identifier is `maxWidth`, `maxHeight`, `minWidth`, or `minHeight` (via the library-shared `referencesConstraintExtent`). Such code already uses `LayoutBuilder` and reads `MediaQuery` only when the parent passes unbounded constraints, where the LayoutBuilder value is `Infinity` and unusable — there is no LayoutBuilder formulation to migrate to. The walk stops at `Statement`/`FunctionBody` boundaries so an unrelated outer ternary cannot match.
- **Viewport scaling (Pattern B).** The existing literal-scale-or-breakpoint helper was renamed from `_isMediaQuerySizeDimensionInLiteralScaleOrBreakpoint` to `_isMediaQuerySizeDimensionScaledOrBreakpoint` and its `*`/`/` branch no longer requires a numeric-literal sibling. Scaling the screen/window extent by a factor — literal (`* 0.85`) or named (`* fraction`) — is viewport-proportional sizing, which `LayoutBuilder` cannot express inside an unbounded-main-axis parent. Comparison operators (`>`/`<`/`>=`/`<=`) still require a numeric literal, because comparing screen extent to a variable is ambiguous and may be genuine constraint logic rather than a device-class breakpoint.

The rule dartdoc documents both exemptions. Two GOOD fixtures were added after `OkScreenFraction` so the existing "no `expect_lint` after `OkScreenFraction`" invariant holds: `OkConstraintFinitenessFallback` (Pattern A) and `OkViewportFractionVariable` (named-factor Pattern B).

### Verification

- `dart run saropa_lints scan` against the fixture: `prefer_layout_builder_for_constraints` fires on the genuine sizing cases at fixture lines 18, 33, 35, 47, 60, 62, 112, 127 and on neither new GOOD case (lines ~284 and ~304 are clean). No regression on the other GOOD cases (screen fraction, breakpoint comparison, `viewInsets`, static utilities, positional breakpoint helper).
- `dart test test/rules/widget/prefer_layout_builder_for_constraints_fixture_test.dart`: all 6 tests pass (registration, registry resolution, professional-tier membership, nine `expect_lint` markers, static-utility presence, no markers after `OkScreenFraction`).
- `dart analyze lib/src/rules/widget/widget_layout_constraints_rules.dart`: no issues.

### Out of scope (tracked separately)

The "Secondary finding (suppression placement)" above — a standalone `// ignore:` placed on its own line mid-`ConditionalExpression` is not honored by the headless scanner — is a scanner ignore-line-mapping issue independent of this rule's detection logic. It is captured in `bugs/infra_scan_ignore_comment_mid_ternary_operand_not_honored.md` and is not addressed here.
