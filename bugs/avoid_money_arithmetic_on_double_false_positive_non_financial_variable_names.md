# Bug: `avoid_money_arithmetic_on_double` false positive on non-financial variables containing money-related substrings

## Rule

`avoid_money_arithmetic_on_double` in `lib/src/rules/performance_rules.dart` (line 3547)

## Severity

**High** — This is a systematic false positive that affects any `double` arithmetic where a variable name contains a substring matching the money pattern set (`total`, `rate`, `balance`, etc.), regardless of whether the calculation is financial.

## Summary

The rule flags all `double` arithmetic operations where either operand's variable name contains a substring from `_moneyPatterns`. Because it uses `name.contains(pattern)` (substring match) rather than whole-word or semantic analysis, it produces false positives on common non-financial variable names like `estimatedTotalWidth`, `totalHeight`, `totalCount`, `frameRate`, `scrollRate`, `balanceForce`, etc.

The word "total" alone appears routinely in UI layout, animation, counting, and measurement contexts that have nothing to do with money.

## Triggering Code (false positive)

```dart
// Animation reveal width — pure UI layout math
final double reveal = estimatedTotalWidth * _animationController.value;
```

**File:** `lib/components/primitive/menu/list_slide_menu.dart`, line 158

This multiplies a pixel width by an animation controller value (0.0–1.0) to calculate a reveal offset. There is no financial calculation, no currency, no rounding concern. The lint flags it because `estimatedTotalWidth` contains the substring `total`.

### Lint output

```
line 158 col 39 • [avoid_money_arithmetic_on_double] Floating point arithmetic
on double values introduces rounding errors in financial calculations. For
example, 0.1 + 0.2 yields 0.30000000000000004 instead of 0.3. This causes
users to see incorrect totals, be charged wrong amounts, and produces
accounting discrepancies that compound over multiple transactions and are
difficult to trace. {v3}
• avoid_money_arithmetic_on_double • WARNING
```

## Other examples that would false-positive

```dart
// UI layout — total width of a row of buttons
final double totalWidth = buttonWidth * buttonCount.toDouble();

// Animation — total progress across multiple phases
final double totalProgress = phase1Duration + phase2Duration;

// Scroll physics — total scroll distance
final double totalOffset = scrollRate * elapsedTime;

// Game physics — total force calculation
final double totalForce = mass * acceleration;

// Statistics — total sample count as percentage
final double totalRatio = totalCount / sampleSize;

// Audio — sample rate conversion
final double outputRate = inputRate * resampleFactor;

// Battery / sensor — charge balance
final double balanceLevel = rawBalance * calibrationFactor;

// Flexbox layout
final double totalFlex = flexA + flexB;
```

None of these are financial calculations. They are flagged because they contain substrings like `total`, `rate`, or `balance`.

## Root cause

**File:** `lib/src/rules/performance_rules.dart`, lines 3567–3614

The rule uses **substring matching** against a set of money-related keywords:

```dart
static const Set<String> _moneyPatterns = <String>{
  'price', 'cost', 'amount', 'total', 'subtotal', 'tax',
  'discount', 'balance', 'payment', 'fee', 'rate', 'salary',
  'wage', 'revenue', 'profit', 'expense', 'budget', 'invoice',
};

// ...
final String name = (node.leftOperand as SimpleIdentifier).name.toLowerCase();
isMoney = _moneyPatterns.any((pattern) => name.contains(pattern));
```

The `name.contains(pattern)` check means:

| Variable Name | Matched Pattern | Is Financial? | Flagged? |
|---|---|---|---|
| `price` | `price` | Likely yes | Yes |
| `estimatedTotalWidth` | `total` | No (UI width) | Yes |
| `totalHeight` | `total` | No (UI height) | Yes |
| `totalCount` | `total` | No (counting) | Yes |
| `frameRate` | `rate` | No (FPS) | Yes |
| `scrollRate` | `rate` | No (scroll) | Yes |
| `balanceForce` | `balance` | No (physics) | Yes |
| `costFunction` | `cost` | No (math/ML) | Yes |
| `taxiDistance` | `tax` | No (travel) | Yes |
| `feeDBias` | `fee` | No (arbitrary) | Yes |
| `profitMarginWidget` | `profit` | Maybe | Yes |
| `amountOfPixels` | `amount` | No (pixels) | Yes |

The pattern `rate` is particularly problematic — `frameRate`, `scrollRate`, `animationRate`, `sampleRate`, `bitRate`, `refreshRate`, `playbackRate` are all common non-financial doubles.

The pattern `total` is equally problematic — `totalWidth`, `totalHeight`, `totalCount`, `totalItems`, `totalDuration`, `totalProgress`, `totalOffset` are ubiquitous in UI code.

### Why substring matching is insufficient

Substring matching conflates **domain-specific financial terms** with **general English words** that happen to appear as substrings. The word "total" means "sum of all parts" in any domain — not exclusively finance. Similarly, "rate" means "ratio per unit" in physics, audio, networking, animation, etc.

The rule has no mechanism to distinguish:
- `totalPrice` (financial — multiply is dangerous) from `totalWidth` (UI — multiply is expected)
- `exchangeRate` (financial) from `frameRate` (rendering)
- `accountBalance` (financial) from `colorBalance` (image processing)

## Suggested fix

### Option A: Whole-word boundary matching (recommended, minimal change)

Replace substring matching with word-boundary matching. Split the variable name into camelCase/snake_case segments and check if any segment exactly matches a money pattern:

