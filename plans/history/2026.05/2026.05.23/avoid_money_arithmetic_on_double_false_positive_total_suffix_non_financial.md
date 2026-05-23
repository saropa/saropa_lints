# BUG: `avoid_money_arithmetic_on_double` — fires on `*Total`-suffixed non-financial geometry (`trailingTotal * value`)

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

## Resolution

Implemented the primary suggested fix (the `total`-demotion mirroring the `rate`
precedent):

- `lib/src/rules/core/performance_rules.dart` — added
  `_weakMoneyPatterns = {'total'}`. `total` stays in `_moneyPatterns` so the
  two-money-word path still flags `totalPrice` / `invoiceTotal`, but the
  single-hit trailing-segment trigger now excludes weak words, so `trailingTotal`,
  `widthTotal`, `heightTotal`, `angleTotal`, and bare `total`/`cartTotal` no longer
  read as financial.
- `example/lib/performance/avoid_money_arithmetic_on_double_fixture.dart` — added
  the geometry no-lint cases, the `cartTotal` trade-off pin, and the
  `totalPrice`/`invoiceTotal` regression-guard lint cases.
- `CHANGELOG.md` — `[13.10.4]` Fixed entry.

**Trade-off accepted:** single-money-word totals (`cartTotal`, `orderTotal`,
`grandTotal`, bare `total`) now require a paired money word to fire — same trade
the `rate` fix accepted.

**Verification:** `dart analyze` clean. The scan CLI does not exercise this rule's
`double` detection (it resolves `staticType.element` differently from the
analysis-server plugin where the production hit occurred), so `_looksFinancial`
was verified by an exact standalone replication of the algorithm over all
bug-report and fixture identifiers — every false-positive name now returns
`false`, every true-positive name returns `true`.

Created: 2026-05-23
Rule: `avoid_money_arithmetic_on_double`
File: `lib/src/rules/core/performance_rules.dart` (line ~3765)
Severity: False positive
Rule version: v3 | Since: v2.3.11 | Updated: v4.13.0

---

## Summary

The rule flags `trailingTotal * value`, where `trailingTotal` is a sum of widget
slot **pixel widths** and `value` is an animation controller value (0.0–1.0). The
result is the animated reveal width of a swipe menu — pure layout geometry, no
money. It fires because `_looksFinancial('trailingTotal')` matches `total` as the
trailing camelCase word. `total` is a generic aggregation noun ("sum of"), not an
inherently financial word — exactly the same false-positive class the `*Rate`
exemption (v3, 2026-04-28) already addressed for `frameRate`/`sampleRate`.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
$ grep -rn "'avoid_money_arithmetic_on_double'" lib/src/rules/
lib/src/rules/core/performance_rules.dart:3782:    'avoid_money_arithmetic_on_double',

# Negative — rule is NOT in the sibling drift-advisor plugin/extension
$ grep -rn "avoid_money_arithmetic_on_double" ../saropa_drift_advisor/lib/ ../saropa_drift_advisor/extension/
# (0 matches; grep exit 1)
```

**Emitter registration:** `lib/src/rules/core/performance_rules.dart:3782` (LintCode)
**Rule class:** `AvoidMoneyArithmeticOnDoubleRule` — registered in `lib/saropa_lints.dart:2021`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` / `_generated_diagnostic_collection_name_#2`

---

## Reproducer

Minimal version of the real site
(`saropa/lib/components/primitive/menu/common_list_slide_menu.dart:466`):

```dart
Widget buildReveal(double slotWidth, int revealedCount, double animValue) {
  final double trailingTotal = slotWidth * revealedCount; // OK — width sum (left operand is not an identifier here)
  // LINT (false positive): geometry, not money. `trailingTotal` ends in "total".
  final double reveal = trailingTotal * animValue; // animated pixel width 0..trailingTotal
  return SizedBox(width: reveal);
}
```

Other non-financial `*Total` sums that hit the same path:

```dart
double widthTotal = 0;
double heightTotal = 0;
double angleTotal = 0;
double _a = widthTotal * scale;   // LINT (false positive)
double _b = heightTotal / 2.0;    // LINT (false positive)
double _c = angleTotal + delta;   // LINT (false positive)
```

**Frequency:** Always — any binary arithmetic where an operand identifier ends in `total` (or is exactly `total`) and either operand is `double`.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — `trailingTotal` is a UI pixel-width aggregate, not currency |
| **Actual** | `[avoid_money_arithmetic_on_double]` reported on `trailingTotal * value` at line 466:41 |

---

## AST Context

```
ClassDeclaration (_CommonListSlideMenuState)
  └─ MethodDeclaration (build)
      └─ ... AnimatedBuilder builder closure (FunctionExpression)
          └─ Block
              └─ IfStatement (value > 0)
                  └─ Block
                      └─ VariableDeclarationStatement
                          └─ VariableDeclaration (reveal)
                              └─ BinaryExpression (trailingTotal * value)   ← reported here (op '*')
                                   ├─ leftOperand:  SimpleIdentifier (trailingTotal)  ← _looksFinancial('trailingTotal') == true
                                   └─ rightOperand: SimpleIdentifier (value)          ← not financial
```

