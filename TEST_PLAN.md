# Saropa Lints Test Plan

This document outlines the comprehensive testing strategy for all 497+ lint rules in the saropa_lints package.

## Testing Approach

### Method: expect_lint Comments

Custom_lint supports testing via `// expect_lint: rule_name` comments:

```dart
// BAD: This should trigger the lint
// expect_lint: avoid_debug_print
debugPrint('test');

// GOOD: This should NOT trigger any lint
logger.info('test');
```

### Running Tests

```bash
cd test_fixtures
dart pub get
dart run custom_lint
```

If all expected lints are found and no unexpected lints appear, the test passes.

### Test Structure

```
test_fixtures/
├── pubspec.yaml              # Pure Dart project with saropa_lints dependency
├── analysis_options.yaml     # Enables custom_lint plugin
├── custom_lint.yaml          # Enables rules being tested
└── lib/
    ├── critical/             # Critical severity rules
    ├── security/             # Security rules (Dart only)
    ├── collections/          # Collection safety rules (Dart only)
    ├── async/                # Async/Stream rules (Dart only)
    ├── variables/            # Variable rules (Dart only)
    ├── types/                # Type safety rules (Dart only)
    └── code_quality/         # Code quality rules (Dart only)
```

> **Note**: Flutter-dependent rules require a separate Flutter test project.
> Current test_fixtures is pure Dart for simplicity.

---

## Phase 1A: Dart-Only Critical Rules (Current Focus)

These rules can be tested without Flutter dependencies.

### Testing Hook
| Rule | File | Status |
|------|------|--------|
| `always_fail` | `critical/always_fail_fixture.dart` | ✅ Created |

### Security Rules (4) - Dart Only
| Rule | File | Status |
|------|------|--------|
| `avoid_hardcoded_credentials` | `security/avoid_hardcoded_credentials_fixture.dart` | ✅ Created |
| `avoid_logging_sensitive_data` | `security/avoid_logging_sensitive_fixture.dart` | ✅ Created |
| `avoid_eval_like_patterns` | `security/` | TODO |
| `avoid_weak_cryptographic_algorithms` | `security/avoid_weak_crypto_fixture.dart` | ✅ Created |

### Collection Safety Rules (2) - Dart Only
| Rule | File | Status |
|------|------|--------|
| `avoid_unsafe_collection_methods` | `collections/avoid_unsafe_collection_fixture.dart` | ✅ Created |
| `avoid_unsafe_reduce` | `collections/avoid_unsafe_reduce_fixture.dart` | ✅ Created |

### Variable Rules (1) - Dart Only
| Rule | File | Status |
|------|------|--------|
| `avoid_late_final_reassignment` | `variables/avoid_late_final_reassignment_fixture.dart` | ✅ Created |

### Type Safety Rules (1) - Dart Only
| Rule | File | Status |
|------|------|--------|
| `avoid_unsafe_cast` | `types/avoid_unsafe_cast_fixture.dart` | ✅ Created |

### Async Rules (1) - Dart Only
| Rule | File | Status |
|------|------|--------|
| `require_stream_controller_dispose` | `async/require_stream_controller_dispose_fixture.dart` | ✅ Created |

### Code Quality Rules - Dart Only
| Rule | File | Status |
|------|------|--------|
| `avoid_null_assertion` | `code_quality/null_assertion_fixture.dart` | ✅ Created |
| `no_empty_block` | `code_quality/empty_block_fixture.dart` | ✅ Created |
| `avoid_adjacent_strings` | `code_quality/avoid_adjacent_strings_fixture.dart` | ✅ Created |
| `avoid_continue` | `code_quality/avoid_continue_fixture.dart` | ✅ Created |
| `prefer_contains` | `code_quality/prefer_contains_fixture.dart` | ✅ Created |
| `prefer_first` | `code_quality/prefer_first_last_fixture.dart` | ✅ Created |
| `prefer_last` | `code_quality/prefer_first_last_fixture.dart` | ✅ Created |

---

## Phase 1B: Flutter-Dependent Critical Rules (Future)

These rules require a Flutter test project.

### Flutter Lifecycle Rules (7)
| Rule | Requires Flutter |
|------|------------------|
| `avoid_context_in_initstate_dispose` | Yes - StatefulWidget |
| `avoid_inherited_widget_in_initstate` | Yes - InheritedWidget |
| `avoid_build_context_in_providers` | Yes - BuildContext |
| `avoid_unsafe_setstate` | Yes - setState |
| `use_setstate_synchronously` | Yes - setState |
| `avoid_global_key_in_build` | Yes - GlobalKey |
| `avoid_setstate_in_build` | Yes - setState |

### Flutter Disposal Rules (3)
| Rule | Requires Flutter |
|------|------------------|
| `require_dispose` | Yes - StatefulWidget |
| `dispose_fields` | Yes - StatefulWidget |
| `require_animation_disposal` | Yes - AnimationController |

