# Plan: Increase Test Coverage

## Problem

Two coverage gaps exist:

| Metric | Current | Target |
|--------|---------|--------|
| **Fixture coverage** (rules with fixture files) | 1165/1748 (66.6%) | 95%+ |
| **Unit test coverage** (categories with test files) | 11/95 (11.6%) | 100% |

## How Coverage Is Measured

- **Fixture coverage**: `_rule_metrics.py` counts `*_fixture.dart` files in `example_*/lib/<category>/` directories and compares to rule class count per category.
- **Unit test coverage**: counts `test/*_rules_test.dart` files that contain `test()` calls, matched by category name.

## Test File Pattern

Every test file follows this template (see `test/async_rules_test.dart`):

```dart
import 'dart:io';
import 'package:test/test.dart';

/// Tests for N <category> lint rules.
void main() {
  // Part 1: Fixture verification
  group('<Category> Rules - Fixture Verification', () {
    final fixtures = ['rule_name_one', 'rule_name_two', ...];
    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example_xxx/lib/category/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Part 2: Semantic test stubs (grouped by subcategory)
  group('<Subcategory> Rules', () {
    group('rule_name', () {
      test('violation pattern SHOULD trigger', () {
        // Why this is a problem
        expect('description', isNotNull);
      });
      test('compliant pattern should NOT trigger', () {
        expect('description', isNotNull);
      });
    });
  });
}
```

## Fixture File Pattern

Each fixture is a minimal Dart file in the appropriate example directory:

```dart
// example_xxx/lib/<category>/<rule_name>_fixture.dart

// ignore_for_file: unused_local_variable, ...

/// Fixture for `rule_name` lint rule.

// Bad: triggers rule
void bad() {
  // violation code
}

// Good: does not trigger rule
void good() {
  // compliant code
}
```

## Example Directory Mapping

| Example dir | Categories housed there |
|---|---|
| `example_async/` | async, api_network, bluetooth_hardware, config, connectivity, context, crypto, db_yield, debug, disposal, error_handling, file_handling, iap, json_datetime, lifecycle, media, memory_management, money, notification, performance, permission, resource_management, security, state_management |
| `example_core/` | architecture, build, class_constructor, code_quality, collection, complexity, control_flow, dependency_injection, equality, exception, formatting, naming_style, numeric_literal, record_pattern, return, structure, type, type_safety, unnecessary_code |
| `example_widgets/` | accessibility, animation, build_method, dialog_snackbar, forms, image, navigation, scroll, theming, ui_ux, widget_layout, widget_lifecycle, widget_patterns |
| `example_style/` | documentation, internationalization, stylistic, stylistic_additional, stylistic_control_flow, stylistic_error_testing, stylistic_null_collection, stylistic_whitespace_constructor, stylistic_widget, test, testing_best_practices |
| `example_packages/` | bloc, equatable, freezed, getx, isar, package_specific, provider |
| `example_platforms/` | platform (android, ios, linux, macos, web, windows) |

## Work Plan

### Phase 1: High-Impact Categories (>25 rules) — 16 categories, ~583 rules

These provide the biggest coverage gains per file created.

| # | Category | Rules | Example dir | Needs test file | Needs fixtures |
|---|----------|-------|-------------|-----------------|----------------|
| 1 | `performance` | 46 | example_async | YES | CHECK |
| 2 | `accessibility` | 39 | example_widgets | YES | CHECK |
| 3 | `navigation` | 36 | example_widgets | YES | CHECK |
| 4 | `api_network` | 35 | example_async | YES | CHECK |
| 5 | `testing_best_practices` | 35 | example_style | YES (full) | CHECK |
| 6 | `structure` | 34 | example_core | YES | CHECK |
| 7 | `widget_lifecycle` | 34 | example_widgets | YES | CHECK |
| 8 | `test_rules` | 30 | example_style | YES | CHECK |
| 9 | `control_flow` | 28 | example_core | YES | CHECK |
| 10 | `stylistic` | 27 | example_style | YES | CHECK |
| 11 | `internationalization` | 26 | example_style | YES | CHECK |
| 12 | `forms` | 25 | example_widgets | YES | CHECK |
| 13 | `naming_style` | 24 | example_core | YES | CHECK |
| 14 | `collection` | 23 | example_core | YES | CHECK |
| 15 | `stylistic_additional` | 22 | example_style | YES | CHECK |
| 16 | `build_method` | 11 | example_widgets | YES | CHECK |

