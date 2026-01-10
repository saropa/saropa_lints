# Implementation Plan: Missing Rules (Achievable Scope)

This document prioritizes rules ordered from easiest to implement. Only includes rules with low false-positive risk and straightforward implementation patterns.

## Complexity Legend

| Symbol | Meaning | Implementation Approach |
|--------|---------|------------------------|
| **EASY** | Exact API/parameter matching | Match specific method names, constructors, or named parameters |
| **MEDIUM** | Pattern matching with context | Requires checking parent nodes, build() context, or simple state |

## Severity Priority

- **CRITICAL** (ERROR) - Crashes, security holes, data corruption
- **HIGH** (WARNING) - Bugs, memory leaks, performance issues
- **MEDIUM** (INFO) - Code quality, maintainability
- **LOW** (INFO) - Style, consistency

---

## Phase 1: Quick Wins (EASY - Exact API Matching)

These rules detect specific API calls, constructors, or named parameters. Lowest false-positive risk, highest implementation speed.

### 1.1 Widget Container Rules (5 rules)

| # | Rule | Tier | Severity | Detection Pattern |
|---|------|------|----------|-------------------|
| 1 | `prefer_sized_box_square` | Recommended | INFO | `SizedBox(width: X, height: X)` where X is identical |
| 2 | `prefer_center_over_align` | Recommended | INFO | `Align(alignment: Alignment.center, ...)` |
| 3 | `prefer_align_over_container` | Recommended | INFO | `Container` with only `alignment` property |
| 4 | `prefer_padding_over_container` | Recommended | INFO | `Container` with only `padding` property |
| 5 | `prefer_constrained_box_over_container` | Recommended | INFO | `Container` with only `constraints` property |

**Implementation notes:**
- All use `addInstanceCreationExpression` or `addMethodInvocation`
- Check which named parameters are present vs absent
- Well-defined patterns, no heuristics needed

### 1.2 Bloc Provider Rules (4 rules)

| # | Rule | Tier | Severity | Detection Pattern |
|---|------|------|----------|-------------------|
| 6 | `prefer_multi_bloc_provider` | Recommended | INFO | Nested `BlocProvider` widgets |
| 7 | `avoid_instantiating_in_bloc_value_provider` | Essential | ERROR | `BlocProvider.value(value: SomeBloc())` - constructor call in value |
| 8 | `avoid_existing_instances_in_bloc_provider` | Essential | ERROR | `BlocProvider(create: (_) => existingBloc)` - variable reference not constructor |
| 9 | `prefer_correct_bloc_provider` | Recommended | INFO | Mismatched BlocProvider variant for use case |

**Implementation notes:**
- Match exact class names: `BlocProvider`, `BlocProvider.value`
- Check if `value:` or `create:` parameter contains `InstanceCreationExpression` vs `SimpleIdentifier`

### 1.3 Provider Package Rules (4 rules)

| # | Rule | Tier | Severity | Detection Pattern |
|---|------|------|----------|-------------------|
| 10 | `prefer_multi_provider` | Recommended | INFO | Nested `Provider` widgets |
| 11 | `avoid_instantiating_in_value_provider` | Essential | ERROR | `Provider.value(value: SomeClass())` |
| 12 | `dispose_providers` | Essential | WARNING | `Provider` without `dispose` callback |
| 13 | `dispose_provided_instances` | Essential | WARNING | `Provider.create` returns disposable without dispose |

**Implementation notes:**
- Same pattern as Bloc rules
- Check for presence of `dispose:` named parameter

### 1.4 GetX Lifecycle Rules (3 rules)

| # | Rule | Tier | Severity | Detection Pattern |
|---|------|------|----------|-------------------|
| 14 | `always_remove_getx_listener` | Essential | WARNING | `ever()`, `once()`, `debounce()` without corresponding cancel |
| 15 | `dispose_getx_fields` | Essential | WARNING | `GetxController` subclass with Workers not disposed |
| 16 | `proper_getx_super_calls` | Essential | ERROR | Override of `onInit`/`onClose` without `super.onInit()`/`super.onClose()` |

**Implementation notes:**
- Match method names exactly
- Check for super calls in method bodies

### 1.5 Equatable Rules (3 rules)