### Flutter Widget Rules (4)
| Rule | Requires Flutter |
|------|------------------|
| `avoid_recursive_widget_calls` | Yes - Widget |
| `avoid_duplicate_widget_keys` | Yes - Key |
| `pass_existing_future_to_future_builder` | Yes - FutureBuilder |
| `pass_existing_stream_to_stream_builder` | Yes - StreamBuilder |

---

## Phase 2: High-Priority Dart Rules

Rules that catch common bugs and can be tested without Flutter.

### Null Safety (Dart Only)
- `avoid_null_assertion` ✅
- `avoid_nullable_interpolation`
- `avoid_nullable_to_string`
- `avoid_always_null_parameters`
- `avoid_unnecessary_nullable_parameters`
- `avoid_unnecessary_nullable_return_type`
- `avoid_unnecessary_nullable_fields`
- `prefer_null_aware_spread`

### Error Handling (Dart Only)
- `avoid_swallowing_exceptions`
- `avoid_losing_stack_trace`
- `avoid_generic_exceptions`
- `avoid_throw_in_catch_block`
- `avoid_throw_in_finally`

### Async/Concurrency (Dart Only)
- `avoid_nested_futures`
- `avoid_nested_streams_and_futures`
- `avoid_unassigned_stream_subscriptions`
- `avoid_future_ignore`
- `avoid_future_to_string`
- `prefer_return_await`
- `avoid_async_call_in_sync_function`
- `avoid_unnecessary_futures`
- `avoid_redundant_async`

### Collections (Dart Only)
- `avoid_duplicate_map_keys`
- `avoid_duplicate_collection_elements`
- `prefer_add_all`
- `prefer_set_for_lookup`
- `avoid_map_keys_contains`

---

## Phase 3: Medium-Priority Rules

### Code Quality (Dart Only - 50+ rules)
- Control flow: `avoid_nested_*`, `avoid_collapsible_if`, etc.
- Naming: `prefer_boolean_prefixes`, `prefer_correct_*_name`, etc.
- Complexity: `avoid_long_*`, `avoid_complex_*`, etc.

### Architecture Rules (Dart Only)
- `avoid_circular_dependencies`
- `avoid_god_class`
- `avoid_singleton_pattern`

---

## Phase 4: Low-Priority Rules

### Style Rules (Dart Only - 100+ rules)
- Formatting rules
- Ordering rules
- Preference rules

---

## Test Coverage Summary

| Phase | Category | Rules | Status |
|-------|----------|-------|--------|
| 1A | Dart-only critical | 17 | 15 ✅ Created |
| 1B | Flutter critical | 14 | Needs Flutter project |
| 2 | High-priority Dart | ~40 | TODO |
| 3 | Medium-priority | ~100 | TODO |
| 4 | Low-priority | ~300 | TODO |

---

## Test File Template

```dart
// ignore_for_file: unused_local_variable, unused_field, unused_element
// Test fixture for <rule_name> rule

import 'dart:async'; // if needed

// BAD: Description of what triggers the lint
// expect_lint: <rule_name>
<code that should trigger lint>

// GOOD: Description of correct code
<code that should NOT trigger lint>
```

---

## CI Integration

Add to `.github/workflows/test.yml`:

```yaml
name: Test Lint Rules

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
        with:
          sdk: stable
      - name: Install dependencies
        run: |
          cd test_fixtures
          dart pub get
      - name: Run custom_lint tests
        run: |
          cd test_fixtures
          dart run custom_lint
```

---

## Adding New Tests

1. Identify if rule needs Flutter or is Dart-only
2. For Dart-only rules:
   - Create fixture file in appropriate `test_fixtures/lib/` directory
   - Add `// expect_lint: rule_name` comments for BAD code
   - Ensure GOOD code has no expect_lint comments
   - Enable rule in `test_fixtures/custom_lint.yaml`
   - Run `dart run custom_lint` to verify
3. For Flutter rules:
   - Create separate Flutter test project (future work)
4. Update this plan's status table

---

## Rule Categories Reference

| Category | Dart-Only | Flutter-Required | Priority |
|----------|-----------|------------------|----------|
| Security | 8 | 0 | Critical |
| Collections | 10 | 0 | High |
| Null Safety | 15 | 0 | High |
| Error Handling | 8 | 0 | High |
| Async | 20 | 0 | High |
| Lifecycle | 0 | 15 | Critical |
| Disposal | 0 | 10 | Critical |
| Widgets | 0 | 40 | Medium |
| State Management | 2 | 8 | High |
| Accessibility | 0 | 10 | Medium |
| Performance | 5 | 15 | Medium |
| Architecture | 7 | 0 | Medium |
| Code Quality | 80 | 0 | Medium |
| Naming | 30 | 0 | Low |
| Formatting | 20 | 0 | Low |
| Documentation | 10 | 0 | Low |
| Testing | 15 | 0 | Low |

**Total: 497+ rules** (~350 Dart-only, ~150 Flutter-required)
