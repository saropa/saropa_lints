# BUG: `prefer_static_method` — Never Detects Implicit (Unprefixed) Instance-Member Access, Only Explicit `this.`

**Status: Fixed**

Created: 2026-08-15
Rule: `prefer_static_method`
File: `lib/src/rules/architecture/structure_rules.dart` (line ~2007)
Severity: False positive
Rule version: v4 | Since: v0.1.4 | Updated: v4.13.0

---

## Summary

The rule's "does this method use instance state" check only recognizes an
explicit `ThisExpression` (`this.foo`). Dart idiomatic style — including this
entire codebase — reads instance fields and calls instance methods via bare
(unprefixed) identifiers (`_countsNotifier`, `_apply(...)`), which the
detector's `visitSimpleIdentifier` override is a documented no-op for. Any
method that touches instance state exclusively through bare identifiers, or
only inside a nested closure, is misdiagnosed as "could be static." Confirmed
false positive on ~13 of 17 firings across `lib/main.dart` and
`lib/components/main_layout/search/app_search_filter_menu.dart` (2 of the 17
were genuine true positives — already fixed by making those two methods
`static` — not part of this bug).

---

## Attribution Evidence

```bash
grep -rn "'prefer_static_method'" lib/src/rules/
# lib/src/rules/architecture/structure_rules.dart:2016:    'prefer_static_method',
```

**Emitter registration:** `lib/src/rules/architecture/structure_rules.dart:2016`
**Rule class:** `PreferStaticMethodRule` — registered in `lib/src/rules/all_rules.dart`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

Anonymized/trimmed from `lib/components/main_layout/search/app_search_filter_menu.dart`
(`_AppSearchFilterMenuState._openMenu`), preserving the exact structural shape
that fools the rule: an instance method whose only instance-state access is a
bare field reference inside a nested closure passed to a widget builder.

```dart
class _ExampleState extends State<ExampleWidget> {
  final ValueNotifier<Map<String, int>> _countsNotifier =
      ValueNotifier<Map<String, int>>(<String, int>{});

  // LINT — but should NOT lint: the method reads instance state
  // (`_countsNotifier`) via a bare identifier inside a nested closure.
  // No `this.` appears anywhere in the method, so the detector's only
  // recognized signal (ThisExpression) never fires.
  Future<void> _openMenu(BuildContext context) async {
    await showMenu<void>(
      context: context,
      position: RelativeRect.fill,
      items: <PopupMenuEntry<void>>[
        PopupMenuItem<void>(
          child: ValueListenableBuilder<Map<String, int>>(
            valueListenable: _countsNotifier, // instance field, bare identifier
            builder: (BuildContext _, Map<String, int> counts, Widget? _) =>
                Text('${counts.length}'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
```

**Frequency:** Always, for any method that reads/calls instance members via
bare identifiers instead of explicit `this.` — which is the dominant Dart
style, including every non-`this.`-prefixed field access in this codebase.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the method depends on instance state (`_countsNotifier`), just not written with an explicit `this.` prefix |
| **Actual** | `[prefer_static_method] Method does not reference any instance members and could be static.` reported at the method name token |

---

## AST Context

```
MethodDeclaration (_openMenu)                       ← context.addMethodDeclaration
  └─ body: BlockFunctionBody
      └─ ExpressionStatement (await showMenu<void>(...))
          └─ ... InstanceCreationExpression (PopupMenuItem)
              └─ NamedExpression (child:)
                  └─ InstanceCreationExpression (ValueListenableBuilder)
                      ├─ NamedExpression (valueListenable:)
                      │   └─ SimpleIdentifier (_countsNotifier)   ← instance field read;
                      │                                              visitSimpleIdentifier is a no-op, never sets usesThis
                      └─ NamedExpression (builder:)
                          └─ FunctionExpression                  ← nested closure; RecursiveAstVisitor
                                                                     descends into it by default, finds nothing
```

---

## Root Cause

`PreferStaticMethodRule._usesThisOrInstanceMembers` (`lib/src/rules/architecture/structure_rules.dart:2067-2075`)
delegates entirely to `_ThisUsageFinder`, a `RecursiveAstVisitor<void>` defined
at lines 2078-2098:

```dart
class _ThisUsageFinder extends RecursiveAstVisitor<void> {
  _ThisUsageFinder(this.onFound);
  final void Function() onFound;

  @override
  void visitThisExpression(ThisExpression node) {
    onFound();
    super.visitThisExpression(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    // Check if identifier refers to an instance member
    // This is a simplification - ideally we'd check the element
    final AstNode? parent = node.parent;
    if (parent is! PropertyAccess && parent is! PrefixedIdentifier) {
      // Could be an unqualified instance member reference
      // Full implementation would check if it resolves to instance member
    }
    super.visitSimpleIdentifier(node);
  }
}
```

