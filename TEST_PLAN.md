# Saropa Lints Test Plan

This document outlines the testing strategy for the saropa_lints package.

## Test Structure

```
saropa_lints/
├── test/                    # Unit tests (dart test)
│   └── saropa_lints_test.dart
└── example/                 # Lint rule fixtures (dart run custom_lint)
    ├── pubspec.yaml
    ├── analysis_options.yaml
    ├── custom_lint.yaml
    └── lib/
        ├── security/        # Security rule fixtures
        └── collections/     # Collection rule fixtures
```

## Running Tests

### Unit Tests
```bash
dart test
```

### Lint Rule Fixtures
```bash
cd example
dart pub get
dart run custom_lint
```

## Testing Method: expect_lint Comments

Fixtures use `// expect_lint: rule_name` comments to assert expected lints:

```dart
// BAD: This should trigger the lint
// expect_lint: avoid_hardcoded_credentials
const password = 'secret123';

// GOOD: This should NOT trigger any lint
const envVar = String.fromEnvironment('PASSWORD');
```

## Current Test Coverage

### Unit Tests
| Test | Description |
|------|-------------|
| `createPlugin returns PluginBase` | Verifies plugin instantiation |
| `createPlugin is callable multiple times` | Verifies plugin reusability |

### Lint Rule Fixtures (example/lib/)

| Rule | Fixture | Assertions |
|------|---------|------------|
| `avoid_hardcoded_credentials` | `security/avoid_hardcoded_credentials_fixture.dart` | 4 |
| `avoid_unsafe_collection_methods` | `collections/avoid_unsafe_collection_fixture.dart` | 3 |
| `avoid_unsafe_reduce` | `collections/avoid_unsafe_reduce_fixture.dart` | 1 |

## Adding New Tests

### For Unit Tests
Add tests to `test/saropa_lints_test.dart`.

### For Lint Rule Fixtures
1. Create fixture file in `example/lib/<category>/`
2. Add `// expect_lint: rule_name` before code that should trigger lint
3. Run `cd example && dart run custom_lint` to verify

## Fixture Template

```dart
// ignore_for_file: unused_local_variable
// Test fixture for <rule_name> rule

void testRuleName() {
  // BAD: Description
  // expect_lint: <rule_name>
  <code that triggers lint>

  // GOOD: Description (no expect_lint)
  <code that does not trigger lint>
}
```

## Notes

- Only rules in `_enabledRules` are active by default
- Flutter-dependent rules require a separate Flutter project
- The `example/` folder is excluded from main project analysis via `analysis_options.yaml`
