# Task: `avoid_banned_api`

## Summary
- **Rule Name**: `avoid_banned_api`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §1.55 Architecture Rules
- **Inspired by**: `solid_lints` `avoid_using_api`

## Problem Statement

In larger codebases, certain APIs should be restricted to specific layers. For example:
- UI layer should never call the database directly
- Domain layer should not import `dart:io` or platform-specific code
- Test utilities should not be imported in production code

Without enforcement, layer boundary violations creep in over time and become impossible to refactor. This rule provides a configurable mechanism to ban specific APIs (by package, class name, identifier, or named parameter) with include/exclude file patterns.

## Description (from ROADMAP)

> Configurable rule to restrict usage of specific APIs based on source package, class name, identifier, or named parameter, with include/exclude file patterns. Useful for enforcing layer boundaries (e.g., UI cannot call database directly).

## Implementation Approach

### Configuration in `analysis_options.yaml`
```yaml
custom_lint:
  rules:
    avoid_banned_api:
      entries:
        - identifier: 'IsarCollection'
          source: 'package:isar'
          reason: 'Database access is only allowed in the data layer'
          allowedFiles:
            - 'lib/data/**'
            - 'lib/src/repositories/**'
          bannedFiles:
            - 'lib/presentation/**'
            - 'lib/ui/**'
        - identifier: 'dart:io'
          reason: 'Use platform-abstracted alternatives'
          bannedFiles:
            - 'lib/domain/**'
```

### AST Visitor
For each configured ban:
1. Check `node.staticElement?.library?.identifier` against the banned source
2. Check `node` identifier name against the banned identifier
3. Check the current file path against `allowedFiles`/`bannedFiles` patterns

```dart
context.registry.addSimpleIdentifier((node) {
  for (final ban in _configuredBans) {
    if (!ban.matches(node)) continue;
    if (!ban.isFileBanned(resolver.path)) continue;
    reporter.atNode(node, code);
  }
});
```

## Code Examples

### Config + Bad (Should trigger)
```yaml
# analysis_options.yaml
custom_lint:
  rules:
    avoid_banned_api:
      entries:
        - identifier: 'IsarCollection'
          source: 'package:isar'
          bannedFiles: ['lib/ui/**']
```

```dart
// lib/ui/product_page.dart — UI layer accessing database directly
class ProductPage extends StatelessWidget {
  final IsarCollection<Product> products;  // ← trigger: IsarCollection in UI
}
```

### Good (Should NOT trigger)
```dart
// lib/data/repositories/product_repository.dart — data layer
class ProductRepository {
  final IsarCollection<Product> _products;  // ← OK: allowed in data layer
}
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| No configuration provided | **Suppress all** — rule is a no-op without config | Check config exists first |
| File matches both `allowedFiles` and `bannedFiles` | **Allow takes precedence** — document this behavior | |
| Dynamic import (`import 'package:isar/isar.dart' show IsarCollection`) | **Detect via `show` import** | |
| Type used in comment only | **Suppress** — comments are not code | |
| Generated files (`.g.dart`) | **Suppress by default** | |
| Banned identifier used as string (e.g., `'IsarCollection'`) | **Suppress** — string is not a usage | |
| Wildcard `*` in identifier | **Support glob patterns** | |
| Test files | **Configurable** — may or may not be banned from test files | |

## Unit Tests

### Violations
1. `IsarCollection` used in `lib/ui/` with rule banning it there → 1 lint
2. `dart:io` import in `lib/domain/` with rule banning it there → 1 lint

### Non-Violations
1. `IsarCollection` used in `lib/data/` (allowed path) → no lint
2. No configuration → no lint
3. `IsarCollection` in comment → no lint
4. Generated file → no lint

## Quick Fix

No automated fix — violation of layer boundaries requires architectural refactoring.

## Notes & Issues

1. **Configuration format** must be carefully designed — this is a complex configurable rule. Study `solid_lints`' `avoid_using_api` implementation for reference.
2. **`banned_usage` in §1.61** is a similar/related rule — check if they can be merged or if they serve different purposes. `avoid_banned_api` focuses on layer boundaries; `banned_usage` may be more general.
3. **Glob pattern matching** for file paths needs a reliable implementation. Consider using the `glob` package.
4. **Performance**: This rule checks every identifier against all configured bans. With many bans, this could be slow. Build an efficient lookup structure.
5. **Custom lint options** parsing needs to be tested carefully — malformed YAML in `analysis_options.yaml` should produce a clear error message, not a crash.
