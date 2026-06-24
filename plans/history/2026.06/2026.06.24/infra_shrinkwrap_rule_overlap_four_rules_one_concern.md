# BUG: shrinkWrap rule overlap — four rules flag one concern, no shared suppression

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-24
Rules: `avoid_shrink_wrap_in_scroll`, `avoid_shrinkwrap_in_scrollview`, `avoid_shrink_wrap_in_lists`, `avoid_shrink_wrap_expensive`
Files: `lib/src/rules/widget/widget_layout_flex_scroll_rules.dart`, `lib/src/rules/widget/scroll_rules.dart`
Severity: Infrastructure (rule design / overlap) — High (forces per-site, per-rule-name `// ignore:` churn downstream)
Rule versions: in_scroll {v6}, in_scrollview {v6}, in_lists {v4}, expensive {v5}

---

## Summary

Four separately-registered rules all police the same `shrinkWrap: true` concern on
scrollables. A single ListView with `shrinkWrap: true` can be flagged by up to four
differently-named diagnostics. Downstream, a site that has already been reviewed and
suppressed under one rule name (e.g. `// ignore: saropa_lints/avoid_shrink_wrap_expensive`)
is re-flagged by another rule name (`avoid_shrink_wrap_in_scroll`) because the ignore
directive matches a rule id, not the concern. The result is repeated, low-value
suppression churn for code that was already acknowledged as correct.

`avoid_shrink_wrap_in_scroll`'s own message concedes it is redundant: *"This is a
stylistic preference for Slivers over shrinkWrap — see `avoid_shrinkwrap_in_scrollview`
for the context-aware rule that targets the genuinely dangerous nested-scrollable case."*

---

## Attribution Evidence

```bash
# Positive — all four rules ARE defined here
$ for r in avoid_shrink_wrap_in_scroll avoid_shrinkwrap_in_scrollview \
           avoid_shrink_wrap_in_lists avoid_shrink_wrap_expensive; do
    grep -rn "'$r'" lib/src/rules/
  done
lib/src/rules/widget/widget_layout_flex_scroll_rules.dart:1725:    'avoid_shrink_wrap_in_scroll',
lib/src/rules/widget/scroll_rules.dart:61:                'avoid_shrinkwrap_in_scrollview',
lib/src/rules/widget/widget_layout_flex_scroll_rules.dart:221:    'avoid_shrink_wrap_in_lists',
lib/src/rules/widget/scroll_rules.dart:951:                'avoid_shrink_wrap_expensive',
```

All four live in `saropa_lints`. No sibling-repo ambiguity (every match is in this repo).

**Emitter registration:**
- `avoid_shrink_wrap_in_scroll` — `lib/src/rules/widget/widget_layout_flex_scroll_rules.dart:1725`
- `avoid_shrink_wrap_in_lists` — `lib/src/rules/widget/widget_layout_flex_scroll_rules.dart:221`
- `avoid_shrinkwrap_in_scrollview` — `lib/src/rules/widget/scroll_rules.dart:61`
- `avoid_shrink_wrap_expensive` — `lib/src/rules/widget/scroll_rules.dart:951`

**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` (saropa_lints analyzer plugin)

---

## Reproducer

A bounded ListView inside a Column with `NeverScrollableScrollPhysics` — the canonical
"shrinkWrap is required and safe" pattern named in the rules' own messages:

```dart
Column(
  children: <Widget>[
    ListView.builder(
      padding: EdgeInsets.zero,
      // ignore: saropa_lints/avoid_shrink_wrap_expensive -- nested Column; bounded list
      shrinkWrap: true,                 // suppressed under ONE rule name...
      physics: const NeverScrollableScrollPhysics(),
      itemCount: groups.length,         // small, bounded
      itemBuilder: (_, i) => Text('$i'),
    ),
  ],
)
// ...still LINTS under avoid_shrink_wrap_in_scroll {v6}, because the ignore
// directive matches a rule id, not the shared concern.
```

**Frequency:** Always, on any site already suppressed under a different shrinkWrap rule name.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | One canonical shrinkWrap rule (the context-aware `avoid_shrinkwrap_in_scrollview`). A site acknowledged once is not re-flagged under three other names. |
| **Actual** | Up to four diagnostics for one `shrinkWrap: true`; suppressing one leaves the others firing. |

---

## Root Cause

Four independent `LintRule` registrations target the same construct
(`shrinkWrap: true` on a scrollable) with no shared identity or suppression group:

- `scroll_rules.dart` defines the context-aware pair `avoid_shrinkwrap_in_scrollview`
  {v6} (targets the genuinely dangerous nested-scrollable case) and the older
  `avoid_shrink_wrap_expensive` {v5}.
- `widget_layout_flex_scroll_rules.dart` separately defines `avoid_shrink_wrap_in_lists`
  {v4} and `avoid_shrink_wrap_in_scroll` {v6} — the latter self-described as a stylistic
  duplicate of `avoid_shrinkwrap_in_scrollview`.

Because analyzer `// ignore:` matches a rule id, suppressing one does not suppress the
overlap. There is no rule-group/alias mechanism that would let one acknowledgment cover
the shared concern.

---

## Suggested Fix

Pick one canonical rule and retire / alias the rest:

1. Keep `avoid_shrinkwrap_in_scrollview` {v6} (context-aware: only flags the genuinely
   dangerous nested-scrollable case; does not fire on bounded `NeverScrollableScrollPhysics`
   lists inside a Column).
2. Deprecate `avoid_shrink_wrap_in_scroll` {v6} — its own message admits redundancy. At
   minimum drop it from default tiers; ideally remove the registration.
3. Reconcile `avoid_shrink_wrap_expensive` {v5} and `avoid_shrink_wrap_in_lists` {v4}
   against the canonical rule — fold their detection into `avoid_shrinkwrap_in_scrollview`
   or mark them superseded in `tiers.dart`.
4. If multiple names must coexist for back-compat, give them a shared suppression alias so
   one `// ignore:` covers the concern.

Downstream mitigation already applied in Saropa Contacts: `avoid_shrink_wrap_in_scroll`
disabled in `analysis_options.yaml` (it is the pure-stylistic duplicate); the
context-aware `avoid_shrinkwrap_in_scrollview` stays enabled.

---

## Fixture Gap

The fixture should assert that the canonical rule does NOT fire on:

1. `ListView.builder(shrinkWrap: true, physics: NeverScrollableScrollPhysics(), ...)`
   inside a `Column` with a bounded `itemCount` — expect NO lint.
2. The same ListView nested inside another scrollable without
   `NeverScrollableScrollPhysics` — expect LINT (the genuinely dangerous case).

And that retired/aliased names do not double-report case 2.

---

## Environment

- saropa_lints version: (current `main`, rules as of 2026-06-24)
- Triggering project: Saropa Contacts (`d:\src\contacts`) — 38 sites flagged by
  `avoid_shrink_wrap_in_scroll`, all already suppressed under `avoid_shrink_wrap_expensive`
  or using the safe bounded-Column pattern.

---

## Finish Report (2026-06-24)

**Resolution:** Consolidated the four overlapping rules to a single canonical rule
via the codebase's deprecation/supersede mechanism (no rule classes removed, so
back-compat and quick fixes are preserved).

**Canonical chosen: `avoid_shrink_wrap_expensive`** (not the bug's suggested
`avoid_shrinkwrap_in_scrollview`). Reason confirmed by reading all four `run`
methods: `expensive` is the strict superset — it flags `shrinkWrap: true` on any
scrollable (nested *and* non-nested) while already exempting the safe
`physics: NeverScrollableScrollPhysics()` pattern that the bug cares about. It is
also already in the **essential** tier, so no tier move was needed and no
coverage was lost. `avoid_shrinkwrap_in_scrollview` is a nested-only subset of it
with no extra value. User agreed to keep `expensive`.

**Changes:**
- `avoid_shrink_wrap_in_scroll` ({v6}, stylistic INFO) → `RuleStatus.deprecated`.
  It fired on *every* `shrinkWrap: true` with no exemption, including the safe
  bounded-Column pattern — the reproducer villain.
- `avoid_shrink_wrap_in_lists` ({v4}, recommended WARN) → `RuleStatus.deprecated`.
  Nested-only but lacked the `NeverScrollableScrollPhysics` exemption, so it
  false-positived where the canonical rule correctly stays quiet.
- `avoid_shrinkwrap_in_scrollview` ({v6}, recommended WARN) → `RuleStatus.deprecated`.
  Strict subset of the canonical rule; kept only to retire under one name.
- `avoid_shrink_wrap_expensive` → added `supersedesRules` listing the three above,
  with a header comment marking it canonical.

**Effect:** `RuleStatus.deprecated` is filtered by `lifecycleFilteredRules`
(`lib/src/init/rule_metadata.dart`), which excludes beta/deprecated rules from
freshly generated tier configs in both the interactive `init_runner` and the
headless `write_config_runner` (the path the VS Code extension and CI use).
A regenerated config therefore carries only `avoid_shrink_wrap_expensive`, so one
acknowledgment covers the concern and the per-rule-name suppression churn ends.

**Suppression alias (suggested fix item 4):** not implemented. The analyzer
matches `// ignore:` to a single diagnostic id with no rule-group/alias hook, and
collapsing to one canonical rule removes the need — only one id fires per site.

**Fixture Gap:** not closed with new fixtures. All `example/lib/scroll/*` shrinkWrap
fixtures are stubs (`void main() {}`) because these rules need real Flutter
widget/framework context the example package does not provide, and fixtures are
not run in CI. The canonical rule's detection logic is unchanged (only metadata
added), so its firing behavior is unaffected by this change.

**Verification:** `dart test` on `test/integrity/saropa_lints_test.dart`,
`test/rules/widget/scroll_rules_test.dart`,
`test/rules/widget/widget_layout_rules_test.dart`,
`test/scan/rule_quick_fix_presence_test.dart` — all 388 tests pass. Integrity
confirms every rule (including the now-deprecated three) still resolves to exactly
one tier set, and the rule classes still instantiate with their quick fixes.

**Downstream note (NOT applied here — different project):** Saropa Contacts can
drop its manual `avoid_shrink_wrap_in_scroll` disable from `analysis_options.yaml`
and re-run init once this ships; the other two deprecated names can also be removed.