`onFound()` is called from exactly one place: `visitThisExpression`. The
`visitSimpleIdentifier` override is a stub — its own comment ("Full
implementation would check if it resolves to instance member") documents that
it was never finished. It computes nothing and never calls `onFound()`.
Consequently:

1. **Bare-identifier instance access is invisible.** `_countsNotifier`,
   `_recomputeCounts()`, or any other unqualified read/call of an instance
   member never trips the detector, because Dart does not require (and this
   codebase does not use) an explicit `this.` prefix for instance access.
2. **The rule does have `usesTypeResolution => true`** (line 2011), so the
   element-resolution capability needed to fix this (checking
   `node.staticElement` for a class-instance-member owner, as the class doc
   comment above even alludes to) is already available and simply unused
   inside `_ThisUsageFinder`.
3. Nested closures compound the gap: `node.body.visitChildren(...)` at line
   2069 does recurse into `FunctionExpression` bodies (no override suppresses
   that), so instance-member reads inside a builder/callback ARE visited —
   but since `visitSimpleIdentifier` never signals anything regardless of
   nesting depth, the closure traversal makes no difference to the outcome.

---

## Suggested Fix

Replace the no-op `visitSimpleIdentifier` with a real check using the
resolved element (the rule already opts into `usesTypeResolution`):

```dart
@override
void visitSimpleIdentifier(SimpleIdentifier node) {
  final Element? element = node.staticElement ?? node.element;
  if (element is ExecutableElement && !element.isStatic) {
    final Element? enclosing = element.enclosingElement3;
    if (enclosing is InterfaceElement) {
      onFound();
    }
  }
  super.visitSimpleIdentifier(node);
}
```

This must also correctly skip the identifier's own declaration site and
non-member local variables/parameters — `node.staticElement` naturally
excludes locals (they resolve to `LocalVariableElement`/`ParameterElement`,
not a class member), so the type check above already handles that.

---

## Fixture Gap

The fixture at `example*/lib/architecture/prefer_static_method_fixture.dart` should include:

1. Method reading an instance field via bare identifier only inside a nested
   closure (`ValueListenableBuilder`/`StreamBuilder` builder callback) —
   expect NO lint
2. Method calling another instance method via bare identifier
   (`_helper()` instead of `this._helper()`) with no other instance-state
   access — expect NO lint
3. Method that truly touches no instance state anywhere, including nested
   closures — expect LINT (current true-positive case, must keep working)
4. Method using explicit `this.field` — expect NO lint (already correct today)

---

## Changes Made

`_ThisUsageFinder.visitSimpleIdentifier` (`lib/src/rules/architecture/structure_rules.dart`)
now resolves the identifier's element instead of being a no-op stub:

- Added `import 'package:analyzer/dart/element/element.dart'`.
- Skips identifiers that are the member name of an **explicit** qualified
  access (`x.member`, `x.method()`, or a `PrefixedIdentifier`'s right-hand
  side) — those are governed by their own target expression, not `this`. The
  suggested fix in this report's "Suggested Fix" section did not account for
  this: it flagged `values.fold(...)` as instance-member usage because
  `fold`'s resolved element is `List` (an `InterfaceElement`), even though
  `values` is a local variable — this had to be corrected during
  implementation to avoid a new false-negative (methods with only qualified
  calls on locals/params were wrongly treated as "uses instance state").
- For all other (bare) `SimpleIdentifier`s, flags as instance-member usage
  when the resolved element is a non-static `ExecutableElement` (covers both
  methods and field access, since bare field reads resolve to a synthetic
  `PropertyAccessorElement`) whose enclosing element is an `InterfaceElement`
  (the containing class/mixin).
- A second regression surfaced during review: a cascade section
  (`foo..bar()`) also parses with `target == null` on the inner
  `MethodInvocation`, identical in shape to a bare call — so
  `values..add(x)..add(y)` on a local would have been misread as instance
  access the same way `values.fold(...)` was. Fixed by also excluding
  `MethodInvocation.methodName` when the invocation is a cascade section
  (`target == null` and an ancestor `CascadeExpression` exists). Cascaded
  property access (`..field = x`) needed no separate fix — it was already
  excluded by the general `PropertyAccess.propertyName` check regardless of
  target.
- A third regression surfaced while writing an isolated resolved-analyzer
  regression test for `this..field = x` cascades: `SimpleIdentifier.element`
  only resolves a READ — a bare identifier used purely as a write target
  (`_field = x`) has a `null` element even though it plainly touches
  instance state, so it was silently invisible to every check above (both
  the original bug and this fix). `_field += x`, `_field++`, and `++_field`
  read AND write, so those happened to still resolve via the read path and
  were unaffected. Fixed by falling back to
  `AssignmentExpression.writeElement` / `PostfixExpression.writeElement` /
  `PrefixExpression.writeElement` (all `SetterElement`, an
  `ExecutableElement`) when `node.element` is `null` and the identifier is
  the write target of one of those three node types.

## Tests Added

Extended `example/lib/structure/prefer_static_method_fixture.dart` with a
`_ImplicitAccessState` class covering all four fixture-gap cases from this
report (bare field read inside a nested closure, bare instance method call,
a truly state-free method, explicit `this.field` access), plus the three
regression cases found during implementation: a state-free method calling
`values.fold(...)` on a local, one using cascaded calls
(`values..add(x)..add(y)`) on a local, and bare field write/increment
(`_count = 5`, `_count++`). Also added
`test/rules/architecture/prefer_static_method_resolved_test.dart`, a
resolved-analyzer regression suite (using the existing
`test/support/resolved_rule_harness.dart` oracle) isolating each of these
cases individually rather than relying only on the shared fixture file.
Verified via
`dart run saropa_lints scan example/lib/structure --tier comprehensive --resolve --format json`
(exactly the 4 expected lines fire), `dart test test/rules/architecture/structure_rules_test.dart`
and `dart test test/rules/architecture/prefer_static_method_resolved_test.dart`
(134/134 combined passed), and a re-scan of the original downstream repro
files (`D:/src/contacts/lib/main.dart` and
`.../app_search_filter_menu.dart`) confirming zero `prefer_static_method`
diagnostics remain (originally 17, 13 confirmed false positives).

## Commits

_Pending — not yet committed._

---

## Environment

- saropa_lints version: (repo HEAD at filing time)
- Dart SDK version: n/a
- custom_lint version: n/a
- Triggering project/file: downstream Flutter/Dart app (contacts), 17 occurrences
  across `lib/main.dart` and
  `lib/components/main_layout/search/app_search_filter_menu.dart` (13 false
  positive, 2 genuine and already fixed, 2 unclassified)

---

## Finish Report (2026-08-15)

`prefer_static_method`'s instance-usage detector recognized only an explicit
`this.` prefix; bare (unprefixed) reads of instance fields or calls to
instance methods — the dominant Dart style — went undetected, so any method
touching instance state only that way was wrongly flagged as "could be
static."

`_ThisUsageFinder.visitSimpleIdentifier` in
`lib/src/rules/architecture/structure_rules.dart` was rewritten to resolve
each identifier's element (the rule already opts into
`usesTypeResolution`). A bare identifier now signals instance-state usage
when its resolved element is a non-static `ExecutableElement` (methods, and
field reads via their synthetic `PropertyAccessorElement`) enclosed by an
`InterfaceElement`. Identifiers that are the member name of an *explicit*
qualified access (`x.member`, `x.method()`, a `PrefixedIdentifier`'s
right-hand side) are excluded, since their target — not `this` — determines
usage; the `ThisExpression` visitor already covers the `this.member` case
separately.

