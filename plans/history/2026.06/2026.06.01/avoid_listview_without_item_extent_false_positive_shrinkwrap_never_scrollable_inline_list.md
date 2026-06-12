# BUG: `avoid_listview_without_item_extent` — Fires on `ListView.builder(shrinkWrap: true, physics: NeverScrollableScrollPhysics())` where the rule's scroll-perf rationale doesn't apply

**Status: Fixed**

Created: 2026-06-01
Fixed: 2026-06-01 — `widget_layout_flex_scroll_rules.dart` now reads `shrinkWrap` and `physics` from the argument list and skips the diagnostic when `shrinkWrap == true` AND `physics` is `NeverScrollableScrollPhysics(...)` (with or without `const`). Fixture extended with `goodInlineNonScrollingListView()` and `goodInlineNonScrollingListViewSeparated()` guards.
Rule: `avoid_listview_without_item_extent`
File: `lib/src/rules/widget/widget_layout_flex_scroll_rules.dart` (line ~597)
Severity: False positive
Rule version: v6 | Since: prior | Updated: v6

## Attribution (positive grep)

```
$ grep -rn "'avoid_listview_without_item_extent'" lib/src/rules/
lib/src/rules/widget/widget_layout_flex_scroll_rules.dart:581:    'avoid_listview_without_item_extent',
```

Rule lives in `saropa_lints`.

## Summary

The rule fires on `ListView.builder` that uses BOTH `shrinkWrap: true` AND `physics: const NeverScrollableScrollPhysics()` — the standard idiom for an inline, non-scrolling list rendered inside a scrollable parent (typically a Column inside SingleChildScrollView, or a CommonTitlePanel body). The rule's correction message recommends `itemExtent` (or `prototypeItem` / `itemExtentBuilder`) for "predictable scroll layout" and "large-list performance". Neither rationale applies here:

