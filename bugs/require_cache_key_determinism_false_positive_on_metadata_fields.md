# Bug: `require_cache_key_determinism` false positive on metadata fields in cache model constructors

## Summary

The `require_cache_key_determinism` rule fires a false positive when a DB/cache model constructor is assigned to a variable ending with `key` (or formerly containing `cache`) and any constructor argument contains a non-deterministic value — even when that argument is a metadata field (e.g., `createdAt: DateTime.now()`) that has no involvement in cache key derivation.

The rule cannot distinguish between arguments that form the cache key identity and arguments that are purely metadata on the same object. This is a design-level gap: the `_checkForNonDeterministicValues` method scans ALL constructor arguments indiscriminately.

## Severity

**Medium** — ERROR-level false positive on legitimate cache-population code. Forces developers to restructure valid code or add ignore comments, eroding trust in the rule.

## Affected Rule

- **Rule**: `require_cache_key_determinism`
- **File**: `lib/src/rules/error_handling_rules.dart` (lines 1635-1899)
- **Detection path**: Check 1 — variable name pattern matching (lines 1747-1765) into `_checkForNonDeterministicValues` (lines 1830-1883)

## Reproduction

### Triggering code (from `contacts` project)

File: `lib/service/wikipedia/wikipedia_api_search_utils.dart` (lines 110-119)

```dart
final WikipediaArticleDBModel newCacheEntry = WikipediaArticleDBModel(
  searchValue: topArticle.locationName,      // deterministic
  wikiSearchTypeName: topArticle.wikiSearchType?.name, // deterministic
  articleDetail: topArticle.description,     // deterministic
  pageUrl: topArticle.pageUrl,              // deterministic
  imageUrl: topArticle.imageUrl,            // deterministic
  searchUrl: topArticle.searchUrl,          // deterministic
  dataSource: 'wikipedia',                  // deterministic
  createdAt: DateTime.now(),                // <-- triggers the lint
);
```

IDE error reported:
```
Cache key may be non-deterministic. Use stable identifiers for cache keys.
[require_cache_key_determinism]
```

### Why the lint is wrong here

The `WikipediaArticleDBModel` class (in `lib/database/isar/schema/system_data/wikipedia_article_db_model.dart`) derives its cache key (`locationKey`) solely from `searchValue`:

```dart
WikipediaArticleDBModel({
  required this.searchValue,
  // ... other fields ...
  this.createdAt,
}) {
  locationKey = generateSearchValueKey(searchValue: searchValue);
}
```

The `createdAt` field is row metadata — a timestamp recording when the cache entry was created. It plays no role in cache key identity, lookup, or uniqueness. The `locationKey` (the actual cache key) is deterministic: it's derived from `searchValue` via `generateSearchValueKey()`, which normalizes the string to lowercase with underscores.

## Root Cause

### Issue 1: Variable name matching may be stale or overly broad

The current Check 1 (line 1747-1752) only matches variables ending with `'key'`:

```dart
if (!varName.endsWith('key')) return;
```

The variable `newCacheEntry` does NOT end with `key`, so this check should skip it. The fact that the lint fires suggests either:
- The analysis server is running a cached/older version of the rule that used `.contains('cache')` instead of `.endsWith('key')` (the code comment at line 1751 references `newCacheEntry` as an excluded case, suggesting this was a known issue that was supposedly fixed)
- There is an additional detection path not visible in the current source

### Issue 2: `_checkForNonDeterministicValues` treats all constructor args equally

Even if the variable name detection is fixed, the deeper design flaw remains. When a variable DOES end with `key` and its initializer is a constructor call, `_checkForNonDeterministicValues` (lines 1836-1856) iterates ALL constructor arguments:

```dart
if (expression is InstanceCreationExpression) {
  for (final Expression arg in expression.argumentList.arguments) {
    if (arg is NamedExpression) {
      if (_debugOnlyParameters.contains(arg.name.label.name)) {
        continue; // Only skips 'debugLabel' and 'debugName'
      }
      if (_containsNonDeterministicValue(arg.expression)) {
        reporter.atNode(reportNode, code);  // Flags the whole declaration
        return;
      }
    }
    // ...
  }
}
```

This means any constructor call with a metadata timestamp triggers the lint, even when the timestamp is irrelevant to caching:

```dart
// This would trigger the lint if variable ends with 'key'
final cacheKey = MyCacheEntry(
  key: stableId,               // the actual key — deterministic
  createdAt: DateTime.now(),   // metadata — non-deterministic but irrelevant
);
```

### Issue 3: Only `debugLabel`/`debugName` are excluded