### Phase 2: Medium Categories (10–24 rules) — 35 categories, ~478 rules

| # | Category | Rules | Example dir |
|---|----------|-------|-------------|
| 17 | `isar` | 22 | example_packages |
| 18 | `getx` | 22 | example_packages |
| 19 | `image` | 21 | example_widgets |
| 20 | `hive` (needs dir) | 20 | example_packages |
| 21 | `error_handling` | 20 | example_async |
| 22 | `ui_ux` | 19 | example_widgets |
| 23 | `record_pattern` | 19 | example_core |
| 24 | `package_specific` | 19 | example_packages |
| 25 | `disposal` | 17 | example_async |
| 26 | `animation` | 17 | example_widgets |
| 27 | `type_safety` | 16 | example_core |
| 28 | `scroll` | 16 | example_widgets |
| 29 | `stylistic_whitespace_constructor` | 15 | example_style |
| 30 | `macos` | 15 | example_platforms |
| 31 | `file_handling` | 15 | example_async |
| 32 | `dependency_injection` | 15 | example_core |
| 33 | `type` | 14 | example_core |
| 34 | `stylistic_null_collection` | 14 | example_style |
| 35 | `resource_management` | 14 | example_async |
| 36 | `dio` (needs dir) | 14 | example_packages |
| 37 | `unnecessary_code` | 13 | example_core |
| 38 | `stylistic_widget` | 13 | example_style |
| 39 | `stylistic_error_testing` | 13 | example_style |
| 40 | `stylistic_control_flow` | 13 | example_style |
| 41 | `equatable` | 13 | example_packages |
| 42 | `json_datetime` | 13 | example_async |
| 43 | `class_constructor` | 13 | example_core |
| 44 | `complexity` | 12 | example_core |
| 45 | `shared_preferences` (needs dir) | 11 | example_packages |
| 46 | `numeric_literal` | 11 | example_core |
| 47 | `memory_management` | 11 | example_async |
| 48 | `build` (build_method?) | 11 | example_widgets |
| 49 | `state_management` | 10 | example_async |
| 50 | `formatting` | 10 | example_core |
| 51 | `bluetooth_hardware` | 10 | example_async |

### Phase 3: Small Categories (<10 rules) — 33 categories, ~139 rules

| # | Category | Rules | Example dir |
|---|----------|-------|-------------|
| 52 | `freezed` | 9 | example_packages |
| 53 | `documentation` | 9 | example_style |
| 54 | `debug` | 9 | example_async |
| 55 | `architecture` | 9 | example_core |
| 56 | `android` | 7 | example_platforms |
| 57 | `notification` | 7 | example_async |
| 58 | `equality` | 7 | example_core |
| 59 | `web` | 6 | example_platforms |
| 60 | `dialog_snackbar` | 6 | example_widgets |
| 61 | `context` | 6 | example_async |
| 62 | `return` | 5 | example_core |
| 63 | `windows` | 5 | example_platforms |
| 64 | `linux` | 5 | example_platforms |
| 65 | `permission` | 5 | example_async |
| 66 | `flutter_hooks` (needs dir) | 5 | example_packages |
| 67 | `lifecycle` | 5 | example_async |
| 68 | `exception` | 5 | example_core |
| 69 | `crypto` | 5 | example_async |
| 70 | `theming` | 4 | example_widgets |
| 71 | `iap` | 4 | example_async |
| 72 | `config` | 4 | example_async |
| 73 | `platform` | 3 | example_platforms |
| 74 | `workmanager` (needs dir) | 3 | example_packages |
| 75 | `supabase` (needs dir) | 3 | example_packages |
| 76 | `qr_scanner` (needs dir) | 3 | example_packages |
| 77 | `get_it` (needs dir) | 3 | example_packages |
| 78 | `geolocator` (needs dir) | 3 | example_packages |
| 79 | `media` | 3 | example_async |
| 80 | `db_yield` | 3 | example_async |
| 81 | `flame` (needs dir) | 2 | example_packages |
| 82 | `money` | 2 | example_async |
| 83 | `sqflite` (needs dir) | 1 | example_packages |
| 84 | `graphql` (needs dir) | 1 | example_packages |
| 85 | `connectivity` | 1 | example_async |

