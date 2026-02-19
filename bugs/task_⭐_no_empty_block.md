# Task: `no_empty_block`

## Summary
- **Rule Name**: `no_empty_block`
- **Tier**: Recommended
- **Severity**: WARNING
- **Status**: Planned (⚠️ MAY ALREADY EXIST — see Notes)
- **Source**: ROADMAP.md §1.61 Code Quality Rules
- **Priority**: ⭐ Next in line for implementation

## ⚠️ CRITICAL: Pre-Implementation Check Required

The project MEMORY file explicitly states:

> `no_empty_block` already exists in `unnecessary_code_rules.dart` — check before implementing

**Before doing any work**, run:
```
Grep for "no_empty_block" in lib/src/rules/
```
If found, this ROADMAP entry should be deleted immediately and the task file archived. The implementation may already be complete and just not removed from ROADMAP.

If the existing rule is a different `no_empty_block` from a different package (e.g., `dart_code_metrics`), then this is a NEW rule that overlaps. Investigate before proceeding.

## Problem Statement

Empty blocks (`{}` with no statements, no comments) typically indicate one of:
1. **Unfinished implementation** — placeholder that was never completed
2. **Dead code** — a branch that should have been removed
3. **Intentional no-op** — rare, and should be documented with a comment

An empty `catch {}` block silently swallows exceptions. An empty `if {}` block suggests a logic error. Empty constructors and methods should be arrow-bodied or removed.

## Description (from ROADMAP)

> Empty blocks indicate missing implementation or dead code.

## Trigger Conditions

Detect `Block` AST nodes (`{ }`) that:
1. Contain zero statements AND
2. Are NOT preceded by a `// ignore:` or comment explaining the intent (e.g., `// intentionally empty`)

### Block Types to Check
- `catch {}` — **highest priority**, silently swallows exceptions
- `if (...) {}` — logic error indicator
- `else {}` — remove the else branch
- `while (...) {}` — infinite no-op loop
- `for (...) {}` — loop that does nothing
- Method body `void method() {}` — unless it's an abstract/override with intent
- Constructor body `MyClass() {}` — should be `: super()` or removed

### Exemptions
- `abstract` methods — no body at all (no block)
- Test file `setUp() {}` / `tearDown() {}` — intentional no-op when setup is not needed
- `@override` methods with empty body indicating "do nothing" — should have a comment
- Empty `main() {}` in examples — debatable

## Implementation Approach

### AST Visitor Pattern

```dart
context.registry.addBlock((node) {
  if (node.statements.isNotEmpty) return;
  if (_hasIntentComment(node)) return;
  if (_isExemptContext(node)) return;
  reporter.atNode(node, code);
});
```

`_hasIntentComment`: check for inline comments inside the block or immediately preceding it using `node.leftBracket.precedingComments` and `node.rightBracket.precedingComments`.

`_isExemptContext`: check if the block is:
- Abstract method body (impossible — abstract has no body)
- In a generated file (`.g.dart`, `.freezed.dart`)
- Test `setUp`/`tearDown` callbacks
- A `noSuchMethod` override returning `super.noSuchMethod(invocation)` ... actually that's not empty

### Detecting Intent Comments
```dart
bool _hasIntentComment(Block node) {
  // Check inline comments between { }
  Token? token = node.leftBracket.next;
  while (token != null && token != node.rightBracket) {
    if (token.precedingComments != null) return true;
    token = token.next;
  }
  return false;
}
```

## Code Examples

### Bad (Should trigger)
```dart
// Empty catch — silently swallows exception
try {
  riskyOperation();
} catch (e) {}  // ← trigger

// Empty if branch — logic error
if (condition) {}  // ← trigger

// Empty method — unfinished implementation
void handleError() {}  // ← trigger

// Empty constructor — just clutter
MyWidget() {}  // ← trigger
```

### Good (Should NOT trigger)
```dart
// Intentional no-op with comment
try {
  riskyOperation();
} catch (e) {
  // Intentionally ignored — this exception is expected in X scenario
}

// Empty method with TODO comment
void handleError() {
  // TODO(developer): implement error handling
}

// Override with explicit intent
@override
void dispose() {
  // Parent handles all cleanup; no additional disposal needed
  super.dispose();
}
```

## Edge Cases & False Positives

| Scenario | Expected Behaviour | Notes |
|---|---|---|
| `catch (e) { rethrow; }` | **Suppress** — not empty | `rethrow` is a statement |
| Empty `test('description', () {})` | **Trigger** — test body should have assertions | Unless it's a placeholder |
| Empty `setUp(() {})` | **Suppress** — intentional no-op is common | Check function name context |
| Empty `main() {}` in example file | **Suppress** | Generated example stubs |
| Empty `@override void didUpdateWidget(...)` | **Trigger** — if overriding with nothing, remove the override | High false positive risk |
| `void onPressed() {}` in Widget → intentional "do nothing" button | **Trigger** — should have a comment | Users will need to add comments to suppress |
| Abstract interface method with `{}` body | **Suppress** — not possible in abstract, but extension types can have `{}` | Check context |
| Generated files | **Suppress** | `.g.dart`, `.freezed.dart` |
| Mixin with empty override body | **Trigger** | Should have comment |
| `noSuchMethod(Invocation i) {}` — swallowing all method calls | **Trigger** with higher priority | This is particularly dangerous |
| Empty function expression `() {}` in argument position | **Trigger** if it's the only expression and serves no purpose | But NOT if it's a deliberate no-op callback (`onPressed: () {}` is common!) |

## Unit Tests

### Violations
1. `catch (e) {}` → 1 lint
2. `if (condition) {}` → 1 lint
3. `void method() {}` (non-abstract, non-test) → 1 lint
4. Empty for loop `for (var i = 0; i < 10; i++) {}` → 1 lint

### Non-Violations
1. `catch (e) { // intentionally ignored\n }` → no lint
2. `catch (e) { log(e.toString()); }` → no lint
3. `void setUp() {}` in test file → no lint (or configure)
4. Generated file → no lint
5. `if (condition) { break; }` → no lint (not empty)

## Quick Fix

Offer "Add a comment to document intent":
```dart
catch (e) {
  // ignore: intentionally empty
}
```

Or for empty methods, offer "Add // TODO comment":
```dart
void handleError() {
  // TODO: implement
}
```

## Notes & Issues

1. **⚠️ MAY ALREADY EXIST** — Check `lib/src/rules/unnecessary_code_rules.dart` for existing `no_empty_block` implementation before doing anything. If it exists, delete the ROADMAP entry and close this task.
2. **`onPressed: () {}`** is a VERY common Flutter pattern for "disable the button" — if we trigger on empty function expressions passed as arguments, the false positive rate will be extremely high. Consider NOT checking empty function expression arguments.
3. **Empty test bodies** are common when TDD practitioners write the test structure first — be careful about triggering in test files.
4. **Existing Dart lint**: Dart's built-in `empty_catches` lint already flags empty catch blocks. This rule would extend it to all block types. Verify we're not purely duplicating it.
5. **The `_hasIntentComment` logic** needs careful token traversal — Flutter's token model has preceding comments accessible via `token.precedingComments`. The block's content tokens need checking properly.
