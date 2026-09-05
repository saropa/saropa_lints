# PROPOSAL: Auto-Fix for `prefer_sorted_equatable_props`

**Status: Open**

Created: 2026-09-05
Type: Quick fix for existing rule
Related rules: `prefer_sorted_equatable_props`

---

## Summary

Add an auto-fix for `prefer_sorted_equatable_props` that rewrites the `ListLiteral` contents of the `props` getter so its entries match the class's field declaration order. Filed as the follow-up quick-fix proposal referenced in the base rule's proposal (`proposal_prefer_sorted_equatable_props.md`, "Alternatives Considered").

---

## Detection

Triggered whenever `prefer_sorted_equatable_props` reports a violation — the fix operates on the same `ListLiteral` node the rule already identified as out of order, reusing its field-order extraction rather than re-deriving it.

---

## Proposed Behavior

Rewrite the `props` list's elements into declared field order, moving only the misordered entries and leaving everything else — including source formatting outside the list — untouched.

### Before

```dart
List<Object?> get props => [age, name, email]; // LINT
```

### After (fields declared as name, age, email)

```dart
List<Object?> get props => [name, age, email];
```

---

## Edge Cases

1. **Non-field entries** (method calls, `DeepCollectionEquality` wrappers, `...super.props` spreads, computed expressions) — left in their original positions; the fix only reorders plain field-identifier entries and never guesses a position for a derived expression.
2. **Missing fields** — out of scope; `list_all_equatable_fields` governs completeness, so the fix must not insert entries for fields absent from `props`, only reorder what is already present.
3. **Extra/duplicate entries** — left as-is at their original slot if not a plain field reference; only entries recognized as simple field identifiers participate in reordering.
4. **Multi-variable field declarations** (`final String a, b;`) — expected order follows source declaration order of each variable, consistent with the base rule.

---

## Alternatives Considered

None significant — the fix is a mechanical follow-up to an already-decided rule; no competing implementation approach was identified.

---

## Decision

Not yet decided.