Three false-negative regressions were found and fixed during implementation
(none were in the original report's suggested fix):

1. `values.fold(...)` on a local resolves `fold`'s element to `List` (an
   `InterfaceElement`), so a naive "enclosing class is an InterfaceElement"
   check alone wrongly treated it as instance-state usage. Fixed by the
   explicit-qualified-access exclusion above.
2. A cascade section (`foo..bar()`) parses with `target == null` on the
   inner `MethodInvocation`, identical in AST shape to a bare call — so
   `values..add(x)..add(y)` on a local hit the same false-negative. Fixed by
   also excluding a `MethodInvocation.methodName` when the invocation is a
   cascade section (`target == null` with an ancestor `CascadeExpression`).
3. `SimpleIdentifier.element` only resolves a READ — a bare field WRITE
   (`_field = x`) has a `null` element and was silently invisible to every
   check above, both in the original bug and everywhere in this fix, until
   caught while writing an isolated regression test for `this..field = x`
   cascades. Compound assignment/increment (`_field += x`, `_field++`,
   `++_field`) read AND write, so those happened to already work via the
   read path. Fixed by falling back to the assignment/increment's own
   `writeElement` (a `SetterElement`, an `ExecutableElement`) when
   `node.element` is `null` and the identifier is the write target of an
   `AssignmentExpression`, `PostfixExpression`, or `PrefixExpression`.

`example/lib/structure/prefer_static_method_fixture.dart` gained an
`_ImplicitAccessState` class covering the four cases from the report's
"Fixture Gap" plus the three regression cases above, all pinned with
`expect_lint`/absence-of-lint. A parallel resolved-analyzer test suite,
`test/rules/architecture/prefer_static_method_resolved_test.dart`, isolates
each case individually using the existing `resolved_rule_harness.dart`
oracle. Verified with
`dart run saropa_lints scan example/lib/structure --tier comprehensive --resolve --format json`
(exactly the 4 expected lines fire), `dart test` on both
`structure_rules_test.dart` and the new resolved test file (134/134
combined passed), and a re-scan of the two files named in the original bug
report's downstream repro confirming zero `prefer_static_method`
diagnostics remain (originally 17, 13 confirmed false positives).
