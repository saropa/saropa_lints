# BUG: `avoid_money_arithmetic_on_double` — Fires on `*Rate` identifiers that are not financial

**Status: Open**

Created: 2026-04-28
Rule: `avoid_money_arithmetic_on_double`
File: `lib/src/rules/core/performance_rules.dart` (line ~3736)
Severity: False positive
Rule version: v3 | Since: v2.3.11 | Updated: v4.13.0

---

## Summary

The rule flags arithmetic on any `double` whose identifier ends in `Rate` (e.g. `flatRate`, `tailRate`, `frameRate`, `heartRate`, `growthRate`, `bitRate`, `sampleRate`, `multiplierRate`). These are not financial values. The rule's own docstring promises `frameRate` is exempt — the implementation does not honor that promise because `'rate'` is treated as a money word at the trailing camelCase segment.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_money_arithmetic_on_double'" lib/src/rules/
# lib/src/rules/core/performance_rules.dart:3753:    'avoid_money_arithmetic_on_double',

# Negative — rule is NOT in saropa_drift_advisor
grep -rn "'avoid_money_arithmetic_on_double'" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# (0 matches)
```

**Emitter registration:** `lib/src/rules/core/performance_rules.dart:3753`
**Rule class:** `AvoidMoneyArithmeticOnDoubleRule` (line 3736) — registered in `lib/saropa_lints.dart:2008`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` / `_generated_diagnostic_collection_name_#3`

---

## Reproducer

Real downstream site: `d:/src/contacts/lib/utils/contact/pet/pet_age_calculator.dart` lines 19 and 45. Pet age conversion (veterinary year multipliers), then rounded to `int`. Nothing financial anywhere in the call graph.

```dart
// Minimal reproduction — none of these are money
double convert(int humanAge, double flatRate) {
  return humanAge * flatRate;          // LINT (false positive) — `flatRate` ends in `rate`
}

double tail(int remaining, double tailRate) {
  return remaining * tailRate;         // LINT (false positive) — `tailRate` ends in `rate`
}

// All of these would also lint despite being clearly non-financial:
double frame(int frames, double frameRate) => frames / frameRate;     // LINT
double heart(int beats, double heartRate) => beats * heartRate;       // LINT
double sample(int n, double sampleRate) => n / sampleRate;            // LINT
double growth(double base, double growthRate) => base * growthRate;   // LINT

// The rule docstring explicitly claims this is exempt — it is not:
//   "Exempt: Operands are matched by camelCase word boundary;
//    names like totalWidth or frameRate are not flagged as financial."
```

**Frequency:** Always — any `double` identifier ending in `Rate` participating in `+ - * /` triggers the diagnostic.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic. `frameRate`, `flatRate`, `tailRate`, etc. are non-financial per the rule's own documented exemption. |
| **Actual** | `[avoid_money_arithmetic_on_double] Floating point arithmetic on double values introduces rounding errors in financial calculations. ...` reported on the binary expression. |

---

## AST Context

```
ClassDeclaration (PetAgeCalculator)
  └─ MethodDeclaration (calculateSpeciesAge)
      └─ Block
          └─ IfStatement
              └─ ReturnStatement
                  └─ MethodInvocation (.round())
                      └─ ParenthesizedExpression
                          └─ BinaryExpression (humanAge * flatRate)   ← reported here
                              ├─ SimpleIdentifier (humanAge)  type: int
                              └─ SimpleIdentifier (flatRate)  type: double
```

`flatRate.staticType?.element?.name == 'double'`, `_looksFinancial('flatRate')` returns `true` because `_splitIdentifier('flatRate') == ['flat', 'rate']`, `'rate'` is in `_moneyPatterns`, and `words.last == 'rate'`.

---

## Root Cause

`_moneyPatterns` (line ~3761) contains the bare token `'rate'`. The detection logic at line ~3812 returns `true` when a single money word appears as the trailing camelCase segment:

```dart
// Single money word at the end: price, itemCost, monthlyFee
if (moneyHits == 1 && words.isNotEmpty) {
  if (_moneyPatterns.contains(words.last)) return true;
}
```

`rate` is overwhelmingly non-financial in software identifiers: `frameRate`, `bitRate`, `sampleRate`, `heartRate`, `growthRate`, `flowRate`, `clickRate`, `errorRate`, `flatRate` (multiplier), `tailRate` (multiplier). The financial usages (`taxRate`, `interestRate`, `exchangeRate`) are also valid concerns, but they are the minority. Putting `rate` in the same trailing-suffix bucket as `price` / `cost` / `fee` is too broad.

Two failure modes compound:

