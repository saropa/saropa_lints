# BUG: `avoid_color_only_indicators` — fires on a decorative active-state bar whose state is already conveyed by sibling widgets

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-22
Rule: `avoid_color_only_indicators`
File: `lib/src/rules/ui/accessibility_rules.dart` (line ~428)
Severity: False positive
Rule version: v6 | Since: unknown | Updated: v6

---

## Summary

The rule flags any `Container` whose only named args are within
`{color, child, key, width, height}` and whose `color:` is a conditional, treating
it as a standalone color-only status indicator. It inspects the `Container` in
isolation and has no awareness of sibling widgets. A thin decorative underline bar
that merely *reinforces* an active state already conveyed by a sibling bold text
label and a sibling solid-vs-light icon is reported as inaccessible, when the
surface in fact satisfies WCAG 1.4.1.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
$ grep -rn "'avoid_color_only_indicators'" lib/src/rules/
lib/src/rules/ui/accessibility_rules.dart:416:    'avoid_color_only_indicators',
```

**Emitter registration:** `lib/src/rules/ui/accessibility_rules.dart:416`
**Rule class:** `AvoidColorOnlyIndicatorsRule` — `accessibility_rules.dart:400`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart`

---

## Reproducer

Minimal — an underline tab marker inside a `Column`, where the active tab is also
bold and uses a solid (vs light) icon:

```dart
Widget buildTab(BuildContext context, bool active, Color accent) {
  return Column(
    children: <Widget>[
      Row(
        children: <Widget>[
          // Secondary cue #1: glyph SHAPE changes (solid vs light) on active.
          CommonIcon(
            iconCommon: ThemeCommonIcon.Email,
            options: CommonIconOptions(isIconActive: active),
          ),
          // Secondary cue #2: font WEIGHT changes (bold) on active.
          CommonText('Email', isBold: active),
        ],
      ),
      // The flagged node. This is a decorative reinforcement bar, NOT the
      // primary (or only) status cue. Should NOT lint.
      Container(
        height: 2.5,
        color: active ? accent : Colors.transparent, // LINT — but should NOT
      ),
    ],
  );
}
```

**Frequency:** Always — any conditionally-colored thin `Container` with only
`height`/`color` triggers it, regardless of sibling cues.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — active state has two non-color cues (bold weight, solid/light glyph) in sibling widgets; the colored bar only reinforces it |
| **Actual** | `[avoid_color_only_indicators]` reported on the `color: active ? accent : Colors.transparent` argument |

---

## AST Context

```
MethodDeclaration (_buildUnderlineTab)
  └─ ... CommonInkWell
      └─ Column
          ├─ Row  (contains CommonIcon[isIconActive], CommonText[isBold])  ← non-color cues live here
          └─ InstanceCreationExpression (Container)                        ← rule's only view
              └─ ArgumentList
                  ├─ NamedExpression (height: 2.5)
                  └─ NamedExpression (color: ConditionalExpression)        ← node reported here
```

The rule registers on the `Container` `InstanceCreationExpression` and never walks
to the parent `Column` / sibling `Row`, so it cannot see that the state is already
distinguished by non-color means.

---

## Root Cause

In `runWithReporter` (`accessibility_rules.dart:428-454`):

1. It matches any `Container` with a `color:` that is a `ConditionalExpression`.
2. It declares the Container "color-only" when every named arg is in
   `{color, child, key, width, height}` (`hasOnlyColorAndChild`, lines 437-446).
3. It reports — with no inspection of anything outside the Container node.

The detection is too broad in two independent ways:

### Hypothesis A: no sibling-cue awareness (primary)

A status indicator is "color-only" relative to the *whole control*, not relative to
one `Container`. Here the active state is carried by a sibling `CommonText(isBold:
active)` (weight cue) and a sibling `CommonIcon(isIconActive: active)` (glyph-shape
cue). The rule reports on the bar in isolation, so it cannot tell a sole indicator
from a decorative reinforcement.

### Hypothesis B: transparent ↔ accent is presence, not red/green status