The `_debugOnlyParameters` set (line 1678-1681) contains only:
```dart
static const Set<String> _debugOnlyParameters = <String>{
  'debugLabel',
  'debugName',
};
```

Common metadata parameter names like `createdAt`, `updatedAt`, `timestamp`, `expiresAt`, and `ttl` are not excluded. These are standard metadata fields that are never part of a cache key's identity.

### Issue 4: Error is reported on the entire declaration, not the offending argument

When `_checkForNonDeterministicValues` finds a non-deterministic argument, it reports at `reportNode` (the entire variable declaration), not at the specific argument containing `DateTime.now()`. This makes it harder for developers to understand which argument is problematic. Compare with Check 2 (API-based detection at line 1785) which correctly reports at `keyArg`.

## Proposed Fix

### Fix 1: Add metadata parameter exclusions

Extend `_debugOnlyParameters` or add a parallel `_metadataParameters` set:

```dart
/// Parameters that store metadata about cache entries, not cache key identity.
/// Non-deterministic values are acceptable here since they don't affect
/// cache lookup or uniqueness.
static const Set<String> _metadataParameters = <String>{
  'createdAt',
  'updatedAt',
  'modifiedAt',
  'lastAccessed',
  'lastModified',
  'timestamp',
  'expiresAt',
  'expiry',
  'ttl',
};
```

Then update `_checkForNonDeterministicValues` at line 1840:

```dart
if (arg is NamedExpression) {
  final String paramName = arg.name.label.name;
  if (_debugOnlyParameters.contains(paramName)) continue;
  if (_metadataParameters.contains(paramName)) continue; // NEW
  // ...
}
```

This follows the same proven pattern already used for `_debugOnlyParameters`.

### Fix 2: Report at the offending argument, not the whole declaration

Change `_checkForNonDeterministicValues` to report at the specific argument:

```dart
// Current (line 1845-1847):
if (_containsNonDeterministicValue(arg.expression)) {
  reporter.atNode(reportNode, code); // Reports at variable declaration
  return;
}

// Proposed:
if (_containsNonDeterministicValue(arg.expression)) {
  reporter.atNode(arg, code); // Reports at the specific argument
  return;
}
```

### Fix 3: Verify the variable name detection is working

Confirm that the `endsWith('key')` check at line 1752 is the version being picked up by the analysis server. If the `contacts` project's analysis server is using a cached older version with `.contains('cache')`, a clean restart or rebuild may be needed. Consider adding a version stamp to the LintCode `problemMessage` to make it easy to verify which version is running.

## Test Cases to Add

The fixture file (`example/lib/error_handling/error_handling_v2311_fixture.dart`) currently only tests string interpolation cache keys. Add constructor-based test cases:

```dart
// ---- Constructor-based cache key tests ----

// Mock cache entry model
class MockCacheEntry {
  MockCacheEntry({
    required this.key,
    this.value,
    this.createdAt,
    this.updatedAt,
    this.ttl,
  });
  final String key;
  final String? value;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? ttl;
}

// GOOD: Constructor with deterministic key and metadata DateTime.now()
void goodConstructorWithMetadataTimestamp(String userId) {
  final cacheKey = MockCacheEntry(
    key: userId,
    value: 'some_value',
    createdAt: DateTime.now(), // Metadata — should NOT trigger
  );
}

// BAD: Constructor where the key itself is non-deterministic
void badConstructorWithNonDeterministicKey() {
  // expect_lint: require_cache_key_determinism
  final cacheKey = MockCacheEntry(
    key: 'user_${DateTime.now().millisecondsSinceEpoch}', // Key identity
    value: 'some_value',
  );
}

// GOOD: Variable named 'cacheEntry' (not ending with 'key') with DateTime.now()
void goodCacheEntryNotNamedKey() {
  final cacheEntry = MockCacheEntry(
    key: 'stable_key',
    createdAt: DateTime.now(), // Should NOT trigger — variable doesn't end with 'key'
  );
}
```

## Impact Assessment

- **False positive rate**: Any code that creates a cache/DB model with a timestamp metadata field and assigns it to a variable ending with `key` will be falsely flagged
- **Workaround**: Move `DateTime.now()` to a cascade assignment after construction (`..createdAt = DateTime.now()`) or rename the variable to not end with `key`
- **Fix complexity**: Low — adding a parameter name set is a 10-line change following an existing pattern

## Related

- Line 1751 comment already acknowledges `newCacheEntry` as an excluded case, confirming awareness of the variable naming edge case
- The `_debugOnlyParameters` exclusion set at lines 1678-1681 establishes the pattern for this fix
- Check 2 (API-based detection) at line 1785 correctly reports at the argument node, not the declaration — Check 1 should match this behavior
