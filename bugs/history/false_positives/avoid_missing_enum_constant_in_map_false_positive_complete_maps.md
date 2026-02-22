# Bug: `avoid_missing_enum_constant_in_map` false positive on complete enum maps

## Summary

The `avoid_missing_enum_constant_in_map` rule flags map literals that include
**all** enum constants. The rule uses a heuristic (2-5 enum keys = flag) instead
of resolving the actual enum definition, so it cannot distinguish between
incomplete maps (true positive) and complete maps (false positive).

A secondary concern: the rule's correction message suggests using a switch
expression, but the rule itself does not detect the more fundamental issue --
that enum-keyed maps **inherently lack exhaustiveness checking** regardless of
whether all values are currently present. A dedicated `prefer_switch_over_enum_map`
rule (or a mode on this rule) would better serve that purpose.

## Severity

**False positive** (INFO severity) -- flags maps that already include every enum
constant. The problem message says "does not include all enum constants" which is
factually incorrect for these cases, eroding trust in the rule.

## Reproduction

### Minimal example (complete enum map, still flagged)

```dart
enum Status { active, inactive, pending }

// FLAGGED: avoid_missing_enum_constant_in_map
// But all 3 enum values ARE present
final Map<Status, String> labels = <Status, String>{
  Status.active: 'Active',
  Status.inactive: 'Inactive',
  Status.pending: 'Pending',
};
```

### Lint output

```
line:97:29 • [avoid_missing_enum_constant_in_map] Map literal keyed by enum
values does not include all enum constants. When a new enum value is added,
this map silently returns null for the missing key instead of producing a
compile-time error, leading to unexpected null values or fallback behavior
at runtime. {v3} • avoid_missing_enum_constant_in_map • INFO
```

## Real-world occurrence

Found in `saropa/lib/data/contact/contact_coach/groups/coach_static_data_relationship.dart`
at line 97 (`CouplesTherapistCoaches`):

```dart
enum CoachDifficultyEnum { Beginner, Intermediate, Advanced }

// FLAGGED -- but all 3 values are present
static const Map<CoachDifficultyEnum, CoachModel>
CouplesTherapistCoaches = <CoachDifficultyEnum, CoachModel>{
  CoachDifficultyEnum.Beginner: CoachModel(...),
  CoachDifficultyEnum.Intermediate: CoachModel(...),
  CoachDifficultyEnum.Advanced: CoachModel(...),
};
```

The enum has exactly 3 values (`Beginner`, `Intermediate`, `Advanced`) and all 3
are present in the map. The rule flags it because the heuristic fires on any
enum-keyed map with 2-5 entries without verifying completeness.

Every `Map<CoachDifficultyEnum, CoachModel>` in this file (and there are many)
is flagged despite being complete, producing dozens of false positives.

## Root cause

**File:** `lib/src/rules/code_quality_rules.dart`, lines 2559-2587
(`AvoidMissingEnumConstantInMapRule`)

The rule registers an `addSetOrMapLiteral` callback and uses a **name-based
heuristic** to detect enum-keyed maps:

```dart
context.registry.addSetOrMapLiteral((SetOrMapLiteral node) {
  if (!node.isMap) return;
  if (node.elements.isEmpty) return;

  String? enumTypeName;
  final Set<String> usedValues = <String>{};

  for (final CollectionElement element in node.elements) {
    if (element is MapLiteralEntry) {
      final Expression key = element.key;
      if (key is PrefixedIdentifier) {
        enumTypeName ??= key.prefix.name;
        if (key.prefix.name == enumTypeName) {
          usedValues.add(key.identifier.name);
        }
      }
    }
  }

  // Heuristic: 2-5 values = flag unconditionally
  if (enumTypeName != null &&
      usedValues.length >= 2 &&
      usedValues.length <= 5) {
    reporter.atNode(node, code);
  }
});
```

### Why this produces false positives

1. **No enum resolution**: The rule collects key names (`Beginner`,
   `Intermediate`, `Advanced`) but never resolves the `CoachDifficultyEnum`
   type to discover its actual constants. It cannot compare the used set
   against the defined set.

2. **Unconditional 2-5 heuristic**: Any map with 2-5 `EnumName.Value` keys
   is flagged regardless of completeness. This means:
   - A 3-value enum with all 3 keys present: **flagged** (false positive)
   - A 3-value enum with 2 keys present: **flagged** (true positive)
   - A 6-value enum with 5 keys present: **not flagged** (false negative)
   - A 1-value enum with 1 key present: **not flagged** (false negative)

3. **Problem message is misleading**: The message states "does not include all
   enum constants" -- this is factually wrong when all constants ARE present.

## Suggested fix

### Option A: Resolve the enum type (recommended)

Use the analyzer's type resolution to get the actual enum constants and compare:

