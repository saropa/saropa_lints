# `prefer_const_literals_to_create_immutables` — false positive: rule fires on `<Widget>[…]` literals that are children of an already-`const` constructor; adding the requested `const` is then flagged by the standard analyzer's `unnecessary_const`

**Status:** Fixed (2026-04-26)

Filed: 2026-04-26
Fixed in: Unreleased — added `if (node.isConst) return;` guard at `lib/src/rules/widget/widget_patterns_avoid_prefer_rules.dart:5252` (the `runWithReporter` body of `PreferConstLiteralsToCreateImmutablesRule`). Fixture extended with const-parent and const-context-propagation cases.
Rule: `prefer_const_literals_to_create_immutables`
File: `lib/src/rules/widget/widget_patterns_avoid_prefer_rules.dart` (line 5189, code at 5208–5276)
Severity: False positive (rule contradicts the standard analyzer's `unnecessary_const`)
Rule version: v1 | Severity in code: INFO | Impact: low

---

## Summary

The saropa_lints version of this rule duplicates the name of a built-in Dart analyzer lint, but its detection logic does not exempt collection literals that are *inside* a `const` constructor argument list. When the parent constructor is `const`, Dart auto-promotes the inner literal — adding an explicit `const` keyword is redundant and immediately flagged by the standard `unnecessary_const` rule. The two rules contradict each other; the user is given no valid resolution short of `// ignore:` or disabling one of them.

The standard analyzer's `prefer_const_literals_to_create_immutables` (enabled separately under `linter.rules`) does **not** fire on these cases, because it correctly recognizes the const-context promotion. Only the saropa_lints copy does.

---

## Attribution Evidence

```bash
$ grep -rn "'prefer_const_literals_to_create_immutables'" lib/src/rules/
lib/src/rules/widget/widget_patterns_avoid_prefer_rules.dart:5208:    'prefer_const_literals_to_create_immutables',
```

Rule lives here. Confirmed.

**Emitter registration:** `lib/src/rules/widget/widget_patterns_avoid_prefer_rules.dart:5189` (`PreferConstLiteralsToCreateImmutablesRule`)
**Rule class:** `PreferConstLiteralsToCreateImmutablesRule` — registered in `lib/src/rules/all_rules.dart`
**Diagnostic `source` / `owner`:** `dart` (saropa_lints native plugin)

**Naming-collision note:** This rule shares its name with the standard Dart analyzer's lint of the same id. Consumers cannot tell the two apart from the diagnostic message; only the emitter source distinguishes them. Consider renaming this rule (e.g., `prefer_const_literals_to_create_immutables_v2` or `saropa_prefer_const_collection_in_widget_args`) so the conflict is visible.

---

## Reproducer

Consumer project: `D:\src\contacts`. Site: `lib/components/contact/companion/generate_contact_companion.dart` — 9 occurrences (lines 91, 118, 145, 215, 243, 270, 297, 324, 351).

```dart
TableRow(
  children: <Widget>[
    const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[                       // LINT — saropa_lints rule fires here
        CommonIconText(
          text: 'Contact Details',
          iconCommon: ThemeCommonIcon.Phone,
          options: CommonIconTextOptions(
            fontSizeCommon: ThemeCommonFontSize.Medium,
          ),
        ),
        CommonText(
          'Phone numbers, emails, websites, etc.',
          colorCommon: ThemeCommonColor.ThemeOnSurfaceDim,
          fontSizeCommon: ThemeCommonFontSize.Small,
        ),
      ],
    ).withPadding(PreferenceItemName.defaultNamePadding),
    CommonToggleSwitch(
      isSelected: _includeContactDetails,
      onToggle: (bool isEnabled) => setStateSafe(() {
        _includeContactDetails = isEnabled;
      }),
    ),
  ],
),
```

Naïvely applying the rule's quick fix (`Add the const keyword before the collection literal`) produces:

```dart
const Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: const <Widget>[              // ← `const` added per the rule's instruction
    CommonIconText(...),
    CommonText(...),
  ],
)
```

…which the standard analyzer immediately flags with `unnecessary_const`:

> "Unnecessary 'const' keyword. Try removing the keyword."

The user is in a deadlock: keep `const` ⇒ `unnecessary_const` fires; remove `const` ⇒ `prefer_const_literals_to_create_immutables` fires.

**Frequency:** Always — every `<Widget>[...]` (or any collection literal) passed as an argument to an already-`const` constructor.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic. When the immediate enclosing constructor is `const` (`const Column(...)`), the inner collection literal is auto-promoted to const by the Dart language. Adding an explicit `const` keyword is redundant and is correctly flagged by the standard analyzer as `unnecessary_const`. |
| **Actual** | `[prefer_const_literals_to_create_immutables]` fires, recommending an `const` addition that the standard analyzer then flags. The two rules form a no-win cycle. |

---

## AST Context

```
InstanceCreationExpression (Column)        — has `const` keyword (parent is const)
  └─ ArgumentList
      └─ NamedExpression (children:)
          └─ ListLiteral <Widget>[…]        ← reported here (incorrectly)
              └─ NodeList<Expression>
                  ├─ InstanceCreationExpression (CommonIconText)   ← isConst = true via context
                  └─ InstanceCreationExpression (CommonText)        ← isConst = true via context
```

The rule's logic at `widget_patterns_avoid_prefer_rules.dart:5219–5236`:

```dart
context.addInstanceCreationExpression((InstanceCreationExpression node) {
  final DartType? type = node.staticType;
  if (type is! InterfaceType) return;
  if (!_isImmutableType(type)) return;

  for (final Expression arg in node.argumentList.arguments) {
    final Expression expr = arg is NamedExpression ? arg.expression : arg;
    if (expr is ListLiteral &&
        expr.constKeyword == null &&            // ← only checks the list's own keyword
        _allElementsConst(expr.elements)) {
      reporter.atNode(expr);                    // ← fires regardless of parent's const-ness
    }
    // …same for SetOrMapLiteral
  }
});
```

The check `expr.constKeyword == null` only inspects the list literal's *own* `const` keyword. It does NOT check whether the list is *already* in a const context via the enclosing `InstanceCreationExpression`'s `const` keyword. That is the gap.

---

## Root Cause

### Flaw: rule does not check whether the parent constructor is already const

In Dart, a list literal inside a `const` constructor's argument list is implicitly const if all its elements are const. Adding an explicit `const` keyword changes nothing semantically and is flagged by the standard analyzer.

The rule's intent is to flag literals where adding `const` would *actually do something* — i.e., literals whose enclosing context is *not* already const. The detection should exempt literals nested in const contexts.

---

## Suggested Fix

Add a parent-walk that skips emission when the immediate enclosing `InstanceCreationExpression` is `const`:

```dart
context.addInstanceCreationExpression((InstanceCreationExpression node) {
  // … existing immutable-type check …
  // The rule's intent is to fix literals that AREN'T already const-promoted
  // by their enclosing context. If `node` itself is `const`, all collection
  // literals inside its argument list are auto-promoted by the language.
  if (node.isConst) return;

  for (final Expression arg in node.argumentList.arguments) {
    // … existing logic …
  }
});
```

`node.isConst` evaluates true when the `const` keyword is present on the constructor. That is precisely the condition under which the inner literal is auto-promoted and the rule should not fire.

This is a one-line fix (the `if (node.isConst) return;` guard).

---

## Fixture Gap

The fixture at `example*/lib/widget/prefer_const_literals_to_create_immutables_fixture.dart` should include:

1. **`Column(children: [const Text('a')])`** — non-const parent, all-const children — expect LINT (genuine case)
2. **`const Column(children: [Text('a')])`** — const parent, children auto-promoted — expect NO lint *(currently false positive)*
3. **`const Column(children: const [Text('a')])`** — explicit redundant const — separate `unnecessary_const` concern, but at minimum saropa rule should not fire either
4. **`const Padding(padding: EdgeInsets.zero, child: Column(children: [Text('a')]))`** — Column itself is non-const inside const Padding — expect LINT on Column's children (literal could be const)
5. **`Column(children: <Widget>[Text(someVar)])`** where `someVar` is non-const — expect NO lint (one element is not const)

Case 2 is the contacts case. Case 3 is adjacent and exposes the `unnecessary_const` interaction that breaks the rule's quick fix.

---

## Downstream

Tracked in `contacts/`. Once this report exists, the saropa_lints version of the rule is disabled at the project level via `analysis_options.yaml` (the standard analyzer's `prefer_const_literals_to_create_immutables` from `package:lints` remains enabled and handles the cases this version got wrong). All 9 sites in `lib/components/contact/companion/generate_contact_companion.dart` close immediately on disable.

---

## Environment

- saropa_lints version: 12.5.1+
- Dart SDK: 3.9.x
- Triggering project: `d:/src/contacts`
- Platform: Windows 11