```dart
static final RegExp _wordBoundary = RegExp(r'[A-Z_]');

bool _containsMoneyWord(String identifier) {
  // Split camelCase and snake_case: "estimatedTotalWidth" → ["estimated", "total", "width"]
  final List<String> words = identifier
      .replaceAllMapped(_wordBoundary, (Match m) => ' ${m.group(0)}')
      .toLowerCase()
      .split(RegExp(r'[_ ]+'))
      .where((String w) => w.isNotEmpty)
      .toList();

  // Require the money word to stand alone, not be a substring
  return words.any((String word) => _moneyPatterns.contains(word));
}
```

This still flags `totalPrice` (words: `total`, `price` — both match) but skips `estimatedTotalWidth` because although `total` matches, the variable must also have a **second** money word or contextual indicator to be considered financial. See Option B for the multi-word refinement.

However, even with whole-word matching, `totalWidth * factor` would still match on `total` alone. To truly fix the false positive rate, the rule needs either:
- A **required pair** of money words (e.g., `total` + `price`), or
- A **non-money exclusion list** for compound words

### Option B: Require financial context (two money words OR money suffix)

Only flag when the variable name suggests a financial value — either by containing two money-related words, or by having a money word as the final (most semantically significant) segment:

```dart
bool _looksFinancial(String identifier) {
  final List<String> words = _splitIdentifier(identifier);

  // Count money-word hits
  final int moneyHits = words.where(
    (String w) => _moneyPatterns.contains(w),
  ).length;

  // Two or more money words: "totalPrice", "discountAmount", "taxRate"
  if (moneyHits >= 2) return true;

  // Single money word at the END of the name: "price", "itemCost", "monthlyFee"
  // The trailing word is the semantic "type" in camelCase naming convention
  if (moneyHits == 1 && _moneyPatterns.contains(words.last)) return true;

  // "total" alone without financial suffix → not financial
  // e.g., "totalWidth", "totalCount", "totalDuration"
  return false;
}
```

This approach:
- Flags `price * quantity` — `price` is the trailing (semantic) word
- Flags `totalPrice * discount` — two money words
- Flags `taxRate * amount` — both operands have trailing money words
- Skips `estimatedTotalWidth * animationValue` — `total` is mid-word, `width` is the trailing semantic word, and `width` is not financial
- Skips `totalCount * scaleFactor` — `total` is not trailing, `count` is not financial
- Skips `frameRate * elapsed` — `rate` is trailing but `frameRate` is not financial (could add a non-financial compound exclusion set)

### Option C: Add non-financial compound exclusion list

Maintain a set of known non-financial compound words that happen to contain money substrings:

```dart
static const Set<String> _nonFinancialCompounds = <String>{
  'totalwidth', 'totalheight', 'totalcount', 'totalduration',
  'totaloffset', 'totalprogress', 'totalitems', 'totalsize',
  'framerate', 'scrollrate', 'samplerate', 'bitrate', 'refreshrate',
  'animationrate', 'playbackrate', 'heartrate',
  'colorbalance', 'whitebalance', 'balanceforce',
  'costfunction', 'taxidistance',
};
```

**Not recommended** as the sole fix — maintaining an exclusion list is fragile and will never be complete. Better as a supplementary optimization on top of Option A or B.

### Recommendation

**Option B** provides the best precision. The camelCase naming convention in Dart makes the trailing word highly indicative of the variable's semantic type. A variable ending in `Width`, `Height`, `Count`, `Duration`, `Offset`, or `Progress` is almost certainly not financial, even if it contains `total` or `rate` earlier in the name. A variable ending in `Price`, `Cost`, `Fee`, `Amount`, or `Tax` almost certainly is financial.

## Test cases to add

```dart
// Should NOT flag (false positives to fix):

// UI layout dimensions
double totalWidth = columnWidth * columnCount.toDouble();
double totalHeight = rowHeight * rowCount.toDouble();
double estimatedTotalWidth = avgWidth * itemCount.toDouble();

// Animation calculations
double reveal = estimatedTotalWidth * animationController.value;
double totalProgress = phase1 + phase2;
double totalOffset = velocity * time;

// Frame/render rate
double frameRate = frames / elapsed;
double scrollRate = distance / duration;
double sampleRate = samples / seconds;
double playbackRate = speed * baseRate;

// Counting
double totalCount = groupA + groupB;
double totalItems = listA.length + listB.length.toDouble();

// Physics / sensors
double totalForce = mass * acceleration;
double balanceAngle = rawAngle * correctionFactor;

// Duration
double totalDuration = fadeIn + holdTime + fadeOut;

// Substring trap: "tax" inside "taxi"
double taxiDistance = speed * tripDuration;


// Should STILL flag (true positives, no change):

// Actual financial calculations
double totalPrice = unitPrice * quantity;
double discountAmount = price * discountRate;
double taxAmount = subtotal * taxRate;
double totalCost = itemCost + shippingFee;
double monthlyPayment = principal * interestRate;
double accountBalance = previousBalance + deposit - withdrawal;
double invoiceTotal = lineItems + tax;
```

## Impact

Any Flutter/Dart codebase performing `double` arithmetic on variables with names containing `total`, `rate`, `balance`, `amount`, `cost`, `fee`, or `tax` as substrings will see false positives. These are extremely common variable names in:

- **UI layout code**: `totalWidth`, `totalHeight`, `totalFlex`, `totalOffset`
- **Animation code**: `totalProgress`, `totalDuration`, `animationRate`
- **Audio/media**: `sampleRate`, `bitRate`, `playbackRate`
- **Game/physics**: `totalForce`, `totalMass`, `balancePoint`
- **Statistics**: `totalCount`, `totalItems`, `totalSamples`
- **Networking**: `totalBytes`, `transferRate`, `totalPackets`

The rule's problem message — "causes users to see incorrect totals, be charged wrong amounts" — does not apply to any of these contexts. Flagging them erodes developer trust in the rule and encourages blanket `// ignore:` suppression, which hides legitimate financial calculation violations.