```dart
context.registry.addSetOrMapLiteral((SetOrMapLiteral node) {
  if (!node.isMap) return;
  if (node.elements.isEmpty) return;

  // Resolve the map's key type from the static type
  final DartType? mapType = node.staticType;
  if (mapType is! InterfaceType) return;

  // Get the key type argument (Map<K, V> -> K)
  final List<DartType> typeArgs = mapType.typeArguments;
  if (typeArgs.isEmpty) return;

  final DartType keyType = typeArgs.first;
  final InterfaceElement? keyElement = keyType is InterfaceType
      ? keyType.element
      : null;

  // Only proceed if key type is an enum
  if (keyElement is! EnumElement) return;

  // Get all declared enum constants
  final Set<String> allConstants = keyElement.fields
      .where((FieldElement f) => f.isEnumConstant)
      .map((FieldElement f) => f.name)
      .toSet();

  // Get all used constants from map keys
  final Set<String> usedConstants = <String>{};
  for (final CollectionElement element in node.elements) {
    if (element is MapLiteralEntry) {
      final Expression key = element.key;
      if (key is PrefixedIdentifier) {
        usedConstants.add(key.identifier.name);
      }
    }
  }

  // Only flag if there are actually missing constants
  final Set<String> missing = allConstants.difference(usedConstants);
  if (missing.isNotEmpty) {
    reporter.atNode(node, code);
  }
});
```

This eliminates false positives entirely: only maps that are genuinely
incomplete get flagged.

### Option B: Add a separate `prefer_switch_over_enum_map` rule

The current rule tries to serve two purposes:

1. **Detect incomplete enum maps** (the name and message say)
2. **Encourage switch for exhaustiveness** (the correction message says)

These should be separate rules:

| Rule | Purpose | When it fires |
|------|---------|---------------|
| `avoid_missing_enum_constant_in_map` (fixed) | Detect actually incomplete maps | Map is missing 1+ enum constants |
| `prefer_switch_over_enum_map` (new) | Encourage switch expressions | Any enum-keyed map literal, complete or not |

The new rule would have a message like:

> **Problem:** "Enum-keyed map literal lacks compile-time exhaustiveness
> checking. When a new enum value is added, this map silently returns null
> instead of producing a compile-time error."
>
> **Correction:** "Use a switch expression instead of a map lookup.
> Switch expressions provide exhaustiveness checking, ensuring every enum
> value is handled at compile time."

This separates the concerns:
- `avoid_missing_enum_constant_in_map`: "Your map is wrong **right now**"
- `prefer_switch_over_enum_map`: "Your map works today but won't catch
  future enum additions at compile time"

### Option C: Add context to the problem message (minimum viable fix)

If enum resolution is too costly, at minimum fix the misleading message:

**Current (factually incorrect for complete maps):**
> "does not include all enum constants"

**Proposed:**
> "Map literal keyed by enum values may not include all enum constants and
> lacks compile-time exhaustiveness checking. Consider using a switch
> expression to ensure every enum value is handled."

This acknowledges uncertainty ("may not") and shifts focus to the
exhaustiveness argument, which is valid regardless of completeness.

## Test cases to add

```dart
enum Color { red, green, blue }
enum Status { active, inactive }

// Should NOT flag (all enum constants present)
final Map<Color, String> completeMap = <Color, String>{
  Color.red: 'Red',
  Color.green: 'Green',
  Color.blue: 'Blue',
};

// Should NOT flag (all enum constants present, 2-value enum)
final Map<Status, int> completeSmallMap = <Status, int>{
  Status.active: 1,
  Status.inactive: 0,
};

// SHOULD flag (missing Color.blue)
// expect_lint: avoid_missing_enum_constant_in_map
final Map<Color, String> incompleteMap = <Color, String>{
  Color.red: 'Red',
  Color.green: 'Green',
};

// SHOULD flag (missing Status.inactive)
// expect_lint: avoid_missing_enum_constant_in_map
final Map<Status, int> incompleteSmallMap = <Status, int>{
  Status.active: 1,
};

// Should NOT flag (not enum-keyed)
final Map<String, int> stringMap = <String, int>{
  'a': 1,
  'b': 2,
};

// Should NOT flag (empty map)
final Map<Color, String> emptyMap = <Color, String>{};
```

### Fixture update needed

The existing fixture at
`example_core/lib/code_quality/avoid_missing_enum_constant_in_map_fixture.dart`
has a `// TODO: Add compliant code` placeholder. The above test cases should
replace it.

Additionally, the existing "bad" example has the `expect_lint` annotation on the
enum declaration (line 112) rather than on the map literal (line 114). The
annotation should be on the map:

```dart
enum Status { active, inactive, pending }

// expect_lint: avoid_missing_enum_constant_in_map
final map = {Status.active: 'A', Status.inactive: 'I'}; // Missing pending
```

## Impact

Any codebase with complete enum-keyed maps containing 2-5 entries will see false
positives. Common patterns affected:

- **Static data tables**: `Map<EnumType, DataModel>` lookup tables (like the
  coach data in the real-world example above)
- **Display mappings**: `Map<EnumType, String>` for labels, descriptions
- **Configuration maps**: `Map<EnumType, Config>` for per-variant settings
- **Color/style mappings**: `Map<EnumType, Color>` for theme data

These are among the most common uses of enum-keyed maps, so the false positive
rate is likely high in practice. The current heuristic's upper bound of 5 means
larger enums escape detection entirely (false negatives), while smaller complete
enums are incorrectly flagged (false positives) -- the worst of both worlds.

## File references

- Rule: `lib/src/rules/code_quality_rules.dart` line 2541
- Fixture: `example_core/lib/code_quality/avoid_missing_enum_constant_in_map_fixture.dart`
- Tier: `lib/tiers/recommended.yaml`