1. **The implementation contradicts its own documentation.** The class docstring at line 3734 says `frameRate` is exempt. The trailing-suffix branch at line ~3813 makes that false.
2. **`rate` is not analogous to `price` / `cost` / `fee`.** The latter three are nearly always financial as standalone words. `rate` is not — it is a generic "per-unit" suffix used across physics, biology, networking, performance, animation, statistics, and finance.

### Hypothesis A: Drop `'rate'` from the single-suffix branch

Keep `'rate'` in `_moneyPatterns` so `taxRate` / `interestRate` / `exchangeRate` still trigger via the **two-money-word** branch (`tax`+`rate`, `interest`+`rate`... wait — `interest` and `exchange` aren't in the set). This hypothesis under-detects real money.

### Hypothesis B: Remove `'rate'` from `_moneyPatterns` entirely; require explicit financial qualifier

Money-rate identifiers are virtually always paired with another financial concept (`taxRate`, `discountRate`, `feeRate`). Rely on the financial qualifier word (`tax`, `discount`, `fee`) to trigger detection — `rate` itself adds no financial signal. This drops some real-money sites that use bare `rate` (e.g. just `double rate = 0.05`), but those are rare and ambiguous anyway.

### Hypothesis C: Add an explicit exclusion list of non-financial `*Rate` words

Words like `frame`, `bit`, `byte`, `sample`, `heart`, `growth`, `flow`, `click`, `error`, `flat`, `tail`, `birth`, `death`, `pulse` precede `Rate` non-financially. Keep `'rate'` in `_moneyPatterns` but reject when paired with these. Brittle — the list grows forever.

**Recommended fix: Hypothesis B.** Removing `'rate'` from `_moneyPatterns` is the cleanest. Real money-rate identifiers (`taxRate`, `interestRate`, `feeRate`) all carry an unambiguous financial word. The rule loses near-zero true positives and drops a large class of false positives in one change.

---

## Suggested Fix

`lib/src/rules/core/performance_rules.dart` line 3772:

```dart
// Remove 'rate' — too many non-financial uses (frameRate, heartRate,
// sampleRate, flatRate as multiplier). Real money-rate identifiers
// (taxRate, interestRate, feeRate) still trigger via their other
// money word ('tax', 'fee') — but 'interest' / 'exchange' may need
// to be added separately if we want full coverage of those.
```

Delete the `'rate',` line. Optionally add `'interest'` and `'exchange'` to recover `interestRate` / `exchangeRate` / `currencyExchange` detection via the two-word branch.

Also: if `frameRate` is meant to remain documented as exempt, the docstring claim must match the implementation after the fix. Verify and update the comment block at lines 3734–3735 if scope changes.

---

## Fixture Gap

The fixture at `example*/lib/core/avoid_money_arithmetic_on_double_fixture.dart` should include:

1. **`flatRate` / `tailRate` as multiplier on `double`** — expect NO lint (non-financial pet/conversion rate)
2. **`frameRate` / `bitRate` / `sampleRate` arithmetic** — expect NO lint (the docstring already promises `frameRate` is exempt; the fixture should enforce it)
3. **`heartRate` / `growthRate` / `flowRate` arithmetic** — expect NO lint (biology / physics)
4. **`taxRate` / `feeRate` arithmetic on `double`** — expect LINT (real financial rate, two money words)
5. **`interestRate` / `exchangeRate` arithmetic on `double`** — expect LINT IFF `'interest'` / `'exchange'` are added to `_moneyPatterns`; otherwise document as a known gap

---

## Changes Made

- Updated `AvoidMoneyArithmeticOnDoubleRule` in
  `lib/src/rules/core/performance_rules.dart`:
  - Removed bare `'rate'` from `_moneyPatterns`.
  - Added an inline rationale comment documenting why `*Rate` is too broad as
    a standalone financial signal.
- Expanded fixture `example/lib/performance/avoid_money_arithmetic_on_double_fixture.dart`:
  - Added **non-financial** `*Rate` examples (`frameRate`, `sampleRate`,
    `heartRate`, `growthRate`, `flatRate`, `tailRate`) marked as GOOD.
  - Added **financially qualified** rate examples (`taxRate`, `feeRate`) marked
    as BAD to preserve intended detections.

---

## Tests Added

- Fixture regression coverage added in
  `example/lib/performance/avoid_money_arithmetic_on_double_fixture.dart` for:
  - Non-financial `*Rate` arithmetic (should NOT lint)
  - Financial `taxRate` / `feeRate` arithmetic (should lint)

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: (whichever is pinned in `d:/src/contacts/pubspec.yaml` as of 2026-04-28)
- Dart SDK version: 3.x
- analysis_server_plugin: per saropa_lints `pubspec.yaml`
- Triggering project/file: `d:/src/contacts/lib/utils/contact/pet/pet_age_calculator.dart` (lines 19, 45)