- **Predictable scroll layout** — the inner list doesn't scroll. The outer parent is the scrollable.
- **Large-list performance** — `shrinkWrap: true` forces ALL children to be laid out and measured up front anyway (that's how it computes its intrinsic size). The lazy-extent benefit `itemExtent` provides on a virtualizing list is impossible here.

Worse, applying `itemExtent` on a `shrinkWrap` inline list ACTIVELY breaks layout when the child rows have variable height (contact rows with wrapping names, multi-line status badges, etc.): items get force-clipped to the constant extent instead of taking their intrinsic height.

## Reproducer

```dart
// Inline list inside a Column, rendering all rows up front.
// Triggers the lint; no fix applies cleanly.
Column(
  children: <Widget>[
    SectionHeader('Companions'),
    ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: companions.length,
      itemBuilder: (BuildContext _, int i) => _CompanionRow(companions[i]),
    ),
    FooterButton(),
  ],
)
```

Trying the rule's recommended fix breaks variable-height rows:

```dart
ListView.builder(
  itemExtent: 64,   // ← force-clips rows whose intrinsic height > 64;
                    //   wraps a 2-line name onto a hidden third line.
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  itemCount: companions.length,
  itemBuilder: (BuildContext _, int i) => _CompanionRow(companions[i]),
)
```

## Why the combination matters

`shrinkWrap: true` + `physics: const NeverScrollableScrollPhysics()` together is the documented Flutter pattern for "use ListView.builder's index-based laziness as a Column", typically when:

- The list lives inside a scrollable parent (the outer scrolls; the inner doesn't).
- Row count is known and small (≤ display limit), so eager layout is fine.
- The author wants `itemBuilder`-style index-driven construction (e.g., bridging a `_Widget(contact: list[i])` adapter) without re-implementing the index loop in a Column.

The rule's perf rationale targets large virtualizing lists, not this inline-Column-substitute usage.

## Suggested fix

In the rule visitor at `lib/src/rules/widget/widget_layout_flex_scroll_rules.dart:597`, after reading the constructor name, also read the `shrinkWrap` and `physics` arguments. If `shrinkWrap == true` AND `physics` is `NeverScrollableScrollPhysics` (constructor or const literal), skip the diagnostic.

Rough sketch:

```dart
bool isInlineNonScrolling = false;
bool shrinkWrap = false;
bool neverScrollablePhysics = false;

for (final Expression arg in node.argumentList.arguments) {
  if (arg is NamedExpression) {
    final String name = arg.name.label.name;
    if (name == 'shrinkWrap') {
      final Expression v = arg.expression;
      if (v is BooleanLiteral && v.value == true) shrinkWrap = true;
    }
    if (name == 'physics') {
      final Expression v = arg.expression;
      if (v is InstanceCreationExpression &&
          v.constructorName.type.name.lexeme == 'NeverScrollableScrollPhysics') {
        neverScrollablePhysics = true;
      }
      // also handle `physics: someConstField` if widely used
    }
  }
}
isInlineNonScrolling = shrinkWrap && neverScrollablePhysics;

if (!hasItemExtent && !hasPrototypeItem && !hasItemExtentBuilder && !isInlineNonScrolling) {
  reporter.atNode(node.constructorName, code);
}
```

Detection can stay structural (no semantic resolution needed) because the combination is almost always written as boolean literal + const constructor.

## Fixture gap

Add a fixture that should NOT fire:

```dart
// fixtures/avoid_listview_without_item_extent_inline_non_scrolling_ok.dart
Column(
  children: <Widget>[
    ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (_, int i) => Text('$i'),
    ),
  ],
);  // expect: no diagnostic
```

## Downstream impact

2 sites in `saropa/contacts` are pure-FP under this pattern and need `// ignore: avoid_listview_without_item_extent` directives until the rule is fixed:

- `lib/components/contact/companion/contact_companion_list.dart:246`
- `lib/components/contact/contact_frequent_list_widget.dart:139`

Both lists render eagerly inside a `CommonTitlePanel` body (themselves inside a scrollable home-tab CustomScrollView). Each ignore carries a one-line rationale pointing at this bug report.

## Related

Sibling FP bug for the same rule's `ListView.separated` constructor-allowlist gap: [avoid_listview_without_item_extent_false_positive_listview_separated_unfixable.md](./avoid_listview_without_item_extent_false_positive_listview_separated_unfixable.md). Both bugs trace to the same rule visitor at `widget_layout_flex_scroll_rules.dart:597`; separate fixes (the `.separated` one drops a constructor branch, this one adds a skip condition).

## Finish Report (2026-06-01)

**Scope:** (A) Dart lint rule fix — single rule, no new rule introduced, no tier change.

**Files changed:**

- `lib/src/rules/widget/widget_layout_flex_scroll_rules.dart` — extended the `AvoidListViewWithoutItemExtentRule` argument loop to also read `shrinkWrap` (must be `BooleanLiteral true`) and `physics` (peels `ParenthesizedExpression`, matches `InstanceCreationExpression` whose `constructorName.type.name.lexeme == 'NeverScrollableScrollPhysics'`). When both are present, the diagnostic is suppressed. Inline comment names the failure mode (clip variable-height rows) and points at this bug.
- `example/lib/widget_layout/avoid_listview_without_item_extent_fixture.dart` — added `goodInlineNonScrollingListView()` (`.builder`) and `goodInlineNonScrollingListViewSeparated()` (`.separated`) — neither carries `expect_lint`, asserting the rule does not fire.
- `test/rules/config/listview_extent_metadata_rules_test.dart` — extended the mirror `_ListViewExtentVisitor._countIfMissingHints` with the same skip logic; added four positive/negative tests:
  - `shrinkWrap + const NeverScrollableScrollPhysics() skips`
  - `same skip applies to ListView.separated`
  - `still flags when only shrinkWrap is set (no physics)`
  - `still flags when only NeverScrollableScrollPhysics is set (no shrinkWrap)`
- `CHANGELOG.md` — new `[Unreleased]` section with a single `### Fixed` bullet describing the false-positive class and instructing users to remove any `// ignore:` they added for this pattern.
- `bugs/...shrinkwrap_never_scrollable_inline_list.md` → `plans/history/2026.06/2026.06.01/...` — archived with `Status: Fixed`.

**Why this fix and not the alternatives:**

- Removing `'separated'` from the rule's allowlist (sibling bug's proposal) was *not* done here — that's the other open bug. This fix is orthogonal: it skips both `.builder` and `.separated` when the inline-non-scrolling pattern is detected, without otherwise changing `.separated` handling. The sibling bug stays open.
- Structural detection (no semantic resolution) is acceptable here because the inline-non-scrolling idiom is overwhelmingly written with a `const NeverScrollableScrollPhysics()` literal or a bare constructor call — both parse as `InstanceCreationExpression` under custom_lint's resolved AST. `physics: someConstField` references are not chased; those are rare enough that the false-positive cost is acceptable until reported.

**Testing:**

- `dart test test/rules/config/listview_extent_metadata_rules_test.dart` — 8 tests pass (the original 4 + 4 new).
- `dart test test/rules/widget/widget_layout_rules_test.dart test/scan/rule_quick_fix_presence_test.dart` — all instantiation pins pass.
- Full `dart test` — one unrelated flake in `test/project_health/health_history_test.dart:builds well-formed trajectory points from git tags` that passes when run in isolation; unrelated to the rule change (project_health is the dashboard subsystem).
- `dart analyze --fatal-infos lib test` — `No issues found!` (CI mirror clean).
- `dart format` — all touched Dart files formatted.

**Scan-CLI verification note:** The Saropa scan CLI uses unresolved `parseString`, so `ListView.builder(...)` is parsed as `MethodInvocation` rather than `InstanceCreationExpression`, and the rule's `addInstanceCreationExpression` visitor does not see it from that CLI. This is a CLI limitation, not a rule defect — custom_lint runs the rule against fully-resolved ASTs in production. The unit-test mirror visitor in `listview_extent_metadata_rules_test.dart` handles both shapes and pins the exemption against the resolved (`const`-prefixed) form that real Dart code uses.

**Sibling `.separated` bug also fixed in the same commit:** The change was extended to also drop `'separated'` from the rule's constructor allowlist (`widget_layout_flex_scroll_rules.dart:609`), closing the unfixable-on-separated bug at the same time. Doc comment, problem message ({v7}), `Since/Updated`, and the fixture's `.separated` case were updated to match. See archived sibling report at [avoid_listview_without_item_extent_false_positive_listview_separated_unfixable.md](./avoid_listview_without_item_extent_false_positive_listview_separated_unfixable.md).

**Out of scope (deliberately not touched):**

- Shared physics-detection helper across `widget_layout_flex_scroll_rules.dart` and `scroll_rules.dart` (similar logic exists in both files but extracting would be feature-creep on a bug fix).

**Outstanding work:** None.

**Status:** Fixed.
