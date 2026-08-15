# NEW RULE PROPOSAL: flag bracketed/parenthesized text in `CommonButton`/`CommonButtonWait` labels

**Status: Fixed**

Created: 2026-08-14
Rule: (proposed — no existing rule name yet, suggest `avoid_parenthesized_button_caption`)
Severity: N/A (feature request, not a false positive/negative on an existing rule)

---

## Summary

This is a **new-rule proposal**, not a bug against an existing rule — filed here per
project convention ("file lint FPs/feature ideas upstream, don't write the rule in the
downstream app repo").

In `saropa_contacts`, `CommonButton` and `CommonButtonWait` (`lib/components/primitive/
buttons/common_button.dart` / `common_button_wait.dart`) support a `text` (main label)
and a separate `subtitleText` (dimmer, smaller secondary line). Twice now, developers
have put clarifying detail inline in the main `text` using parentheses instead of using
`subtitleText`:

- `'Delete All Contacts (User & Imported)'`
- `'Import Contacts (Quick Pass)'`

Both were fixed by hand (2026-08-14, `saropa_contacts` commit `fix(database-tools): move
bracketed button captions to subtitle, dim subtitle, toast on env-override delete`) by
splitting into `text: '...'` + `subtitleText: '...'`. Nothing prevents this regressing —
the fix was example-only, with no enforcement.

## Proposed Rule

Flag any `CommonButton(...)` / `CommonButtonWait(...)` constructor call where the `text:`
argument (or the value passed to a named l10n getter used as `text:`) is a string literal
containing a parenthesized segment — `(...)` — that is not itself the entire string. The
`subtitleText:` parameter is exempt (parentheses there are legitimate, e.g. wrapping a
waiting-state ellipsis).

**Detection is necessarily best-effort on l10n calls** — `text: l10n.someKey` cannot be
statically resolved to its ARB value without cross-referencing `app_en.arb`. Two options,
ranked by cost:

1. **Literal-only (cheap, high precision):** only flag inline string literals /
   concatenations passed directly to `text:` (catches the exact pattern above — the
   `_ButtonImportNativeContactsFast` case was a raw string literal, not an l10n call).
2. **ARB cross-reference (more work, catches more):** for `text: l10n.<key>`, resolve
   `<key>` against `app_en.arb`'s English value and flag if it contains `(...)`. This
   would have caught `databaseToolsButtonDeleteAllContactsUserAndImported` even though
   the call site itself was just an l10n getter reference with no literal parens visible
   in the Dart source.

Recommend starting with (1) — it's a pure AST match with no cross-file resolution, and
already covers half of the two real regressions found.

## Reproducer

```dart
// LINT — parens belong in subtitleText, not text
CommonButton(
  text: 'Delete All Contacts (User & Imported)',
  onPressed: () {},
);

// OK — split into text + subtitleText
CommonButton(
  text: 'Delete All Contacts',
  subtitleText: 'User & Imported',
  onPressed: () {},
);

// OK — subtitleText itself may contain parens (e.g. waiting-state ellipsis wrapper)
CommonButton(
  text: 'Clean & Repair Database',
  subtitleText: '(Cleaning…)',
  onPressed: () {},
);
```

## Why This Matters

- No lint currently enforces the `text`/`subtitleText` split; the convention exists only
  as tribal knowledge + one example in `database_tools_panel_delete_contacts.dart`.
- The failure mode is purely cosmetic (a slightly cluttered button label), so it is easy
  to miss in review and easy to reintroduce — exactly the kind of drift a lint rule is
  for.

## Fixture Gap (once implemented)

The fixture should include:
1. `text:` with inline `(...)` on a raw string literal — expect LINT
2. `text:` with inline `(...)` on a string built via `+`/adjacent-string-literal
   concatenation — expect LINT
3. `subtitleText:` containing `(...)` — expect NO lint (subtitle position already implies
   secondary detail; wrapping in parens there is an existing accepted pattern, e.g.
   `CommonButtonWait`'s waiting-text formatter)
4. `text:` with balanced parens that ARE the whole string, e.g. `'(Coming Soon)'` — open
   question whether this should still lint; recommend LINT (the fix is still "move to
   subtitleText", the button should have real text)
5. `text: l10n.someKey` where the getter name gives no textual signal — expect NO lint
   under approach (1); this is the accepted false-negative gap unless approach (2) is
   built later

## Environment

- Found in: `saropa_contacts` (downstream app), `lib/components/utilities/database_tools/`
- Triggering commit: `fix(database-tools): move bracketed button captions to subtitle...`
  (2026-08-14)

## Finish Report (2026-08-14)

Implemented approach (1) (literal-only detection) from the proposal as new rule
`avoid_parenthesized_button_caption`, shipped in the Comprehensive tier at `[14.5.9]`.

The rule visits `InstanceCreationExpression` nodes for `CommonButton` / `CommonButtonWait`,
extracts the `text:` argument's string value (`SimpleStringLiteral`, `AdjacentStrings`, or
`BinaryExpression` `+` concatenation — the last added after review flagged the bug report's
concatenation requirement as an initial gap), and flags it when the value matches
`RegExp(r'\(.*\)')`. `subtitleText:` is never inspected. String interpolation (`'text ($var)'`)
and l10n getter references (`text: l10n.someKey`) are out of scope, matching the bug report's
accepted false-negative gap for approach (1).

Registration: rule class in `widget_patterns_avoid_prefer_rules.dart`; factory in
`_allRuleFactories` (`saropa_lints.dart`); tier assignment in `comprehensiveOnlyRules`
(`tiers.dart`); mock `CommonButton`/`CommonButtonWait` classes added to
`example/lib/flutter_mocks.dart`; fixture at
`example/lib/widget_patterns/avoid_parenthesized_button_caption_fixture.dart`; smoke test in
`test/rules/widget/widget_patterns_rules_test.dart`.

A deep-review pass (background subagent) found three defects before verification: an
`impact`/`severity` mismatch (`LintImpact.warning` paired with `DiagnosticSeverity.INFO`,
corrected to `LintImpact.info`), a DartDoc `Since:` version tag that didn't match the actual
release (`v14.6.0` corrected to `v14.5.9`), and the missing `+`-concatenation handling noted
above. All three were fixed and re-verified.

Verification required `dart run saropa_lints scan <dir> --tier comprehensive --resolve` — the
default syntactic-only scan parses `CommonButton(...)` as a `MethodInvocation`, not an
`InstanceCreationExpression`, until the unit is type-resolved, so the rule silently produced
zero diagnostics without `--resolve`. A second issue surfaced only under `--resolve`: the
fixture had no diagnostics at all because `applicableFileTypes => {FileType.widget}` gates on
the file containing `extends StatelessWidget` / `StatefulWidget` / `State<`, and the original
fixture was bare top-level functions with no widget class. Added a minimal `_MarkerWidget
extends StatelessWidget` to the fixture to match how `CommonButton` is actually called in
downstream code (inside a widget's `build()`). After the fix, the resolved scan reported
exactly 5 hits — one per `_bad1`–`_bad5` — and zero on the 4 `GOOD` blocks.
