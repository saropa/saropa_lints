# BUG: `avoid_parameter_mutation` — flags field assignment on a shared domain-model parameter that the function exists to update

**Status: Fixed**

Created: 2026-10-29
Rule: `avoid_parameter_mutation`
File: `lib/src/rules/code_quality/code_quality_variables_rules.dart` (line ~501; visitor 657-719)
Severity: False positive
Rule version: v3 | Since: unknown | Updated: 17.0.1-beta.2

Related (different exemptions, closed): `plans/history/2026.10/2026.10.29/avoid_parameter_mutation_false_positive_draft_accumulator_handlers.md`, `.../2026.06.03/avoid_parameter_mutation_false_positive_value_notifier.md`.

---

## Summary

A function whose documented purpose is to record a user ruling on a model object that already lives inside a larger object graph (a contact owns the item; the contact is then persisted) assigns two timestamp fields on the parameter. Returning a copy cannot work: the copy would not be the instance the owning contact holds, so the later `save(contact)` would not persist it and the UI would not see it. The rule reports every field assignment.

---

## Attribution Evidence

```bash
grep -rn "'avoid_parameter_mutation'" lib/src/rules/
# lib/src/rules/code_quality/code_quality_variables_rules.dart:521:    'avoid_parameter_mutation',
```

**Rule class:** `AvoidParameterMutationRule` (`code_quality_variables_rules.dart:501`), registered in `lib/saropa_lints.dart:664`
**Diagnostic as seen in Problems panel:** `[avoid_parameter_mutation] Parameter object is being mutated. This modifies the caller's data. {v3}` (source: saropa_lints)

---

## Reproducer

Standalone pure Dart. Real code: `lib/utils/contact/contact_value_confirmation_utils.dart` lines 107-117 (`_stampRuling`) and 160-165 (rollback) in the Saropa contacts app.

```dart
class Item {
  DateTime? confirmedAt;
  DateTime? refutedAt;
}

class Contact {
  Contact(this.items);
  final List<Item> items;
}

enum Ruling { confirmed, refuted }

// The Item is owned by a Contact; the Contact is saved afterwards.
void stampRuling(Item item, Ruling ruling) {
  final DateTime now = DateTime.now();
  switch (ruling) {
    case Ruling.confirmed:
      item.confirmedAt = now; // LINT — but should NOT lint
      item.refutedAt = null; // LINT — but should NOT lint
    case Ruling.refuted:
      item.refutedAt = now; // LINT — but should NOT lint
      item.confirmedAt = null; // LINT — but should NOT lint
  }
}

void main() {
  final Item item = Item();
  final Contact contact = Contact(<Item>[item]);
  stampRuling(item, Ruling.confirmed);
  print(contact.items.single.confirmedAt != null); // true: the owner sees the change
}
```

**Frequency:** Always for field assignment on a non-notifier, non-`*Draft` parameter.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic for a `void` function whose name or doc says it applies state to the passed object (`stamp*`, `apply*`, `mark*`) |
| **Actual** | `[avoid_parameter_mutation]` at each assignment (project lines 112, 113, 115, 116, 163, 164 of `contact_value_confirmation_utils.dart`, column 9 / 5) |

---

## AST Context

```
ClassDeclaration (ContactValueConfirmationUtils)
  └─ MethodDeclaration (_stampRuling)  [returnType void]
      └─ BlockFunctionBody
          └─ SwitchStatement
              └─ SwitchCase
                  └─ ExpressionStatement
                      └─ AssignmentExpression (item.confirmedAt = now)   ← node reported here
                          └─ PrefixedIdentifier (item.confirmedAt)  prefix: item (parameter)
```

---

## Root Cause

`_checkFunction` (`code_quality_variables_rules.dart:554`) records every parameter name; `_ParameterMutationVisitor.visitAssignmentExpression` (line 674) reports `left is PrefixedIdentifier` when `_isMutableParameter(prefix.name, ...)` (line 730) is true. `_isMutableParameter` excludes only mutation-by-design types (notifiers, `_mutationByDesignTypeNames`). The v3 `isVoid` accumulator exemption (lines 559, 574-579) is limited to type names ending in `Draft|Builder|Accumulator|Collector|Buffer`. A domain model passed to a `void` function named as a state setter is neither.

---

## Why the code is correct

The in-memory model graph is the single source of truth for the UI and for the persistence call that follows. Replacing the item with a copy would leave the contact graph unchanged and lose the ruling. A rollback in the failure path (lines 163-164) restores the captured previous values for the same reason.

---

## Suggested Fix

Do not report when the enclosing function is `void` and every flagged assignment targets a parameter of the same type as the declaring class's domain model passed together with a persistence call in the same body, or add an opt-in config list `avoid_parameter_mutation: safe_methods:` (as `avoid_ignoring_return_values` has `safe_to_ignore`). Smallest option: exempt `void` methods whose name starts with `stamp`, `apply`, `mark`, `set`, `restore`, `rollback`.

---

## Fixture Gap

1. `void stampRuling(Item item, Ruling r) { item.confirmedAt = DateTime.now(); }` — expect NO lint after the fix.
2. `Item withRuling(Item item) { item.confirmedAt = DateTime.now(); return item; }` — expect LINT (non-void, returns the same instance).
3. `void rename(User user) { user.name = 'x'; }` — expect LINT (no name signal).

---

## Environment

- saropa_lints version: 17.0.1-beta.2
- Dart SDK version: Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- Triggering project/file: Saropa contacts app, `lib/utils/contact/contact_value_confirmation_utils.dart` (112, 113, 115, 116, 163, 164)

## Status 2026-10-29

Fixed in 17.0.1-beta.4 (see CHANGELOG).
