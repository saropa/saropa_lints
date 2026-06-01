# BUG: `avoid_large_list_copy` — `_isToListRequired` misses three structurally-required contexts: NamedExpression argument, BinaryExpression `??` fallback, PropertyAccess on the `.toList()` result

**Status: Fixed**

Created: 2026-06-01
Rule: `avoid_large_list_copy`
File: `lib/src/rules/core/performance_rules.dart` (line ~1916, `_isToListRequired`)
Severity: False positive
Rule version: v4 | Since: prior | Updated: v4

## Attribution (positive grep)

```
$ grep -rn "'avoid_large_list_copy'" lib/src/rules/
lib/src/rules/core/performance_rules.dart:1858:    'avoid_large_list_copy',
```

Rule lives in `saropa_lints`.

## Summary

The rule's `_isToListRequired` helper (line ~1916) decides whether the `.toList()` call's result is structurally required. The current implementation handles:

- `ReturnStatement`
- `ExpressionFunctionBody`
- `VariableDeclaration`
- `AssignmentExpression`
- `ArgumentList` (positional argument)
- `MethodInvocation` where `parent.target == current` (method chain)
- `CascadeExpression` (with target == current)
- `ParenthesizedExpression` / `ConditionalExpression` (climbed through)

It misses three common structurally-required contexts that fire false positives across the codebase:

### FP-1: Named argument (`children: x.map(...).toList()`)

In Dart AST, `children: x.toList()` parses as `NamedExpression(name: 'children:', expression: x.toList())`. The `.toList()` MethodInvocation's parent is the `NamedExpression`, not the `ArgumentList`. The current check `if (parent is ArgumentList) return true;` does not unwrap `NamedExpression` first.

```dart
// FIRES (false positive). children: takes List<Widget>, so a List is structurally required.
Column(
  children: items.map((i) => Text(i)).toList(),
)
```

### FP-2: Null-coalescing fallback (`x?.where(...).toList() ?? <T>[]`)

In Dart AST, `x.toList() ?? []` parses as `BinaryExpression(left: x.toList(), operator: '??', right: [])`. The `.toList()`'s parent is the `BinaryExpression`. The current `_isToListRequired` does not handle `BinaryExpression` at all — the climb-through loop only unwraps `ParenthesizedExpression` and `ConditionalExpression`.

```dart
// FIRES (false positive). Nullable chain with fallback list; result is structurally
// the same as a returned/assigned List.
final List<T> selected =
    source
        ?.where((T x) => predicate(x))
        .toList() ??
    <T>[];
```

### FP-3: PropertyAccess on the `.toList()` result (`x.toList().nonEmpty`)

In Dart AST, `x.toList().nonEmpty` parses as `PropertyAccess(target: x.toList(), propertyName: 'nonEmpty')` (or `PrefixedIdentifier` depending on form). The `.toList()`'s parent is a `PropertyAccess`, not a `MethodInvocation`. The current check `if (parent is MethodInvocation && parent.target == current) return true;` only handles method chains, not property/getter chains.

```dart
// FIRES (false positive). `.nonEmpty` extension getter is defined on List<T>;
// the .toList() is required to make it available.
children: items.map((i) => Tile(i)).toList().nonEmpty,
```

## Reproducer

All three patterns in one file:

```dart
class Reproducer extends StatelessWidget {
  final List<int>? source;

  @override
  Widget build(BuildContext context) {
    // FP-3: PropertyAccess
    final List<int> nonEmpty = source!.map((int i) => i + 1).toList().nonEmpty;

    return Column(
      // FP-1: NamedExpression argument
      children: source!.map((int i) => Text('$i')).toList(),
    );
  }

  // FP-2: Null-coalescing fallback
  List<int> get filtered =>
      source?.where((int i) => i > 0).toList() ?? <int>[];
}
```

All three lines trigger the lint today. None of them has a lazy alternative — they all need a concrete `List`.

## Suggested fix

In `_isToListRequired` at `lib/src/rules/core/performance_rules.dart:1916`:

1. **Add `NamedExpression` to the climb-through whitelist** (alongside `ParenthesizedExpression` / `ConditionalExpression`). A named argument is just a wrapper around an expression that is itself eventually an `ArgumentList` child — same rationale.

2. **Add a `BinaryExpression` short-circuit** for the `??` operator: if the `.toList()` is either operand of a `??` (left or right), the result of the binary expression goes wherever a List was structurally required, so treat as required. Conservative variant: only short-circuit when `operator.type == TokenType.QUESTION_QUESTION` AND the operand on the other side has list type. Aggressive variant: short-circuit on any `??` binary expression — the rule is INFO severity and FP avoidance matters more here.

3. **Handle `PropertyAccess` and `PrefixedIdentifier`**: if the `.toList()`'s parent is a `PropertyAccess` (or `PrefixedIdentifier`) whose target/prefix is the `.toList()` call, the property is being accessed on the concrete List — so the call is required for that property access to compile.

Rough sketch:

```dart
static bool _isToListRequired(MethodInvocation node) {
  AstNode current = node;
  AstNode? parent = current.parent;
  while (parent != null) {
    if (parent is CascadeExpression && parent.target == current) return true;

    // Add NamedExpression to the climb-through set.
    if (parent is ParenthesizedExpression ||
        parent is ConditionalExpression ||
        parent is NamedExpression) {
      current = parent;
      parent = parent.parent;
      continue;
    }
    break;
  }

  if (parent is ReturnStatement) return true;
  if (parent is ExpressionFunctionBody) return true;
  if (parent is VariableDeclaration) return true;
  if (parent is AssignmentExpression) return true;
  if (parent is MethodInvocation && parent.target == current) return true;
  if (parent is ArgumentList) return true;

  // New: any BinaryExpression containing the .toList() — the binary
  // expression's RESULT goes wherever a List was required, and ?? is the
  // dominant case (fallback list when source is null).
  if (parent is BinaryExpression) return true;

  // New: PropertyAccess / PrefixedIdentifier on the .toList() — the property
  // is defined on List, so the .toList() is required for the getter to compile.
  if (parent is PropertyAccess && parent.target == current) return true;
  if (parent is PrefixedIdentifier && parent.prefix == current) return true;

  return false;
}
```

