# BUG: `avoid_variable_shadowing` — flags reused names in DISJOINT (sibling/sequential) scopes, not just nested shadowing

**Status: Fixed**

Created: 2026-06-06
Rule: `avoid_variable_shadowing`
File: `lib/src/rules/core/class_constructor_rules.dart` (line ~461, `_ShadowingChecker`)
Severity: False positive
Rule version: v3

---

## Summary

`avoid_variable_shadowing` is meant to flag a nested-scope declaration that
hides a name from an ENCLOSING scope. Its checker uses a single flat
`outerNames` set for the whole method/function body and never removes names
when a scope ENDS, so it also flags a name legitimately reused in a DISJOINT
sibling or sequential scope — two `for` loops in separate collection literals,
two separate `switch` cases, two sequential blocks. Those are not nested and do
not shadow anything.

## Attribution Evidence

```
$ grep -rn "'avoid_variable_shadowing'" lib/src/rules/
lib/src/rules/core/class_constructor_rules.dart:403:    'avoid_variable_shadowing',
```

`_ShadowingChecker` adds every declared name to one flat set and never pops on
scope exit:

```dart
class _ShadowingChecker extends RecursiveAstVisitor<void> {
  final Set<String> outerNames; // seeded with {methodName} + parameter names
  @override
  void visitDeclaredIdentifier(DeclaredIdentifier node) {
    final String name = node.name.lexeme;
    if (outerNames.contains(name)) {
      reporter.atNode(node);       // <-- fires for sibling-scope reuse too
    } else {
      outerNames.add(name);        // <-- never removed when the scope closes
    }
    super.visitDeclaredIdentifier(node);
  }
  // visitVariableDeclaration: same pattern
}
```

## Reproducer

```dart
Widget build(BuildContext context) {
  // Two SIBLING collection-for loops in separate map literals — disjoint
  // scopes, `level` in the second does not shadow the first.
  final Map<String, int> a = <String, int>{
    for (final E level in E.values) name(level): level.x,   // OK (first)
  };
  final Map<String, int> b = <String, int>{
    for (final E level in E.values) name(level): level.y,   // LINT (false positive)
  };
}

void open(String code) {
  switch (kind) {
    case Kind.a:
      final C? country = C.tryParse(code); // OK (first)
      use(country);
    case Kind.b:
      final C? country = C.tryParse(code); // LINT (false positive) — separate case scope
      use(country);
  }
}

// SHOULD STILL LINT — genuinely nested shadow:
void outer() {
  final int x = 1;
  if (cond) {
    final int x = 2; // LINT (correct) — inner block hides outer `x`
    use(x);
  }
}
```

## Expected vs Actual

| Shape | Expected | Actual |
|---|---|---|
| same loop var in two sibling collection-`for`s | OK | LINT |
| same local in two separate `switch` cases | OK | LINT |
| same var in two sequential blocks | OK | LINT |
| inner-block var hiding an outer var | LINT | LINT |

## Root Cause

Shadowing is a *nesting* relationship: an inner scope hides a name from an
enclosing scope that is still live. The checker models scope as a single
append-only name set for the entire body, so it cannot distinguish "nested
(still live)" from "sibling/sequential (already closed)". Any name reused
anywhere later in the same body is reported.

## Suggested Fix

Track scope as a STACK of name sets (push on entering a block / for-statement /
switch-case / function body, pop on exit). Flag a declaration only when the
name exists in a STILL-OPEN ENCLOSING frame, not in a sibling frame that has
already been popped. Seeding the method name + parameters into the outermost
frame is fine; the fix is the push/pop discipline for inner frames.

## Fixture Gap

Add fixtures: two sibling collection-`for`s reusing a loop var (no lint); the
same local in two separate switch cases (no lint); two sequential `for (int i…)`
loops (no lint); and keep a positive nested-block shadow (still lints).

## Affected sites in Saropa Contacts (inline-ignored pending this fix)

- `lib/views/connection/contact_prompted_message_screen.dart:779,783` — `level` in sibling `itemIcons`/`itemIconColors` map literals
- `lib/views/connection/contact_prompted_message_screen.dart:804,807` — `type` in sibling `itemIcons`/`itemIconColors` map literals
- `lib/utils/system/app_screen_open_extensions.dart:335` — `country` re-declared in a separate `switch` case (also declared in the EmergencyServiceList case)

---

## Finish Report (2026-06-06)

Fixed in `lib/src/rules/core/class_constructor_rules.dart` (`_ShadowingChecker`).

The checker already snapshot/restored its `outerNames` set around `ForStatement`,
`while`, `do`, if/else blocks, and closures — but it did NOT cover two scope
shapes, so names declared there leaked into disjoint sibling scopes:

1. **`ForElement`** — the collection-`for` (`for (x in …)` inside a list/set/map
   literal) is a distinct AST node from `ForStatement` and had no handler, so its
   loop variable leaked to a sibling literal.
2. **Switch cases without braces** — `visitBlock`'s save/restore only fires when a
   case wraps its statements in `{}`. A bare `case X: final c = …;` has no `Block`,
   so the declaration leaked to the next case.

### Changes

- Added a `_visitScoped(visit)` helper that snapshots `outerNames`, runs the
  visit, then restores — and routed `visitForStatement`/`visitWhileStatement`/
  `visitDoStatement` through it (no behavior change, removes the duplicated
  save/restore blocks).
- Added `visitForElement`, `visitSwitchCase`, `visitSwitchPatternCase` (Dart 3
  pattern cases), and `visitSwitchDefault` overrides that all use `_visitScoped`.
- Bumped the rule from `{v3}` to `{v4}` in the `LintCode` message and the dartdoc
  (`Updated: v13.12.2 | Rule version: v4`).

### Fixtures

Added to `example/lib/avoid_variable_shadowing_fixture.dart`:
`siblingCollectionForLoops()` (two map-literal `for`s reusing `level` — no lint)
and `separateSwitchCases()` (same local `country` in case-0 / case-1 / default —
no lint). Existing positive nested-shadow cases retained.

### Verification

`dart run saropa_lints scan` over the fixture (renamed off `_test.dart` so it is
not treated as a test file): the 4 genuine nested-shadow cases still lint
(`trueShadowingExample`, `nestedShadowingExample`, `nestedLoopShadowing`,
`mixedCaseExample` closure), and the two new sibling/switch-case groups produce
zero `avoid_variable_shadowing` diagnostics. `dart analyze` on the changed file is
clean in the edited region (the 2 pre-existing warnings at lines 1024/1109 are
unrelated and untouched).