---

## Root Cause

`_looksFinancial(String identifier)` (lines ~3830–3848) returns true when a single
money word is the **trailing** camelCase segment:

```dart
// Single money word at the end: price, itemCost, monthlyFee
if (moneyHits == 1 && words.isNotEmpty) {
  if (_moneyPatterns.contains(words.last)) return true;
}
```

`_splitIdentifier('trailingTotal')` → `['trailing', 'total']`. `total` is in
`_moneyPatterns` (line 3794) and is `words.last`, so the trailing-segment branch
returns true. The left operand resolves to `double`, so the rule reports.

The defect is treating `total` as a strong financial word. Unlike `price`, `cost`,
`fee`, `salary`, or `invoice` — which are inherently monetary — `total` is a generic
aggregation noun meaning "sum of <whatever the leading words name>". The leading
words here (`trailing`, `width`, `height`, `angle`) are non-financial dimensions,
so the aggregate is non-financial. This is the identical mechanism the maintainers
already recognized for `rate`: the comment at line 3801–3802 notes "most *Rate
identifiers (frameRate, sampleRate, heartRate) are non-financial in practice" and
removed `rate` from `_moneyPatterns`. `total` as a trailing/standalone word has the
same problem.

Note the existing exemption only protects `total` as a **leading** word: `totalWidth`
→ `['total','width']`, `words.last == 'width'` (not a money word) → exempt. But the
mirror image, `widthTotal` / `trailingTotal` (`total` trailing), is NOT exempt. The
rule is asymmetric about the exact same concept.

### Related history

- `plans/history/2026.04/2026.04.28/avoid_money_arithmetic_on_double_false_positive_rate_suffix_non_financial.md`
- `plans/history/2026.02/20260216/avoid_money_arithmetic_on_double_false_positive_non_financial_variable_names.md`

---

## Suggested Fix

Primary (mirrors the `rate` precedent): demote `total` from a standalone/trailing
money word. Keep it only as a **corroborating** word — i.e., it counts toward the
`moneyHits >= 2` path but does not on its own make a single-word identifier
financial. Concretely, exclude `total` from the `moneyHits == 1 && words.last`
trailing-segment trigger (and from the bare-`total` standalone case), the same way
`rate` was removed.

```dart
// In _moneyPatterns, mark generic aggregation words that are only financial
// when paired with a true money word. `total` alone is overwhelmingly a
// non-financial sum (trailingTotal, widthTotal, angleTotal). Mirrors the
// `rate` decision (frameRate/sampleRate are non-financial).
static const Set<String> _weakMoneyPatterns = <String>{'total'};

// In _looksFinancial: a single hit only qualifies if it is NOT a weak word.
if (moneyHits == 1 && _moneyPatterns.contains(words.last)
    && !_weakMoneyPatterns.contains(words.last)) {
  return true;
}
```

**Trade-off (maintainer decision):** demoting `total` means single-money-word
financial totals — `cartTotal`, `orderTotal`, bare `total` — stop being flagged
unless a second money word is present (e.g. `totalPrice`, `invoiceTotal`). The
prior `rate` fix accepted the analogous trade-off (`taxRate`/`feeRate` still fire
only because the *other* operand, `amount`, is money). If the project wants
`cartTotal`-style names kept, the alternative is a leading-segment dimension
blocklist (`trailing`, `width`, `height`, `angle`, `offset`, `count`, `duration`,
`size`, `extent`) that exempts `<dimension>Total` while leaving `cartTotal` flagged
— more code, more brittle. Recommend the `total`-demotion to match the established
`rate` pattern.

---

## Fixture Gap

The fixture at `example/lib/performance/avoid_money_arithmetic_on_double_fixture.dart`
should add, alongside the existing `*Rate` cases:

1. **`trailingTotal * value`** — geometry pixel width — expect NO lint
2. **`widthTotal * scale`**, **`heightTotal / 2.0`**, **`angleTotal + delta`** — non-financial aggregates — expect NO lint
3. **`totalPrice * quantity`** / **`invoiceTotal - discount`** — `total` paired with a real money word — expect LINT (regression guard for the `moneyHits >= 2` path)
4. (If `cartTotal`-style single-word totals are intentionally kept after the fix, add a `cartTotal * 1.0` case with the chosen expectation so the trade-off is pinned by a test.)

---

## Environment

- saropa_lints version: 13.10.4
- Dart SDK version: (Flutter stable, project `saropa/contacts`)
- custom_lint version: n/a — saropa_lints runs as a native `analysis_server_plugin`
- Triggering project/file: `saropa/lib/components/primitive/menu/common_list_slide_menu.dart:466`