The conditional here is `active ? accent : Colors.transparent` — it toggles a bar
on/off (a position/presence cue), not red↔green meaning. The rule's own message and
correction text describe red/green error/success status; a show/hide-by-transparency
bar is a different (and far weaker a11y-risk) pattern that the rule lumps in.

---

## Suggested Fix

Prefer narrowing the trigger so this common, correct pattern stops firing. Options,
in order of preference:

1. **Skip when a sibling cue exists.** When the `Container` is a child of a
   `Column`/`Row`/`Flex`/`Stack`, scan sibling widgets for a non-color cue keyed on
   the same condition — e.g. a `Text`/`CommonText` with a conditional `fontWeight`/
   `isBold`, or an `Icon`/`CommonIcon` with a conditional shape/`isIconActive`. If
   one exists, suppress.
2. **Exclude the show/hide-by-transparency shape.** When one branch of the
   conditional is `Colors.transparent` (or `Colors.transparent.withOpacity(...)`),
   treat it as a presence toggle, not a status color, and do not report.
3. At minimum, exclude very thin bars (`height`/`width` ≤ ~4) since a 2.5px strip is
   a decorative rule/underline, not a status badge.

Option 1 is the correct general fix; option 2 is a cheap, high-value narrowing that
clears the most common real-world hits (active-tab underlines, selection
underbars).

---

## Fixture Gap

`example/lib/accessibility/avoid_color_only_indicators_fixture.dart` should add:

1. **Thin `Container` underline with `active ? accent : Colors.transparent` inside a
   `Column` whose `Row` sibling has a conditional-bold `Text`** — expect NO lint
   (sibling weight cue present).
2. **Same bar with a sibling `Icon` toggling shape on the same condition** — expect
   NO lint (sibling glyph-shape cue present).
3. **`active ? accent : Colors.transparent` with NO sibling cue** — expect NO lint
   under option 2 (transparency = presence toggle), or LINT if only option 1 is
   adopted (document which).
4. **Genuine red/green standalone dot** (`isError ? Colors.red : Colors.green`, no
   sibling cue) — expect LINT (true positive must still fire).

---

## Environment

- saropa_lints version: (rule message `{v6}`)
- Dart SDK version: (Flutter stable)
- custom_lint version: native analyzer plugin (analysis_server_plugin)
- Triggering project/file: Saropa Contacts —
  `lib/components/primitive/tabs/common_tab_bar.dart:286` (`_buildUnderlineTab`)

---

## Resolution (2026-06-22, rule v7)

Both option 1 (sibling-cue awareness) and option 2 (transparency presence toggle)
were implemented in `AvoidColorOnlyIndicatorsRule.runWithReporter`
(`lib/src/rules/ui/accessibility_rules.dart`). Option 1 was required, not just
preferred: the rule's own documented GOOD example (a `Row` with a conditional
`Icon` beside the colored `Container`) and the existing fixture `_good3` were
themselves false positives under v6.

What the fix does, before reporting:

1. **Transparency toggle (option 2).** If either branch of the `color:`
   conditional resolves to `Colors.transparent` (including
   `Colors.transparent.withOpacity(...)` chains), the bar is a show/hide presence
   cue, not a red-vs-green hue — suppressed. Clears the reported active-tab
   underline (`active ? accent : Colors.transparent`).
2. **Sibling non-color cue (option 1).** Walks to the enclosing `children` list
   and searches each sibling subtree for a Text/Icon-family widget
   (`name.contains('Text') || name.contains('Icon')`, covering Flutter's
   `Text`/`Icon` and project `Common*` wrappers) that references one of the
   identifiers used in the bar's color condition. Matching is by identifier-name
   intersection (whole tokens, not substrings) so an unrelated conditional
   elsewhere does not mask a genuine issue.

Option 3 (thin-bar height heuristic) was deliberately not adopted — it risks
suppressing small genuine status dots, and options 1+2 already clear every
documented case.

### Verification

Ran the resolved scan CLI against a self-contained reproducer
(`dart run bin/saropa_lints.dart scan <dir> --tier comprehensive --resolve`):

