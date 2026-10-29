# BUG: `avoid_parameter_mutation` — Fires on functions whose documented contract is to update the passed model in place

**Status: Open**

Created: 2026-10-29
Rule: `avoid_parameter_mutation`
File: `lib/src/rules/code_quality/code_quality_variables_rules.dart` (class line ~501, `_checkFunction` line ~552)
Severity: False positive (design-intent pattern with no copy alternative at the call sites)
Rule version: v3 | Since: v4.2.0 | Updated: v14.0.5

---

## Summary

The rule reports every `param.field = value` assignment. Three groups of functions in the Saropa contacts app exist to update the passed model in place: their dartdoc says "in place", and every caller reads the mutated object afterward. The exemptions in the rule cover only Flutter render-object overrides and notifier-like types (lines 546-548, 763-772), so these functions are reported although mutation is their API.

---

## Attribution Evidence

```bash
grep -rn "'avoid_parameter_mutation'" lib/src/rules/
# lib/src/rules/code_quality/code_quality_variables_rules.dart:521:    'avoid_parameter_mutation',
grep -n "AvoidParameterMutationRule" lib/saropa_lints.dart
# lib/saropa_lints.dart:664:  AvoidParameterMutationRule.new,
```

**Rule class:** `AvoidParameterMutationRule`
**Diagnostic message:** `[avoid_parameter_mutation] Parameter object is being mutated. This modifies the caller's data. {v3}`

---

## Reproducer

Standalone, compiles with the Dart SDK. Real code: `lib/utils/contact_pre_processor/relationship_hygiene_state.dart:44-49`.

```dart
class Item {
  DateTime? favoriteAt;
  DateTime? emergencyAt;
}

/// Copies the marks of [loser] onto [winner] (in place; the caller keeps [winner]).
void inheritMarks(Item winner, Item loser) {
  winner.favoriteAt ??= loser.favoriteAt; // LINT (col 3) — API contract is in-place update
  winner.emergencyAt ??= loser.emergencyAt; // LINT
}

void main() {
  final Item a = Item();
  inheritMarks(a, Item()..favoriteAt = DateTime.now());
}
```

**Frequency:** Always, for every assignment through a non-collection, non-notifier parameter.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when the function's contract states in-place update (void return, doc comment says "in place") |
| **Actual** | One diagnostic per assigned field |

---

## AST Context

```
ClassDeclaration (RelationshipHygieneState)
  └─ MethodDeclaration (inheritMarks)   params: winner, loser
      └─ BlockFunctionBody
          └─ Block
              └─ TryStatement
                  └─ ExpressionStatement
                      └─ AssignmentExpression (winner.favoriteAt ??= loser.favoriteAt)  ← reported
                          └─ PrefixedIdentifier (winner.favoriteAt)
```

---

## Root Cause

- `code_quality_variables_rules.dart:542` registers `addMethodDeclaration`; `_checkFunction` (line 552) collects all parameter names.
- `_ParameterMutationVisitor.visitAssignmentExpression` (line 661) reports when `left is PrefixedIdentifier` and `_isMutableParameter(prefix.name, ...)` (line 730) is true (report at line 681).
- `_isMutableParameter` excludes only types in `_mutationByDesignTypeNames` (line 763: notifiers, sinks, controllers). A project model type is never excluded.
- The only method-level exemption is `_renderObjectOverrideMutationTargets` (render-object overrides). No signal for a documented mutator (void return plus "in place" in the dartdoc, or a name verb such as apply, restore, inherit, carry, merge).

---

## Why the code is correct

- Each function is the single place that performs one model update; callers (pre-processor pipeline, audit auto-fix with undo capture, gap-filler bulk remove) pass the live model on purpose and persist it afterward.
- A copy-returning variant would force every caller to replace the live object in lists, caches and Drift write paths. That is a design change, not a lint fix.
- The caller is never surprised: the dartdoc states the mutation.

---

## Affected project locations

- `lib/utils/contact_issues/contact_audit_auto_fix.dart:150-153` (`_restoreLinks`, 4 assignments)
- `lib/utils/contact_issues/contact_audit_auto_fix.dart:215,216,220` (`_removeDeprecated`)
- `lib/utils/contact_issues/contact_audit_auto_fix.dart:248,255` (`_applyUrls`)
- `lib/utils/contact_pre_processor/relationship_hygiene_state.dart:44-49` (`inheritMarks`), `:67,68,70,71` (`_mergeLinkFlags`)
- `lib/utils/contact/gap_filler/gap_filler_bulk.dart:96,100,104,108` (`removeTopic`, doc: "in place")
- `lib/utils/contact_issues/contact_audit_auto_fix_details.dart:130,138` (`restoreEmails`, `restorePhones`: dartdoc "Puts the [before] ... back", assigns `contact.emails` / `contact.phones`)
- `lib/utils/contact/native_contact_detail_write.dart:480,498,545,556` (mirror add and undo write `contact.phones` / `contact.emails` on the passed contact)

---

## Suggested Fix

Add a method-level exemption in `_checkFunction`: skip a parameter when the declaration returns `void` or `bool` and its doc comment contains "in place" or "mutates", or when the method name starts with `apply`, `restore`, `inherit`, `carry`, `merge`. Document the exemption in the rule dartdoc next to the render-object exemption.

---

## Fixture Gap

1. `/// Updates [m] in place.` `void apply(Model m) { m.x = 1; }` — expect NO lint.
2. `void apply(Model m) { m.x = 1; }` with no doc and a neutral name — expect LINT.
3. `bool restore(Model m, Snapshot s) { m.x = s.x; return true; }` — expect NO lint (name verb).
4. `void process(List<String> items)` index assignment — unchanged behavior.

---

## Environment

- saropa_lints version: 17.0.1-beta.2
- Dart SDK version: Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- Triggering project/file: Saropa contacts app, files listed above

## Status 2026-10-29

Fixed in 17.0.1-beta.4 (see CHANGELOG).