## Fixture gap

Three new fixtures that should NOT fire:

```dart
// fixtures/avoid_large_list_copy_named_argument_ok.dart
Column(children: items.map((i) => Text(i)).toList());  // expect: no diagnostic

// fixtures/avoid_large_list_copy_null_coalesce_ok.dart
final List<int> selected = source?.where(p).toList() ?? <int>[];  // expect: no diagnostic

// fixtures/avoid_large_list_copy_property_access_ok.dart
final children = items.map((i) => Tile(i)).toList().nonEmpty;  // expect: no diagnostic
```

## Downstream impact

24 sites in `saropa/contacts` are all FP under one of these three patterns:

- **17 NamedExpression** (`children:`, etc.): `activity_day_grouped_list.dart:180+191`, `activity_list_widget.dart:245`, `activity_list_recent_phone_calls.dart:161`, `activity_view_phone_dialer.dart:415`, `hidden_notice_contact_list.dart:192`, `hidden_notice_country_list.dart:189`, `stale_shares_section.dart:161`, `choose_cartoon_avatar_dialog.dart:168`, `contact_status_and_contact_group_contact_list.dart:199`, `activity_details_widget.dart:238`, `contact_audit_panel.dart:530`, `calendar_event_detail_dialog.dart:170+448`, `nav_icon_list.dart:802`, `note_rows_list.dart:70`, `organization_panel.dart:197`
- **5 BinaryExpression `??`**: `connected_users_section.dart:100`, `group_share_picker.dart:150+159`, `multi_family_panel.dart:184+490`
- **2 PropertyAccess `.nonEmpty`**: `connected_users_section.dart:125`, `connection_pending_invitations_section.dart:181`

Each ignore carries a line-level rationale pointing at this bug.

## Finish Report (2026-06-01)

This work will be reviewed by another AI.

**Scope:** (A) Dart lint rules — `lib/src/rules/core/performance_rules.dart`, `example/lib/performance/avoid_large_list_copy_fixture.dart`, `CHANGELOG.md`.

### Change summary

Extended `AvoidLargeListCopyRule._isToListRequired` (performance_rules.dart ~line 1916) to recognize three structurally-required contexts that previously fired false positives:

1. **NamedExpression** added to the climb-through whitelist alongside `ParenthesizedExpression` / `ConditionalExpression`. A named argument (`children: x.toList()`) wraps the `ArgumentList`, where a concrete `List` is already required; unwrapping it lets the existing `ArgumentList` branch decide.
2. **BinaryExpression `??`** short-circuit, restricted to `TokenType.QUESTION_QUESTION`. `x.toList() ?? <T>[]` flows its result to wherever a `List` was required; both operands are List-typed. Restricting to `??` avoids silently exempting `==` and other operators.
3. **PropertyAccess / PrefixedIdentifier** on the `.toList()` result (`x.toList().nonEmpty`). The getter is defined on `List`, not `Iterable`, so the `.toList()` is required to compile. Guarded with `parent.target == current` / `parent.prefix == current` so only access *on* the result (not the result being some other node's property) qualifies.

The BAD path (bare `.toList()` on a lazy chain whose result is discarded) is unchanged and still fires.

### Deep review

- **Logic & safety:** All three additions are pure `is`-checks with identity guards on the relevant child slot; no recursion added beyond the existing climb loop (which still terminates on the first non-wrapper parent). The `??` branch reads `parent.operator.type`, safe on any `BinaryExpression`.
- **Linter integrity:** Rule stays in performance_rules.dart; `impact`/`cost`/`ruleType`/tier unchanged (behavior-narrowing fix, not a new rule). No quick fix applies — the correct action is to leave the required `.toList()` in place, so there is nothing to auto-fix.
- **Performance:** Added checks are O(1) per node, only reached after the existing `where`/`map`/`expand`/`skip` target gate, so hot-path cost is unchanged.
- **Refactoring:** None beyond scope.

### Testing

- Audited `test/rules/core/performance_rules_test.dart` and `test/integrity/false_positive_fixes_test.dart` — the only references are instantiation/presence pins and doc-comment mentions; none assert specific `toList` contexts, so none break.
- Ran `dart test test/rules/core/performance_rules_test.dart` → **99/99 pass**.
- Added three GOOD fixtures (`_good794h/i/j`) for named-argument, `??`-fallback, and `.nonEmpty`-getter cases.
- Verified via scan CLI on an isolated copy: only the discarded-result BAD case fired; all three new GOOD cases produced no `avoid_large_list_copy` diagnostic.
- `dart analyze` on the package → **No issues found**.

### Maintenance

- CHANGELOG: entry added under `[Unreleased] → Fixed`.
- README verified — no updates needed (rule count unchanged; FP-narrowing fix, not a new rule).
- pubspec: no dependency/release change.
- ROADMAP: no entry — this closes a false-positive bug, not a roadmap rule.
- guides reviewed.
- Bug archived: bugs/avoid_large_list_copy_false_positive_named_argument_null_coalesce_property_access.md → plans/history/2026.06/2026.06.01/avoid_large_list_copy_false_positive_named_argument_null_coalesce_property_access.md

### Outstanding work

None.