### Phase 4: Missing Fixture Files

After all test files are created, audit fixture gaps:

1. For each category, compare rule count vs fixture file count
2. Create missing `*_fixture.dart` stub files in the correct example directory
3. Each fixture needs: file header, bad example, good example (can be `// TODO:` stubs)

### Phase 5: Platform-Specific Test Consolidation

Platform rules (ios, android, macos, web, windows, linux) live in `platforms/` subdirectory.
The existing `ios_rules_test.dart` pattern should be replicated for the other platforms.
Fixtures live in `example_platforms/lib/platforms/` (or `example_platforms/lib/platform/`).

## Execution Strategy

### Per-category workflow (for each of the 84 missing test files):

1. **Read the rule file** (`lib/src/rules/<category>_rules.dart`) to get all rule names
2. **Check existing fixtures** (`example_xxx/lib/<category>/`) — note which exist, which are missing
3. **Create missing fixture files** — minimal stubs with bad/good examples
4. **Create the test file** (`test/<category>_rules_test.dart`) following the template:
   - Fixture verification group (one `test()` per rule)
   - Semantic test groups (2+ tests per rule: SHOULD trigger / should NOT trigger)

### Batch strategy (to stay within commit size guidelines):

- Commit after each **5 categories** (~5 test files + associated fixtures)
- Each commit: `test: add <category1>, <category2>, ... test coverage`
- Phase 1 = ~3 commits, Phase 2 = ~7 commits, Phase 3 = ~7 commits

## Expected Results

| Metric | Before | After Phase 1 | After All Phases |
|--------|--------|---------------|------------------|
| Unit test categories | 11/95 (11.6%) | 27/95 (28.4%) | 95/95 (100%) |
| Fixture coverage | 1165/1748 (66.6%) | ~1400/1748 (~80%) | ~1700/1748 (97%+) |

## Progress

### Phase 1 — DONE
- 16 test files created for high-impact categories (>25 rules)
- 64 fixture stubs created
- Coverage: 1229/1748 (70.3%), 27/95 categories (28.4%)

### Phase 2 — DONE
- 34 test files created for medium categories (10–24 rules)
- 191 fixture stubs created
- Fixed: `error_handling_rules_test.dart` was regenerated with correct rules (had disposal rules by mistake)
- Fixed: macOS capitalization in `macos_rules_test.dart`
- Coverage: 1420/1748 (81.2%), 61/95 categories (64.2%)

### Phase 3 — TODO
- 34 remaining small categories (<10 rules)

## Risks & Notes

- **Fixture files in example dirs must compile** — they are analyzed by `dart analyze` but example dirs are excluded in root `analysis_options.yaml`, so they can contain lint violations intentionally
- **New example subdirs for packages** (hive, dio, shared_preferences, flutter_hooks, workmanager, supabase, qr_scanner, get_it, geolocator, flame, sqflite, graphql) may need to be created under `example_packages/lib/`
- **Platform rules** use a nested structure (`platforms/ios_rules.dart`) — test file naming needs to match: `ios_rules_test.dart`
- The metrics script matches test files by `{category}_rules_test` or `{category}_test` stem — ensure naming matches
- Each test file must have actual `test()` calls to register as having coverage