| # | Rule | Tier | Severity | Detection Pattern |
|---|------|------|----------|-------------------|
| 17 | `extend_equatable` | Professional | INFO | Class with `operator ==` override that doesn't extend Equatable |
| 18 | `list_all_equatable_fields` | Essential | WARNING | Equatable subclass with fields not in `props` |
| 19 | `prefer_equatable_mixin` | Professional | INFO | Class extending Equatable that could use mixin |

**Implementation notes:**
- Check class hierarchy for Equatable
- Compare declared fields vs props getter contents

### 1.6 Flutter Hooks Basic Rules (3 rules)

| # | Rule | Tier | Severity | Detection Pattern |
|---|------|------|----------|-------------------|
| 20 | `avoid_hooks_outside_build` | Essential | ERROR | `use*` calls outside of `build()` method |
| 21 | `avoid_conditional_hooks` | Essential | ERROR | `use*` calls inside `if`/`switch`/ternary |
| 22 | `avoid_unnecessary_hook_widgets` | Recommended | INFO | `HookWidget` without any `use*` calls |

**Implementation notes:**
- Match function names starting with `use`
- Check if inside build method and not in conditional

### 1.7 Formatting Rules (5 rules)

| # | Rule | Tier | Severity | Detection Pattern |
|---|------|------|----------|-------------------|
| 23 | `newline_before_return` | Stylistic | INFO | Return statement without preceding blank line |
| 24 | `newline_before_case` | Stylistic | INFO | Case clause without preceding blank line |
| 25 | `newline_before_method` | Stylistic | INFO | Method declaration without preceding blank line |
| 26 | `newline_before_constructor` | Stylistic | INFO | Constructor without preceding blank line |
| 27 | `enum_constants_ordering` | Stylistic | INFO | Enum constants not in specified order |

**Implementation notes:**
- Check token positions and whitespace
- Line number arithmetic

### 1.8 Testing Assertion Rules (3 rules)

| # | Rule | Tier | Severity | Detection Pattern |
|---|------|------|----------|-------------------|
| 28 | `missing_test_assertion` | Essential | WARNING | Test body without `expect()`, `verify()`, or assertion |
| 29 | `avoid_async_callback_in_fake_async` | Essential | ERROR | `async` callback inside `fakeAsync` |
| 30 | `prefer_symbol_over_key` | Professional | INFO | String keys in tests instead of Symbols |

**Implementation notes:**
- Detect `test()` or `testWidgets()` calls
- Check body for assertion calls

### 1.9 Firebase Analytics Rules (2 rules)

| # | Rule | Tier | Severity | Detection Pattern |
|---|------|------|----------|-------------------|
| 31 | `incorrect_firebase_event_name` | Essential | ERROR | Event name not matching Firebase conventions |
| 32 | `incorrect_firebase_parameter_name` | Essential | ERROR | Parameter name not matching Firebase conventions |

**Implementation notes:**
- Match `logEvent()` calls
- Validate string literals against regex pattern

### 1.10 Simple Widget Rules (5 rules)

| # | Rule | Tier | Severity | Detection Pattern |
|---|------|------|----------|-------------------|
| 33 | `prefer_transform_over_container` | Recommended | INFO | Container with only transform property |
| 34 | `prefer_action_button_tooltip` | Recommended | INFO | IconButton without tooltip |
| 35 | `prefer_dedicated_media_query_methods` | Recommended | INFO | `MediaQuery.of()` vs `sizeOf()` |
| 36 | `prefer_spacing` | Recommended | INFO | SizedBox for spacing |
| 37 | `prefer_void_callback` | Professional | INFO | `void Function()` instead of `VoidCallback` |

**Implementation notes:**
- All straightforward parameter/type checking

### 1.11 GetIt Rules (1 rule)

| # | Rule | Tier | Severity | Detection Pattern |
|---|------|------|----------|-------------------|
| 38 | `avoid_functions_in_register_singleton` | Essential | WARNING | `registerSingleton(() => ...)` |

**Implementation notes:**
- Match exact GetIt API
- Check argument type is function literal

---

## Phase 2: Moderate Complexity (MEDIUM - Context-Aware)

