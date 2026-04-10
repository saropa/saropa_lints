# Bug Report: `require_currency_code_with_amount` — False Positive on Non-Monetary Aggregate Fields

## Diagnostic Reference

```json
[{
  "resource": "/D:/src/contacts/lib/views/connection/connection_screen.dart",
  "owner": "_generated_diagnostic_collection_name_#2",
  "code": "require_currency_code_with_amount",
  "severity": 2,
  "message": "[require_currency_code_with_amount] Money amount without currency information. Amounts without currency are ambiguous. Always pair amounts with currency codes. This monetary calculation can produce rounding errors that accumulate, causing financial discrepancies. {v2}\nAdd currency field (String currency or CurrencyCode enum) alongside amount. Verify the change works correctly with existing tests and add coverage for the new behavior.",
  "source": "dart",
  "startLineNumber": 747,
  "startColumn": 1,
  "endLineNumber": 762,
  "endColumn": 2,
  "modelVersionId": 52,
  "origin": "extHost1"
}]
```

---

## Summary

The `require_currency_code_with_amount` rule flags the private class `_ConnectionStats` because it contains a field named `total` of type `int`. The rule's regex pattern (`\b(price|amount|cost|total|balance|fee|charge|payment|salary|wage|rate)\b`) matches `total` and treats it as a monetary field. However, `_ConnectionStats` is a simple data class that holds **connection counts** (total connections, connected, pending, shared, stale) — it has absolutely nothing to do with money, currency, or financial calculations.

---

## The False Positive Scenario

### Flagged Code

`lib/views/connection/connection_screen.dart` — lines 747-762:

```dart
/// Data class for connection statistics.
class _ConnectionStats {
  const _ConnectionStats({
    this.total = 0,
    this.connected = 0,
    this.pending = 0,
    this.shared = 0,
    this.stale = 0,
  });

  final int total;
  final int connected;
  final int pending;
  final int shared;
  final int stale;
}
```

This is a private data class used exclusively to aggregate connection statistics for display in the `ConnectionScreen`. The fields are integer counts:

- `total` — total number of connections
- `connected` — number of active connections
- `pending` — number of pending invitations
- `shared` — number of shared contacts
- `stale` — number of stale/expired shares

There is no monetary value, no financial calculation, and no currency context. The word `total` is used in its general English sense of "sum/count" — not in a financial sense.

### How the Class Is Used

The `_ConnectionStats` instance is built by counting items from database queries and then displayed in stat chips on the connection management screen. The values are rendered as plain integer counts (e.g., "12 connected", "3 pending"). No formatting, no decimal places, no currency symbols.

---

## Why the Current Rule Is Wrong Here

The rule's problem message says:

> "Money amount without currency information. Amounts without currency are ambiguous. Always pair amounts with currency codes. This monetary calculation can produce rounding errors that accumulate, causing financial discrepancies."

Every part of this message is inapplicable:

1. **"Money amount"** — `total` is a connection count, not a money amount.
2. **"Amounts without currency are ambiguous"** — There is no ambiguity. An integer count of connections has no currency dimension.
3. **"Monetary calculation can produce rounding errors"** — The fields are `int`, not `double`. Integer arithmetic has no rounding errors.
4. **"Financial discrepancies"** — There is nothing financial about this class.

The correction message ("Add currency field alongside amount") would be nonsensical to follow — you cannot add a currency code to a class that counts social connections.

---

## Root Cause Analysis

The rule in `lib/src/rules/money_rules.dart` (lines 256-308) uses a regex-based heuristic to detect monetary fields:

```dart
static final RegExp _moneyFieldPattern = RegExp(
  r'\b(price|amount|cost|total|balance|fee|charge|payment|salary|wage|rate)\b',
  caseSensitive: false,
);
```

The detection algorithm:

1. Iterates over all `ClassDeclaration` nodes
2. Skips classes whose name contains `money` or `currency`
3. For each field, checks if the field name matches `_moneyFieldPattern`
4. If the field is a numeric type (`double`, `int`, `num`, `decimal`), sets `hasMoneyField = true`
5. Checks if any field name contains `currency` or `code` → sets `hasCurrencyField = true`
6. If `hasMoneyField && !hasCurrencyField`, reports the entire class

### The Problem: `total` Is Overly Broad

The word `total` is one of the most common field names in programming, used in countless non-monetary contexts:

- `totalConnections`, `totalUsers`, `totalItems` — counts
- `totalDuration`, `totalDistance` — measurements
- `totalScore`, `totalPoints` — game/fitness values
- `totalSteps`, `totalCalories` — health tracking
- `totalErrors`, `totalRetries` — system metrics

By matching on `total` alone, the rule produces false positives on a very large proportion of data classes in any non-trivial codebase.

### Secondary Issue: `int` Fields Flagged as Monetary

The rule flags `int` fields alongside `double` and `num`. While monetary values are occasionally stored as integers (cents), the vast majority of integer fields named `total` are simple counts. The rule's own problem message mentions "rounding errors" — which cannot occur with integer arithmetic. This suggests the rule was primarily designed for `double` fields but was broadened to `int` without adjusting the heuristic.

---

## Suggested Fixes

### Option A: Require Multiple Money-Signal Fields (Recommended)

A single field named `total` in a class full of count fields is weak evidence of monetary usage. Require **at least two** money-pattern fields, or require that the field name more specifically suggests money (e.g., `totalPrice`, `totalCost`, `totalAmount`):