- Standalone `isError ? Colors.red : Colors.green` (no sibling, no transparent) — **LINT** (true positive preserved).
- `Row` with sibling `Icon(isError ? ...)` + colored `Container` — no lint.
- Thin bar `active ? accent : Colors.transparent` in a `Column` — no lint.
- Bar with sibling `Text(... fontWeight: active ? bold : normal)` (opaque colors) — no lint.
- Bar with sibling `Icon(active ? ...)` nested in a `Row` (opaque colors) — no lint.
- Opaque red/green `Container` in a `Column` with no cue — **LINT** (true positive preserved).

### Files changed

- `lib/src/rules/ui/accessibility_rules.dart` — rule logic + `_IdentifierCollector` / `_SiblingCueVisitor` helpers; doc and message bumped to v7.
- `example/lib/accessibility/avoid_color_only_indicators_fixture.dart` — added the four GOOD cases above and a second standalone-status BAD case.
- `CHANGELOG.md` — `[14.0.8]` Fixed entry.

### Not addressed (out of scope)

The triggering file lives in Saropa Contacts, a separate project — no edits made
there. Once this ships, the false positive at `common_tab_bar.dart:286` clears
without a code change in that repo.

---

## Finish Report (2026-06-22)

### Defect

`avoid_color_only_indicators` (rule v6, `lib/src/rules/ui/accessibility_rules.dart`)
reported every `Container` with a conditional `color:` and only
color/size/child/key arguments, inspecting the node in isolation. It had no
awareness of sibling widgets, so a decorative active-state underline whose state
was already carried by a sibling bold `Text` or shape-toggling `Icon` was flagged
as a WCAG 1.4.1 violation. The rule's own documented GOOD example (a `Row` with a
conditional `Icon` beside the colored `Container`) and the `_good3` fixture were
themselves false positives.

### Change

`runWithReporter` now, after confirming a conditional `color:` on an
otherwise-bare `Container`, applies two suppressions before reporting:

- **Transparency presence toggle.** `_togglesTransparency` / `_isTransparentColor`
  detect either branch resolving to `Colors.transparent`, including
  `Colors.transparent.withOpacity(...)` chains (method-chain unwrap to the base
  `PrefixedIdentifier` / `PropertyAccess`). A transparent branch hides the
  element, so there is no hue to disambiguate — a show/hide cue, not a status
  color.
- **Sibling non-color cue.** `_hasSiblingNonColorCue` walks to the enclosing
  `children` `ListLiteral` (stopping at the first enclosing widget so it never
  crosses into another widget's argument list) and searches each sibling subtree
  with `_SiblingCueVisitor` for a Text/Icon-family widget
  (`name.contains('Text') || name.contains('Icon')`) that references one of the
  identifiers in the color condition. Matching uses identifier-name set
  intersection (`_IdentifierCollector`), comparing whole tokens rather than
  substrings so an unrelated conditional elsewhere does not mask a genuine issue.

Both were necessary: the transparency toggle clears the reported active-tab
underline, while sibling-cue awareness is what makes the rule's own GOOD example
pass. Option 3 from the report (a thin-bar height heuristic) was rejected — it
risks suppressing small genuine status dots, and the two adopted suppressions
already clear every documented case.

### Scope

Rule logic and helpers in `lib/src/rules/ui/accessibility_rules.dart`; doc header
and `LintCode` message bumped v6 -> v7 (`Updated: v14.0.8`). Fixture
`example/lib/accessibility/avoid_color_only_indicators_fixture.dart` gained four
GOOD cases (sibling Icon, transparency toggle, sibling bold Text, nested glyph
Icon) and a second standalone-status BAD case. `CHANGELOG.md` `[14.0.8]` Fixed
entry added. No edits in the triggering project (Saropa Contacts).

### Verification

`dart run bin/saropa_lints.dart scan <dir> --tier comprehensive --resolve`
against a self-contained reproducer: the two standalone red/green indicators
(no sibling, no transparent branch) still LINT; all four GOOD patterns are clean.
`dart analyze` on the changed rule file: no issues. `dart test
test/rules/ui/accessibility_rules_test.dart`: 82/82 pass. The unit-test harness
for this file is instantiation pins plus fixture-existence checks (no
analyzer-backed assertion path), so behavior was verified through the scan CLI
and fixtures.