These rules require understanding context (e.g., inside build method, class hierarchy, async gaps).

### 2.1 Bloc State Management Rules (6 rules)

| # | Rule | Tier | Severity | Detection Pattern |
|---|------|------|----------|-------------------|
| 39 | `check_is_not_closed_after_async_gap` | Essential | ERROR | `emit()` after `await` without `isClosed` check |
| 40 | `avoid_duplicate_bloc_event_handlers` | Essential | ERROR | Multiple `on<SameEvent>` handlers |
| 41 | `prefer_immutable_bloc_events` | Professional | WARNING | Event class with mutable fields |
| 42 | `prefer_immutable_bloc_state` | Professional | WARNING | State class with mutable fields |
| 43 | `prefer_sealed_bloc_events` | Professional | INFO | Event class not sealed |
| 44 | `prefer_sealed_bloc_state` | Professional | INFO | State class not sealed |

**Implementation notes:**
- Requires tracking class hierarchy
- Mutable field detection is straightforward (no `final` keyword)

### 2.2 Riverpod Rules (8 rules)

| # | Rule | Tier | Severity | Detection Pattern |
|---|------|------|----------|-------------------|
| 45 | `avoid_ref_read_inside_build` | Essential | WARNING | `ref.read()` inside `build()` |
| 46 | `avoid_ref_watch_outside_build` | Essential | ERROR | `ref.watch()` outside `build()` |
| 47 | `avoid_ref_inside_state_dispose` | Essential | ERROR | `ref` access in `dispose()` |
| 48 | `use_ref_read_synchronously` | Essential | WARNING | `ref.read()` after `await` |
| 49 | `use_ref_and_state_synchronously` | Essential | WARNING | `ref`/`state` after async gap |
| 50 | `avoid_assigning_notifiers` | Essential | ERROR | Direct assignment to notifier variable |
| 51 | `avoid_notifier_constructors` | Professional | WARNING | Notifier with constructor initialization |
| 52 | `prefer_immutable_provider_arguments` | Professional | INFO | Mutable arguments to providers |

**Implementation notes:**
- Needs method context detection (am I in build? dispose?)
- Async gap analysis for ref usage

### 2.3 Type Safety Rules (4 rules)

| # | Rule | Tier | Severity | Detection Pattern |
|---|------|------|----------|-------------------|
| 53 | `avoid_non_null_assertion` | Recommended | WARNING | `!` operator usage |
| 54 | `avoid_type_casts` | Professional | INFO | `as` keyword usage |
| 55 | `avoid_unrelated_type_casts` | Essential | ERROR | Cast between incompatible types |
| 56 | `prefer_explicit_type_arguments` | Professional | INFO | Generic without explicit type args |

**Implementation notes:**
- `!` and `as` detection is trivial
- `avoid_unrelated_type_casts` needs type system integration

### 2.4 Error Handling Rules (2 rules)

| # | Rule | Tier | Severity | Detection Pattern |
|---|------|------|----------|-------------------|
| 57 | `avoid_uncaught_future_errors` | Essential | WARNING | Future without `.catchError()` or try-catch |
| 58 | `avoid_nested_try_statements` | Professional | INFO | Try block inside another try block |

**Implementation notes:**
- Future error handling requires tracking async context
- Nested try is simple AST traversal

### 2.5 Boolean & Conditional Rules (3 rules)

| # | Rule | Tier | Severity | Detection Pattern |
|---|------|------|----------|-------------------|
| 59 | `no_boolean_literal_compare` | Recommended | INFO | `x == true` or `x == false` |
| 60 | `prefer_simpler_boolean_expressions` | Recommended | INFO | `!(!x)` or `!(a && !b)` patterns |
| 61 | `prefer_returning_conditional_expressions` | Recommended | INFO | `if (x) return a; else return b;` |

**Implementation notes:**
- Pattern matching on BinaryExpression and IfStatement
- Well-defined AST patterns

### 2.6 Collection & Loop Rules (2 rules)

| # | Rule | Tier | Severity | Detection Pattern |
|---|------|------|----------|-------------------|
| 62 | `prefer_correct_for_loop_increment` | Recommended | INFO | Non-standard increment in for loop |
| 63 | `avoid_unreachable_for_loop` | Recommended | WARNING | For loop with impossible bounds |