```dart
// Stronger signal — class likely deals with money
class Invoice {
  final double total;
  final double taxAmount;  // Two money-pattern fields
}

// Weak signal — class likely deals with counts
class _ConnectionStats {
  final int total;     // Only one money-pattern field
  final int connected; // Other fields are clearly non-monetary
}
```

### Option B: Contextual Scoring Instead of Binary Matching

Instead of flagging on any single match, assign a confidence score based on multiple signals:

| Signal | Score |
|---|---|
| Field named `price`, `cost`, `amount` | +3 (strongly monetary) |
| Field named `total`, `balance`, `rate` | +1 (ambiguous) |
| Field type is `double` or `Decimal` | +2 |
| Field type is `int` | +0 (usually counts) |
| Class name contains `order`, `invoice`, `payment` | +3 |
| Class name contains `stats`, `count`, `metric` | -3 |
| Multiple money-pattern fields present | +2 |
| Class is private (prefixed `_`) | -1 (less likely API surface) |

Only flag when the score exceeds a threshold (e.g., 4+). This would correctly flag `Invoice { double total; double taxAmount; }` (score: 1+3+2+2 = 8) while skipping `_ConnectionStats { int total; int connected; }` (score: 1+0-3-1 = -3).

### Option C: Exclude `int`-Only Classes

If every numeric field in the class is `int`, the class almost certainly deals with counts rather than money. Only flag classes that have at least one `double`, `num`, or `Decimal` field:

```dart
// Flag: has double field — could be money
class PriceInfo {
  final double total;  // flagged
}

// Skip: all int fields — these are counts
class _ConnectionStats {
  final int total;     // not flagged
  final int connected;
}
```

### Option D: Exclude Classes With "Stats", "Count", or "Metric" in the Name

The rule already skips classes named `*money*` or `*currency*`. Extend the exclusion list:

```dart
// Add to the class-name skip list
if (className.contains('stats') ||
    className.contains('count') ||
    className.contains('metric') ||
    className.contains('summary') ||
    className.contains('tally')) {
  return;
}
```

### Option E: Remove `total` From the Pattern (or Make It a Compound-Only Match)

The word `total` alone is too ambiguous. Only match it when it appears as part of a compound monetary name:

```dart
// Match these (clearly monetary)
'totalPrice', 'totalCost', 'totalAmount', 'totalFee', 'totalCharge'

// Don't match these (ambiguous)
'total', 'totalCount', 'totalItems', 'totalConnections'
```

This could be implemented by checking if `total` is followed by another money keyword, or by replacing the `total` entry in the regex with more specific compound patterns.

---

## Patterns That Should NOT Be Flagged

| Class | Fields | Why Not Monetary |
|---|---|---|
| `_ConnectionStats { int total, connected, pending, shared, stale }` | `total` | Counts of social connections |
| `PaginationInfo { int total, page, pageSize }` | `total` | Count of items in a paginated list |
| `TestResults { int total, passed, failed, skipped }` | `total` | Count of test cases |
| `ScoreBoard { int total, wins, losses, draws }` | `total` | Count of games played |
| `HealthMetrics { int totalSteps, totalCalories }` | `total*` | Fitness counts |
| `NetworkStats { int totalRequests, totalErrors }` | `total*` | System metrics |

## Patterns That SHOULD Be Flagged

| Class | Fields | Why Monetary |
|---|---|---|
| `OrderSummary { double total, double taxAmount }` | `total`, `amount` | Financial transaction |
| `Invoice { double amount, double fee }` | `amount`, `fee` | Billing context |
| `CartItem { double price, int quantity }` | `price` | Product pricing |
| `PayrollEntry { double salary, double bonus }` | `salary` | Compensation |

---

## Current Workaround

The only option is to suppress the rule with an ignore comment:

```dart
// Connection counts — not monetary values
// ignore: require_currency_code_with_amount
class _ConnectionStats {
  ...
}
```

This is undesirable because:

- It suppresses a valid rule for an entire class, so if a genuinely monetary field were later added, it wouldn't be caught
- It adds noise to a simple, self-documenting data class
- The correction message makes no sense in context, which confuses developers encountering the warning

---

## Affected Files

| File | Lines | What |
|---|---|---|
| `lib/src/rules/money_rules.dart` | 256-259 | `_moneyFieldPattern` regex — `total` is too broadly matched |
| `lib/src/rules/money_rules.dart` | 267-308 | `runWithReporter` — no contextual analysis of whether fields are actually monetary |
| `lib/src/rules/money_rules.dart` | 286-295 | Numeric type check — treats `int` the same as `double`, but integer fields are overwhelmingly counts |
| `lib/src/rules/money_rules.dart` | 270-273 | Class-name skip list — only checks for `money`/`currency`, misses `stats`/`count`/`metric` |

---

## Priority

**High** — The word `total` is extremely common in non-monetary contexts. Any data class that aggregates counts (stats, summaries, pagination, test results, metrics) is likely to use a field named `total`. This makes the false positive rate for this rule very high across real-world codebases. The problem message's references to "rounding errors" and "financial discrepancies" are misleading when applied to integer count fields, which erodes developer trust in the linter.

The fix should focus on improving the heuristic's precision — either by requiring stronger evidence of monetary context (multiple money fields, `double` types, monetary class names) or by narrowing the `total` pattern to compound forms like `totalPrice`/`totalCost`.
