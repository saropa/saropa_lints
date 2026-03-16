# Bug: `prefer_single_quotes` false positive on strings containing single quote characters

**Status:** Fixed (v7)
**Rule:** `prefer_single_quotes` (v6)
**Severity:** False positive — flags valid code where double quotes are the better choice
**Plugin version:** saropa_lints

## Problem

The rule flags **double-quoted strings that contain literal single quote characters** (e.g. SQL string literals like `'value'` or `''`). Converting these to single-quoted Dart strings requires `\'` escaping, which is less readable than the original double-quoted form.

The rule's own message says "to reduce visual noise in string literals" — but the suggested fix *increases* visual noise by introducing escape sequences.

## Reproduction

**File:** `lib/src/server/analytics_handler.dart`, line 365

```dart
await query(
  'SELECT COUNT(*) AS c FROM "$tableName" '
  "WHERE \"$colName\" = ''",
);
```

**Diagnostic output:**

```
[prefer_single_quotes] Double quotes detected where single quotes would suffice.
Prefer single quotes for consistency with Dart style conventions and to reduce
visual noise in string literals. {v6}
```

**The suggested single-quoted form would be:**

```dart
'WHERE "$colName" = \'\''
```

This is harder to read — the `\'\'` obscures the SQL empty-string literal `''`.

**File:** `lib/src/server/server_context.dart`, lines 435, 448, 454

```dart
return "'$escaped'";    // SQL string literal wrapping
return "X'$hex'";       // SQL hex literal
```

**The suggested single-quoted forms would be:**

```dart
return '\'$escaped\'';  // harder to read
return 'X\'$hex\'';     // harder to read
```

## Why this is wrong

1. **Double quotes are preferred when the string contains single quotes.** The Dart style guide (and common sense) recognizes that avoiding escape sequences improves readability. Using double quotes when the string contains `'` characters is idiomatic Dart.

2. **The rule's stated goal is contradicted by its suggestion.** The diagnostic says "reduce visual noise" but the fix adds `\'` escape sequences, which is more visual noise.

3. **SQL strings commonly contain single quotes.** SQL uses single quotes for string literals (`'value'`), empty strings (`''`), and hex literals (`X'FF'`). Any codebase with SQL generation will have many double-quoted strings for this reason.

## Expected behavior

The rule should NOT fire when:

- The double-quoted string contains literal single quote characters (`'`)
- Converting to single quotes would require adding escape sequences

## Suggested fix

Check whether the string body contains unescaped single quotes before flagging:

```dart
// Skip if the string contains single-quote characters
final content = node.stringValue ?? '';
if (content.contains("'")) {
  return;
}
```

## Impact

Any codebase that generates SQL, shell commands, or interacts with systems using single-quoted syntax will have many false positives. In `server_context.dart`, 3 out of 3 flagged instances are strings containing SQL single quotes. Following the lint's suggestion would make the code objectively less readable.