**Implementation notes:**
- For loop analysis is straightforward

### 2.7 Widget Optimization Rules (4 rules)

| # | Rule | Tier | Severity | Detection Pattern |
|---|------|------|----------|-------------------|
| 64 | `prefer_single_setstate` | Professional | INFO | Multiple `setState` calls in same method |
| 65 | `prefer_compute_over_isolate_run` | Professional | INFO | `Isolate.run` for simple computation |
| 66 | `prefer_for_loop_in_children` | Professional | INFO | `List.generate` in widget children |
| 67 | `prefer_container` | Comprehensive | INFO | Multiple widgets that should be Container |

**Implementation notes:**
- Most are parameter/type checking
- `prefer_single_setstate` needs method body analysis

### 2.8 Intl/Localization Rules (5 rules)

| # | Rule | Tier | Severity | Detection Pattern |
|---|------|------|----------|-------------------|
| 68 | `prefer_date_format` | Recommended | INFO | Raw DateTime formatting |
| 69 | `prefer_number_format` | Recommended | INFO | Raw number formatting |
| 70 | `prefer_intl_name` | Professional | INFO | Intl.message without name parameter |
| 71 | `prefer_providing_intl_description` | Professional | INFO | Intl.message without description |
| 72 | `prefer_providing_intl_examples` | Professional | INFO | Intl.message without examples |

**Implementation notes:**
- All are exact API matching on Intl methods

### 2.9 Flame Engine Rules (2 rules)

| # | Rule | Tier | Severity | Detection Pattern |
|---|------|------|----------|-------------------|
| 73 | `avoid_creating_vector_in_update` | Essential | WARNING | `Vector2()` or `Vector3()` in `update()` method |
| 74 | `avoid_redundant_async_on_load` | Recommended | INFO | `async onLoad()` without await |

**Implementation notes:**
- Check method name context
- Async keyword without await is easy to detect

### 2.10 Bloc Naming Rules (2 rules)

| # | Rule | Tier | Severity | Detection Pattern |
|---|------|------|----------|-------------------|
| 75 | `prefer_bloc_event_suffix` | Stylistic | INFO | Event class without Event suffix |
| 76 | `prefer_bloc_state_suffix` | Stylistic | INFO | State class without State suffix |

**Implementation notes:**
- Class naming patterns - check class name ends with suffix
- Need to detect Bloc event/state classes by hierarchy

### 2.11 Simple Code Quality Rules (5 rules)

| # | Rule | Tier | Severity | Detection Pattern |
|---|------|------|----------|-------------------|
| 77 | `no_empty_block` | Recommended | WARNING | Empty `{}` blocks |
| 78 | `prefer_typedefs_for_callbacks` | Professional | INFO | Inline function types |
| 79 | `prefer_redirecting_superclass_constructor` | Recommended | INFO | Non-redirecting super calls |
| 80 | `avoid_empty_build_when` | Recommended | WARNING | Empty `buildWhen` callback |
| 81 | `prefer_use_prefix` | Stylistic | INFO | Custom hook without `use` prefix |

**Implementation notes:**
- All straightforward AST patterns

### 2.12 Provider Advanced Rules (3 rules)

| # | Rule | Tier | Severity | Detection Pattern |
|---|------|------|----------|-------------------|
| 82 | `prefer_immutable_selector_value` | Professional | INFO | Mutable value in Selector |
| 83 | `prefer_nullable_provider_types` | Professional | INFO | Non-nullable Provider that can be null |
| 84 | `prefer_provider_extensions` | Professional | INFO | Long Provider access chains |

**Implementation notes:**
- Type mutability analysis
- Pattern recognition for verbose code

### 2.13 Riverpod Widget Rules (2 rules)

| # | Rule | Tier | Severity | Detection Pattern |
|---|------|------|----------|-------------------|
| 85 | `avoid_unnecessary_consumer_widgets` | Recommended | INFO | ConsumerWidget not using ref |
| 86 | `avoid_nullable_async_value_pattern` | Recommended | INFO | Nullable AsyncValue usage |

**Implementation notes:**
- Track ref usage in widget body

