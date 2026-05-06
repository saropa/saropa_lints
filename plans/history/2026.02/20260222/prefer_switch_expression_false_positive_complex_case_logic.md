# Bug: `prefer_switch_expression` false positive on switch with complex logic inside case branches

## Resolution

**Fixed.** Rewritten to reject cases with multiple statements, control flow (`if`/`for`/`while`/`try`/`do`), and non-exhaustive switches with post-switch code.

## Summary

The `prefer_switch_expression` rule incorrectly flags a `switch` statement as
convertible to a switch expression when one or more `case` branches contain
logic beyond a simple return or assignment. Specifically, it flags a switch where
a `case` branch contains an `if` statement with conditional logic, which cannot
be directly expressed in a Dart switch expression without significant
restructuring.

## Severity

**False positive** -- the rule claims "Switch statement with only return/assignment
detected" when the switch actually contains control flow logic (an `if` statement)
inside one of its branches. The suggested switch expression would either be
incorrect or require extracting the logic into a separate helper, which is a
non-trivial refactor beyond what the rule's quick-fix message suggests.

## Reproduction

### Minimal example

```dart
String pluralize(num? count, {bool simple = false}) {
  if (isEmpty || count == 1) return this;
  if (simple) return '${this}s';

  final String lastChar = lastChars(1);
  // FLAGGED: prefer_switch_expression
  //          "Switch statement with only return/assignment detected"
  switch (lastChar) {
    case 's':
    case 'x':
    case 'z':
      return '${this}es';
    case 'y':
      // This case has LOGIC, not just a return:
      if (length > 2 && this[length - 2].isVowel()) return '${this}s';
      return '${substringSafe(0, length - 1)}ies';
  }

  final String lastTwo = lastChars(2);
  if (lastTwo == 'sh' || lastTwo == 'ch') return '${this}es';
  return '${this}s';
}
```

### Why this cannot be a simple switch expression

The `case 'y':` branch contains an `if` statement with two possible return
values. A switch expression requires each case to evaluate to a single
expression. To convert this, you would need:

```dart
// Attempted conversion -- the 'y' case needs a nested ternary or helper:
return switch (lastChar) {
  's' || 'x' || 'z' => '${this}es',
  'y' => (length > 2 && this[length - 2].isVowel())
      ? '${this}s'
      : '${substringSafe(0, length - 1)}ies',
  _ => /* but there's MORE logic after the switch! */
};
```

Problems with this conversion:

1. **The switch is NOT exhaustive** -- there's code after the switch that handles
   remaining cases (`sh`, `ch`, and the default). A switch expression must be
   exhaustive or have a `_` default, but the post-switch code would need to be
   folded into the default case, changing the method's structure significantly.

2. **The `'y'` case becomes a nested ternary**, which violates the
   `avoid_nested_conditional_expressions` lint rule -- one lint fix would
   trigger another lint violation.

3. **The `if` statement in the `'y'` case** represents meaningful branching
   logic (vowel check before 'y') that is clearer as an `if` statement than
   as a ternary expression.

### Lint output

```
line 1050 col 5 • [prefer_switch_expression] Switch statement with only
return/assignment detected. Using statement syntax for simple value mapping
adds unnecessary boilerplate (break statements, case keywords) and makes
the code more verbose and harder to scan. {v5}
```

### Affected location (1 instance)

| File                                | Line | Method      | Complex case                                              |
| ----------------------------------- | ---- | ----------- | --------------------------------------------------------- |
| `lib/string/string_extensions.dart` | 1050 | `pluralize` | `case 'y':` contains `if` statement with two return paths |

## Root cause

The rule detects that every `case` branch ends with a `return` statement and
concludes the switch is a "simple value mapping." However, it does not check
whether any case branch contains **control flow statements** (like `if`, `for`,
`while`) that make it more than a simple single-expression mapping.

### Likely detection gap

The rule probably checks:

- Does every case end with `return` or an assignment? → Yes
- Is there a default case or does control flow after the switch? → (not checked)

It does NOT check:

- Does any case contain **multiple statements**?
- Does any case contain **conditional logic** (`if`/`else`)?
- Is the switch **non-exhaustive** with post-switch code?

### What makes a switch "expression-convertible"

A switch statement can be cleanly converted to a switch expression only when:

1. Every case maps to a **single expression** (no `if`/`else`, no multi-statement logic)
2. The switch is **exhaustive** (covers all values, or the result is the only
   thing the function computes)
3. There is no **code after the switch** that depends on non-matched cases
   falling through

## Suggested fix

Add checks for complex case bodies before flagging:

```dart
void checkSwitchStatement(SwitchStatement node) {
  for (final member in node.members) {
    if (member is SwitchCase) {
      final statements = member.statements;

      // Skip if case has multiple statements (complex logic)
      if (statements.length > 1) return; // Do not flag

      // Skip if case body contains if/for/while/try
      for (final stmt in statements) {
        if (stmt is IfStatement ||
            stmt is ForStatement ||
            stmt is WhileStatement ||
            stmt is TryStatement) {
          return; // Do not flag -- complex logic in case
        }
      }
    }
  }

  // Also check: is there code after the switch statement?
  // If yes, the switch is non-exhaustive and harder to convert
  final parent = node.parent;
  if (parent is Block) {
    final stmtIndex = parent.statements.indexOf(node);
    if (stmtIndex < parent.statements.length - 1) {
      // There are statements after the switch -- non-exhaustive
      // conversion would require restructuring
      return; // Do not flag (or flag with lower severity)
    }
  }

  // ... existing flagging logic for simple switches
}
```

## Test cases to add

```dart
// Should NOT flag (false positives to fix):

// Case with if statement (multiple return paths)
String example1(String c) {
  switch (c) {
    case 'a':
      return 'alpha';
    case 'b':
      if (someCondition) return 'bravo1';
      return 'bravo2';
    default:
      return 'other';
  }
}

// Non-exhaustive switch with post-switch code
String example2(String c) {
  switch (c) {
    case 'x':
      return 'ex';
    case 'y':
      return 'why';
  }

  return c.toUpperCase();  // fallthrough for other cases
}

// Case with multiple statements
String example3(String c) {
  switch (c) {
    case 'a':
      final processed = c.toUpperCase();
      return processed + '!';
    default:
      return c;
  }
}

// Should STILL flag (true positives, no change):

// Pure value mapping (all cases are single return expressions)
String example4(int n) {
  switch (n) {
    case 1:
      return 'one';
    case 2:
      return 'two';
    default:
      return 'other';
  }
}

// Simple fall-through cases with single returns
String example5(String vowel) {
  switch (vowel) {
    case 'a':
    case 'e':
    case 'i':
    case 'o':
    case 'u':
      return 'vowel';
    default:
      return 'consonant';
  }
}
```

## Impact

Any switch statement that combines simple cases with one or more complex cases
(containing `if` logic, multiple statements, or early returns) will be falsely
flagged. This is common in:

- Grammar/linguistic processing (pluralization, article selection)
- Parsers with special-case handling
- State machines where most transitions are simple but some have guards
- Enum-to-value mappings where certain values require computation
