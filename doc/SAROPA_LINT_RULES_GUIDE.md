# Saropa Custom Lint Rules

## Enterprise-Grade Code Quality for Flutter Applications

---

## Executive Summary

The Saropa Custom Lint Rules package provides **475 automated code quality checks** for Flutter and Dart applications. These rules help development teams catch bugs before they reach production, enforce consistent coding standards, and build more maintainable, performant, and accessible applications.

**This is a free, open-source tool** designed to integrate seamlessly into your existing Flutter development workflow.

### Key Benefits

| Stakeholder | Benefits |
|-------------|----------|
| **Product Owners** | Reduced bug counts, faster releases, lower maintenance costs |
| **Development Teams** | Automated code reviews, consistent standards, faster onboarding |
| **End Users** | More stable apps, better accessibility, improved performance |

---

## Table of Contents

1. [What Are Lint Rules?](#what-are-lint-rules)
2. [Business Value](#business-value)
3. [Rule Categories](#rule-categories)
4. [Getting Started](#getting-started)
5. [Adoption Strategy](#adoption-strategy)
6. [Rule Selection Guide](#rule-selection-guide)
7. [Handling Initial Warnings](#handling-initial-warnings)
8. [Configuration Reference](#configuration-reference)
9. [Frequently Asked Questions](#frequently-asked-questions)

---

## What Are Lint Rules?

Lint rules are automated checks that analyze your code **before it runs**. They identify potential bugs, security vulnerabilities, performance issues, and style inconsistencies during development rather than in production.

### How They Work

```
Developer writes code
        ↓
Lint rules analyze code automatically
        ↓
Issues flagged immediately in IDE
        ↓
Developer fixes issues before commit
        ↓
Cleaner, safer code reaches production
```

### Real-World Impact

| Without Linting | With Linting |
|-----------------|--------------|
| Bug found by user in production | Bug caught during development |
| 4+ hours to diagnose and fix | 5 minutes to fix with IDE suggestion |
| Reputation damage, support costs | Issue never reaches users |

---

## Business Value

### For Product Owners & Stakeholders

#### 1. Reduced Defect Rates

Static analysis catches entire categories of bugs automatically:

- **Null reference errors** — The #1 cause of app crashes
- **Memory leaks** — Cause slow performance and crashes over time
- **Resource leaks** — Database connections, file handles left open
- **Security vulnerabilities** — Hardcoded secrets, unsafe data handling

> **Industry data**: Static analysis tools typically reduce production defects by **30-50%** ([source: NIST](https://www.nist.gov/)).

#### 2. Lower Maintenance Costs

Code that follows consistent patterns is:

- **Easier to understand** — New team members onboard faster
- **Easier to modify** — Changes don't break unrelated features
- **Easier to test** — Consistent structure enables better testing

> **Cost ratio**: Fixing a bug in production costs **6-10x more** than fixing it during development ([source: IBM Systems Sciences Institute](https://www.ibm.com/)).

#### 3. Faster Development Velocity

| Activity | Without Linting | With Linting |
|----------|-----------------|--------------|
| Code review | 45 min (manual style checks) | 15 min (focus on logic) |
| Bug investigation | Hours of debugging | Immediate IDE feedback |
| New developer onboarding | Weeks learning patterns | Days with enforced standards |

#### 4. Compliance & Accessibility

Many rules help meet regulatory and accessibility requirements:

- **WCAG accessibility compliance** — Screen reader support, touch targets
- **Security best practices** — OWASP guidelines, secure storage
- **Platform guidelines** — Apple/Google app store requirements

### For Development Teams

#### Automated Code Reviews

Rules automate the tedious parts of code review:

- Style consistency (naming, formatting)
- Common bug patterns
- Performance anti-patterns
- Security vulnerabilities

This frees reviewers to focus on **architecture, logic, and design**.

#### Consistent Codebase

Every developer follows the same patterns:

```dart
// Without linting: 5 developers, 5 different styles
fetchUser()    // Developer A
getUserData()  // Developer B
loadUser()     // Developer C
getUser()      // Developer D
user_fetch()   // Developer E

// With linting: Enforced naming convention
getUser()      // Everyone
```

#### Living Documentation

Rule messages explain **why** something is wrong and **how** to fix it:

```
⚠️ avoid_build_context_in_async_callback

Problem: BuildContext used after async gap may be invalid.
Fix: Check 'mounted' before using context, or store needed
     values before the async operation.
```

---

## Rule Categories

The 475 rules are organized into categories based on what aspect of code quality they address:

### Core Quality Categories

| Category | Rules | Impact |
|----------|-------|--------|
| **Performance** | 25 | Faster app, better battery life |
| **Memory Management** | 7 | Prevents crashes, improves stability |
| **Resource Management** | 7 | Prevents leaks of files, connections |
| **Error Handling** | 8 | Better crash recovery, user experience |
| **Security** | 8 | Protects user data, prevents breaches |

### Architecture & Design

| Category | Rules | Impact |
|----------|-------|--------|
| **Architecture** | 7 | Maintainable, scalable codebase |
| **Dependency Injection** | 8 | Testable, modular code |
| **State Management** | 10 | Predictable app behavior |
| **Type Safety** | 7 | Fewer runtime errors |

### Flutter-Specific

| Category | Rules | Impact |
|----------|-------|--------|
| **Widget Rules** | 40+ | Efficient UI rendering |
| **Accessibility** | 10 | Usable by everyone |
| **Internationalization** | 8 | Ready for global markets |

### Code Quality

| Category | Rules | Impact |
|----------|-------|--------|
| **Documentation** | 8 | Maintainable code |
| **Testing Best Practices** | 7 | Reliable test suites |
| **API & Network** | 7 | Robust network handling |
| **Async Patterns** | 20+ | Correct concurrent code |

### Complete Category Breakdown

<details>
<summary>Click to expand full category list</summary>

| Category | Rule Count | Description |
|----------|------------|-------------|
| Accessibility | 10 | Screen readers, touch targets, focus management |
| API & Network | 7 | HTTP handling, timeouts, error mapping |
| Architecture | 7 | Layer separation, clean architecture |
| Async | 20+ | Futures, streams, isolates |
| Class & Constructor | 15+ | Constructor patterns, initialization |
| Code Quality | 20+ | General best practices |
| Collection | 15+ | List, Map, Set operations |
| Complexity | 10+ | Cyclomatic complexity, nesting depth |
| Control Flow | 15+ | If/else, switch, loops |
| Debug | 5+ | Print statements, debug code |
| Dependency Injection | 8 | DI patterns, service locators |
| Documentation | 8 | Doc comments, examples |
| Equality | 10+ | ==, hashCode, identical |
| Error Handling | 8 | Exceptions, Result pattern |
| Exception | 10+ | Try/catch, rethrow |
| Flutter Widget | 40+ | Widget lifecycle, keys, const |
| Formatting | 10+ | Code style, line length |
| Internationalization | 8 | l10n, RTL, plurals |
| Memory Management | 7 | Leaks, disposal, caching |
| Naming & Style | 20+ | Variable, class, file naming |
| Numeric Literal | 5+ | Magic numbers, constants |
| Performance | 25 | Build optimization, lazy loading |
| Record & Pattern | 5+ | Dart 3 patterns |
| Resource Management | 7 | File, database, socket cleanup |
| Return | 10+ | Return statements, early returns |
| Security | 8 | Credentials, input validation |
| State Management | 10 | Provider, BLoC, Riverpod |
| Structure | 10+ | File organization, imports |
| Test | 15+ | Test patterns, mocking |
| Testing Best Practices | 7 | Setup, assertions, isolation |
| Type | 15+ | Type annotations, inference |
| Type Safety | 7 | Casts, generics, nullability |
| Unnecessary Code | 15+ | Dead code, redundant operations |

</details>

---

## Getting Started

### Installation

Add to your project's `pubspec.yaml`:

```yaml
dev_dependencies:
  custom_lint: ^0.8.0
  saropa_lints:
    path: custom_lints  # Or your package reference
```

Enable in `analysis_options.yaml`:

```yaml
analyzer:
  plugins:
    - custom_lint
```

### IDE Integration

The rules work automatically in:

- **VS Code** with Dart extension
- **Android Studio / IntelliJ** with Dart/Flutter plugins
- **Command line** via `dart run custom_lint`

Issues appear as you type with suggested fixes.

---

## Adoption Strategy

### The Challenge: Initial Warning Count

When first enabling comprehensive lint rules on an existing project, you will likely see **thousands of warnings**. This is normal and expected.

A typical medium-sized Flutter app might show:

| Project Size | Initial Warnings |
|--------------|------------------|
| Small (10K lines) | 500-2,000 |
| Medium (50K lines) | 2,000-10,000 |
| Large (200K+ lines) | 10,000-50,000+ |

**This does not mean your code is bad.** It means you now have visibility into areas for improvement.

### Recommended Adoption Path

#### Phase 1: Critical Rules Only (Week 1)

Start with rules that catch **actual bugs**:

```yaml
custom_lint:
  enable_all_lint_rules: false  # Start with all disabled

  rules:
    # Memory leaks - these cause crashes
    require_dispose_controllers: true
    require_stream_subscription_cancel: true
    require_image_disposal: true

    # Null safety - #1 crash cause
    avoid_bang_after_await: true
    avoid_force_unwrap_in_callback: true

    # Security - critical for production
    avoid_hardcoded_credentials: true
    avoid_logging_sensitive_data: true
```

**Goal**: Fix all critical issues (typically 50-200 warnings).

#### Phase 2: High-Impact Rules (Weeks 2-4)

Add rules that improve **reliability and performance**:

```yaml
    # Performance
    avoid_expensive_build: true
    prefer_const_constructors: true
    avoid_unnecessary_rebuilds: true

    # Error handling
    require_error_boundary: true
    avoid_swallowing_exceptions: true

    # Architecture
    avoid_business_logic_in_widgets: true
```

**Goal**: Reduce warnings by 50% through targeted fixes and establishing patterns for new code.

#### Phase 3: Code Quality Rules (Months 2-3)

Enable rules that improve **maintainability**:

```yaml
    # Documentation
    require_public_api_documentation: true

    # Testing
    require_test_assertions: true
    avoid_hardcoded_test_delays: true

    # Accessibility
    require_semantics_label: true
```

**Goal**: All new code follows these standards; legacy code fixed opportunistically.

#### Phase 4: Full Enablement (Month 3+)

Enable remaining rules, with team-specific exclusions:

```yaml
custom_lint:
  enable_all_lint_rules: true

  rules:
    # Disable rules that don't fit your project
    prefer_result_pattern: false  # Team prefers exceptions
    avoid_print_statements: false  # Needed for debugging
```

### Strategies for Handling Existing Warnings

#### Strategy 1: Fix-As-You-Touch

Only fix warnings in files you're already modifying:

```dart
// When editing user_service.dart for a new feature,
// also fix any lint warnings in that file
```

**Pros**: No dedicated cleanup time, gradual improvement
**Cons**: Some files may never get cleaned up

#### Strategy 2: Dedicated Cleanup Sprints

Schedule short focused efforts:

- 2-hour "lint party" each Friday
- One cleanup story per sprint
- Gamify with team leaderboards

**Pros**: Consistent progress, team building
**Cons**: Requires dedicated time allocation

#### Strategy 3: File-by-File Exclusion

Temporarily exclude legacy files:

```yaml
analyzer:
  exclude:
    - lib/legacy/**
    - lib/old_features/**
```

Then remove exclusions as files are cleaned up.

**Pros**: Clean CI immediately, clear scope
**Cons**: Technical debt not visible

#### Strategy 4: Rule-by-Rule Enablement

Enable one new rule at a time, fixing all violations before enabling the next.

**Pros**: Very manageable, clear progress
**Cons**: Takes longer to get full coverage

---

## Rule Selection Guide

### By Project Type

#### Consumer Mobile App

Focus on user experience and stability:

```yaml
# Essential
- Performance rules (all)
- Memory management (all)
- Accessibility rules (all)
- Error handling (all)

# Recommended
- State management rules
- Internationalization rules

# Optional
- Architecture rules (if team > 3 developers)
```

#### Enterprise/B2B App

Focus on security and maintainability:

```yaml
# Essential
- Security rules (all)
- Architecture rules (all)
- Documentation rules (all)
- Type safety rules (all)

# Recommended
- Testing best practices
- Dependency injection rules

# Optional
- Accessibility (if required by contracts)
```

#### Startup MVP

Focus on shipping fast with quality foundations:

```yaml
# Essential
- Critical bug prevention only
- Performance basics

# Defer
- Documentation rules
- Style rules
- Architecture rules (until team grows)
```

### By Team Experience

#### Junior-Heavy Team

Enable more rules to guide learning:

```yaml
# Highly Recommended
- All naming rules (teaches conventions)
- All documentation rules (builds good habits)
- All error handling rules (prevents common mistakes)
```

#### Senior Team

Enable rules that catch subtle issues:

```yaml
# Focus on
- Performance rules (catches non-obvious issues)
- Memory management (complex lifecycle bugs)
- Concurrency rules (race conditions, deadlocks)

# Consider disabling
- Basic style rules (seniors know conventions)
```

### By Development Phase

#### Greenfield Project

Enable everything from day one:

```yaml
custom_lint:
  enable_all_lint_rules: true
```

Starting clean prevents debt accumulation.

#### Legacy Modernization

Phased enablement (see Adoption Strategy above).

#### Maintenance Mode

Enable bug-prevention rules, disable style rules:

```yaml
# Enable
- Security rules
- Memory management
- Critical error handling

# Disable (to avoid churn)
- Documentation rules
- Naming rules
- Formatting rules
```

---

## Handling Initial Warnings

### Understanding Warning Severity

Warnings are categorized by severity:

| Severity | Icon | Action Required |
|----------|------|-----------------|
| **ERROR** | ❌ | Must fix - indicates likely bug or crash |
| **WARNING** | ⚠️ | Should fix - indicates problematic pattern |
| **INFO** | ℹ️ | Consider fixing - improvement opportunity |

### Triage Process

When faced with thousands of warnings:

1. **Filter by severity**: Fix all ERRORs first
2. **Filter by category**: Security → Memory → Performance → Style
3. **Filter by file**: Focus on actively-developed files first
4. **Bulk operations**: Many fixes can be automated

### Automated Fixes

Many rules provide automatic fixes in the IDE:

```
Right-click warning → Quick Fix → Apply fix
```

For bulk fixes:

```bash
# Apply all available quick fixes
dart fix --apply
```

### When to Suppress Warnings

Sometimes warnings should be suppressed rather than fixed:

```dart
// Intentional: This is test code that needs to verify error behavior
// ignore: avoid_print_statements
print('Debug output for test');

// Intentional: Legacy code scheduled for removal in v2.0
// ignore_for_file: deprecated_member_use
```

**Guidelines for suppression**:

- ✅ Add a comment explaining WHY
- ✅ Suppress the most specific rule possible
- ❌ Never suppress to hide real issues
- ❌ Avoid file-wide suppressions when possible

---

## Configuration Reference

### Basic Configuration

```yaml
# custom_lint.yaml or analysis_options.yaml

custom_lint:
  # Master switch: true = all rules enabled by default
  enable_all_lint_rules: true

  rules:
    # Disable specific rules
    rule_name: false

    # Enable with options (where supported)
    avoid_too_many_dependencies:
      max_dependencies: 7  # Custom threshold
```

### Severity Levels

Each rule has a default severity that can be overridden:

```yaml
analyzer:
  errors:
    avoid_print_statements: error      # Promote to error
    prefer_const_constructors: ignore  # Demote to ignored
```

### File Exclusions

Exclude specific files or patterns:

```yaml
analyzer:
  exclude:
    - "**/*.g.dart"           # Generated files
    - "**/*.freezed.dart"     # Freezed generated
    - "lib/generated/**"      # All generated
    - "test/fixtures/**"      # Test fixtures
```

### Per-File Configuration

Override rules for specific files:

```dart
// At top of file:
// ignore_for_file: require_documentation

// Or for specific lines:
// ignore: avoid_print
print('Allowed here');
```

---

## Frequently Asked Questions

### For Product Owners

**Q: What's the ROI of implementing lint rules?**

A: Typical returns include:
- 30-50% reduction in production bugs
- 20-40% faster code reviews
- 50%+ faster new developer onboarding
- Reduced emergency fix costs (bugs caught earlier)

**Q: Will this slow down our developers?**

A: Initially, there may be a small slowdown (1-2 weeks) as the team addresses critical issues. After that, development typically accelerates because:
- Fewer bugs to investigate
- Faster code reviews
- Less time debugging production issues

**Q: Can we implement this gradually?**

A: Yes, phased adoption is recommended. See the [Adoption Strategy](#adoption-strategy) section.

**Q: Do we need to fix all existing warnings?**

A: No. Focus on:
1. Critical severity issues (fix immediately)
2. New code (enforce going forward)
3. Legacy code (fix opportunistically)

### For Developers

**Q: Why am I seeing thousands of warnings?**

A: When comprehensive linting is first enabled, it analyzes the entire codebase and reports all potential issues at once. This is a one-time event—once addressed, you'll only see warnings for new code.

**Q: These rules are too strict / too lenient. Can we customize?**

A: Yes. Every rule can be:
- Disabled entirely
- Changed in severity
- Configured with custom thresholds (where supported)

**Q: Some rules conflict with each other. What do I do?**

A: Disable the rule that doesn't fit your project. Rules are recommendations, not mandates.

**Q: How do I fix [specific rule]?**

A: Each rule includes:
- Problem description
- Bad example (what triggers it)
- Good example (how to fix it)
- Automatic quick-fix (often available)

**Q: Will this break our CI/CD pipeline?**

A: Not by default. Lint warnings don't fail builds unless you configure them to. Recommended approach:
1. Enable as warnings first
2. Add `--fatal-warnings` to CI after cleaning up

### For Tech Leads

**Q: How do we enforce these rules across the team?**

A:
1. Add configuration to version control
2. Enable in CI pipeline (with appropriate thresholds)
3. IDE settings shared via project configuration
4. Pre-commit hooks (optional)

**Q: What's the performance impact on development?**

A: Analysis runs in the background and typically completes in seconds. Large projects (100K+ lines) may take 10-30 seconds for full analysis but only on initial load.

**Q: Should we write tests for the lint rules themselves?**

A: For custom rules you write, yes. For Saropa's rules, they're already tested.

---

## Rule Quick Reference

### Critical Rules (Always Enable)

These rules catch bugs that will crash your app:

| Rule | Why It Matters |
|------|---------------|
| `require_dispose_controllers` | Memory leaks crash apps |
| `require_stream_subscription_cancel` | Memory leaks crash apps |
| `avoid_bang_after_await` | Null errors crash apps |
| `avoid_hardcoded_credentials` | Security breaches |
| `require_error_boundary` | Unhandled errors crash apps |

### High-Value Rules

These rules significantly improve code quality:

| Rule | Category | Impact |
|------|----------|--------|
| `avoid_expensive_build` | Performance | 2-10x faster UI |
| `prefer_const_constructors` | Performance | Reduced rebuilds |
| `require_semantics_label` | Accessibility | Usable by everyone |
| `avoid_business_logic_in_widgets` | Architecture | Maintainable code |
| `require_api_timeout` | Network | No hanging requests |

### Noisy but Valuable Rules

Enable after initial cleanup:

| Rule | Why It's Noisy | Why It's Valuable |
|------|---------------|-------------------|
| `require_documentation` | Every public API | Self-documenting code |
| `avoid_hardcoded_strings_in_ui` | Every UI string | i18n readiness |
| `prefer_constrained_generics` | Every generic | Type safety |

---

## Support & Resources

- **Issue Tracker**: [GitHub Issues](https://github.com/saropa/saropa_dart_utils/issues)
- **Documentation**: This guide + inline rule documentation
- **Examples**: Each rule includes BAD/GOOD code examples

---

## Appendix: Complete Rule List by Severity

### Error Severity (Must Fix)

These indicate likely bugs or crashes:

<details>
<summary>Click to expand</summary>

- `require_dispose_controllers`
- `require_stream_subscription_cancel`
- `require_keys_in_animated_lists`
- `avoid_bloc_state_mutation`
- `avoid_circular_imports`
- `avoid_logging_sensitive_data`
- `avoid_eval_like_patterns`
- `avoid_hardcoded_credentials`
- `require_native_resource_cleanup`

</details>

### Warning Severity (Should Fix)

These indicate problematic patterns:

<details>
<summary>Click to expand</summary>

- `avoid_unsafe_cast`
- `require_safe_json_parsing`
- `require_null_safe_extensions`
- `require_file_close_in_finally`
- `require_database_close`
- `require_websocket_close`
- `require_image_disposal`
- `require_cache_eviction_policy`
- `avoid_expando_circular_references`
- `avoid_service_locator_in_widgets`
- `avoid_too_many_dependencies`
- `avoid_circular_di_dependencies`
- `require_http_status_check`
- `require_api_timeout`
- `avoid_hardcoded_api_urls`
- `avoid_swallowing_exceptions`
- `avoid_losing_stack_trace`
- `require_future_error_handling`
- `require_deprecation_message`
- ... and more

</details>

### Info Severity (Consider Fixing)

These are improvement opportunities:

<details>
<summary>Click to expand</summary>

- `prefer_constrained_generics`
- `require_covariant_documentation`
- `prefer_specific_numeric_types`
- `require_futureor_documentation`
- `require_http_client_close`
- `require_platform_channel_cleanup`
- `require_isolate_kill`
- `avoid_large_objects_in_state`
- `avoid_capturing_this_in_callbacks`
- `prefer_weak_references_for_cache`
- `avoid_large_isolate_communication`
- `avoid_internal_dependency_creation`
- `prefer_abstract_dependencies`
- `avoid_singleton_for_scoped_dependencies`
- `prefer_null_object_pattern`
- `require_typed_di_registration`
- `require_retry_logic`
- `require_typed_api_response`
- `require_connectivity_check`
- `require_api_error_mapping`
- ... and many more

</details>

---

*Document version: 1.0*
*Rules version: 475 rules*
*Last updated: December 2024*