### 2.14 GetX Build Rules (2 rules)

| # | Rule | Tier | Severity | Detection Pattern |
|---|------|------|----------|-------------------|
| 87 | `avoid_getx_rx_inside_build` | Professional | WARNING | `.obs` in build method |
| 88 | `avoid_mutable_rx_variables` | Professional | INFO | Reassignment of Rx variable |

**Implementation notes:**
- Variable assignment tracking
- Build context detection

---

## Implementation Order Summary

### Sprint 1: Foundation (Rules 1-38) - 38 rules
- Container widget rules (5)
- Bloc provider rules (4)
- Provider package rules (4)
- GetX lifecycle rules (3)
- Equatable rules (3)
- Flutter hooks basic rules (3)
- Formatting rules (5)
- Testing assertion rules (3)
- Firebase analytics rules (2)
- Simple widget rules (5)
- GetIt rules (1)

**Estimated effort:** Low - all exact API matching

### Sprint 2: Context-Aware (Rules 39-88) - 50 rules
- Bloc state management (6)
- Riverpod rules (8)
- Type safety rules (4)
- Error handling rules (2)
- Boolean/conditional rules (3)
- Collection/loop rules (2)
- Widget optimization (4)
- Intl/localization (5)
- Flame engine (2)
- Bloc naming rules (2)
- Simple code quality (5)
- Provider advanced (3)
- Riverpod widget (2)
- GetX build (2)

**Estimated effort:** Medium - requires context detection

---

## Dependencies

### Shared Utilities to Build

1. `isInsideBuildMethod()` - Context detection (used by ~15 rules)
2. `isInsideDisposeMethod()` - Dispose context (used by ~5 rules)
3. `getClassHierarchy()` - Inheritance chain (used by Bloc/Riverpod rules)
4. `hasAsyncGap()` - Await detection before usage (used by async safety rules)

---

## Success Metrics

| Milestone | Rules | Cumulative |
|-----------|-------|------------|
| Sprint 1 Complete | 38 | 38 |
| Sprint 2 Complete | 50 | 88 |

**Total achievable rules: 88**

---

## Excluded Rules (Deferred)

The following 73 rules were excluded due to complexity:

### Cross-File Analysis (requires whole-project analysis)
- `avoid_never_passed_parameters`
- `avoid_missing_test_files`
- `avoid_importing_entrypoint_exports`

### Heuristic-Heavy (high false-positive risk)
- `avoid_missing_tr` / `avoid_missing_tr_on_strings` - detecting user-visible strings
- `avoid_missing_interpolation` - string concat patterns
- `avoid_high_cyclomatic_complexity` - McCabe calculation with threshold
- `avoid_explicit_type_declaration` - redundant type inference

### Complex Class Analysis
- `avoid_accessing_other_classes_private_members`
- `avoid_referencing_subclasses`
- `avoid_suspicious_super_overrides`
- `avoid_suspicious_global_reference`
- `dispose_class_fields` - requires tracking all disposable types

### Pubspec/YAML Analysis (requires separate parser)
- `add_resolution_workspace`
- `avoid_dependency_overrides`
- `dependencies_ordering`
- `newline_before_pubspec_entry`
- `prefer_commenting_pubspec_ignores`
- `pubspec_ordering`
- `prefer_correct_screenshots`
- `prefer_correct_topics`
- `avoid_any_version`
- `prefer_caret_version_syntax`
- `prefer_pinned_version_syntax`
- `prefer_semver_version`
- `prefer_correct_package_name`
- `prefer_publish_to_none`

### Configuration-Dependent
- `banned_usage` - requires robust configuration system
- `arguments_ordering` - multiple ordering strategies
- `pattern_fields_ordering`
- `record_fields_ordering`

### Type Resolution Heavy
- `handle_throwing_invocations` - needs to know which methods throw
- `avoid_not_encodable_in_to_json` - toJson return type analysis
- `prefer_correct_json_casts` - unsafe JSON cast detection
- `avoid_collection_mutating_methods` - unmodifiable collection detection
- `add_copy_with` - immutability detection
- `avoid_unnecessary_null_aware_elements` - nullability inference

These can be revisited after the 88 achievable rules are implemented.
