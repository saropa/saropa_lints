# Contributing to saropa_lints

Thank you for your interest in contributing! This guide will help you get started.

## Code of Conduct

Be respectful and constructive. We're all here to make Flutter development better.

## How to Contribute

### Reporting Issues

1. Search existing issues first
2. Include: Dart/Flutter version, minimal reproduction, expected vs actual behavior
3. Use the issue template if available

### Suggesting New Rules

1. Open an issue with the `rule-request` label
2. Include:
   - Rule name (following naming conventions)
   - What it detects
   - Why it matters (bug prevention, performance, etc.)
   - BAD and GOOD code examples
   - Suggested tier (Essential, Recommended, Professional, Comprehensive, Insanity)

### Submitting Code

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/new-rule-name`
3. Make your changes
4. Add tests
5. Run `dart analyze` and `dart test`
6. Submit a pull request

## Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/saropa_lints.git
cd saropa_lints

# Get dependencies
dart pub get

# Run tests
dart test

# Run the linter on itself
dart run custom_lint
```

## Adding a New Rule

### 1. Create the rule

Add to the appropriate file in `lib/src/rules/`:

```dart
class AvoidMyAntiPatternRule extends SaropaLintRule {
  const AvoidMyAntiPatternRule() : super(code: _code);

  /// REQUIRED: Specify the business impact of this rule's violations.
  /// See "Impact Classification" section below.
  @override
  LintImpact get impact => LintImpact.high;

  static const _code = LintCode(
    name: 'avoid_my_anti_pattern',
    problemMessage: 'Avoid using this anti-pattern because...',
    correctionMessage: 'Instead, use the recommended pattern.',
    errorSeverity: ErrorSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addXxxExpression((node) {
      // Detection logic
      if (isAntiPattern(node)) {
        reporter.atNode(node, code);
      }
    });
  }
}
```

### 2. Set the impact classification (REQUIRED)

Every rule **must** override the `impact` getter. This helps teams understand which violations to prioritize:

| Impact | Threshold | Use when... | Examples |
|--------|-----------|-------------|----------|
| `critical` | 1-2 is serious | Each occurrence is independently harmful | Memory leaks, security holes, crashes |
| `high` | 10+ needs action | Significant issues that compound | Accessibility, performance anti-patterns |
| `medium` | 100+ = tech debt | Quality issues worth addressing | Error handling, complexity (default) |
| `low` | Large counts OK | Style/consistency matters | Naming, hardcoded strings, formatting |

```dart
@override
LintImpact get impact => LintImpact.critical; // Memory leak - each one matters
```

**Guidelines:**
- **Critical**: Crashes, memory leaks, security vulnerabilities, data corruption
- **High**: Accessibility issues, performance problems, missing error handling in critical paths
- **Medium**: Code smells, maintainability issues, missing documentation
- **Low**: Style preferences, naming conventions, formatting

**DO NOT default to `medium` without thought.** Consider the real-world consequence of 1000 violations of your rule.

### 3. Register the rule

Add to `lib/src/rules/all_rules.dart`:

```dart
AvoidMyAntiPatternRule(),
```

### 4. Add to appropriate tier(s)

Edit `lib/tiers/*.yaml`:

```yaml
rules:
  avoid_my_anti_pattern: true
```

### 5. Add quick fixes (optional but recommended)

Quick fixes provide IDE code actions that help developers resolve lint issues.

```dart
class AvoidMyAntiPatternRule extends DartLintRule {
  // ... rule implementation ...

  @override
  List<Fix> getFixes() => <Fix>[_MyAntiPatternFix()];
}

class _MyAntiPatternFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    // Find the node and apply the fix
  }
}
```

#### Quick Fix Design Principles

**Comment out, don't delete.** When a fix removes code (like debug statements),
comment it out instead of deleting it. This preserves the developer's intent
and provides context during code review about what was there and why it was disabled.

```dart
// GOOD: Comment out to preserve history
builder.addSimpleReplacement(
  SourceRange(statement.offset, statement.length),
  '// ${statement.toSource()}',
);

// BAD: Deleting loses context
builder.addDeletion(SourceRange(statement.offset, statement.length));
```

This principle helps:
- Code reviewers understand what was changed and why
- Developers recover the code if needed
- Maintain a history of debugging attempts
- Make the fix reversible without version control

#### Quick Fix Requirements

All rules should have quick fixes when feasible:

1. Add `**Quick fix available:**` to the rule's doc comment describing what it does
2. Fix type guidelines:
   - **Simple transformations**: Apply directly (e.g., `!(a == b)` → `a != b`)
   - **Debug/intentional code**: Comment out to preserve developer history
   - **Complex issues**: Add `// HACK:` comment for manual attention
3. **All WARNING/ERROR severity rules must have at least a HACK comment fix**

### 6. Add tests

Create a fixture file in `example/lib/<category>/`:

```dart
// ignore_for_file: unused_local_variable
// Test fixture for avoid_my_anti_pattern rule

void testAvoidMyAntiPattern() {
  // BAD: This triggers the lint
  // expect_lint: avoid_my_anti_pattern
  final bad = myAntiPattern();

  // GOOD: This should NOT trigger any lint (no expect_lint comment)
  final good = correctPattern();
}
```

Run the fixture tests:

```bash
cd example
dart pub get
dart run custom_lint
```

The `expect_lint` comments assert that a lint fires on the next line. If the lint doesn't fire, the test fails. If a lint fires without an `expect_lint` comment, that also fails.

## Rule Naming Conventions

| Prefix | Meaning | Example |
|--------|---------|---------|
| `avoid_` | Don't do this | `avoid_print_in_production` |
| `prefer_` | Do this instead of alternatives | `prefer_const_constructors` |
| `require_` | Must have this | `require_dispose` |
| `no_` | Absolute prohibition | `no_empty_catch` |

## Message Style Guide

### Doc Header Format (Published to pub.dev)

Every rule class must have a doc header that follows this format:

```dart
/// One-sentence summary of what this rule warns about.
///
/// [Optional 1-2 sentence explanation of why this matters - the consequence.]
///
/// **BAD:**
/// ```dart
/// // Code that triggers the lint
/// ```
///
/// **GOOD:**
/// ```dart
/// // Code that passes the lint
/// ```
class MyRule extends SaropaLintRule { ... }
```

**Requirements:**
- First line: Clear, concise summary (no period if single sentence)
- Include **BAD:** and **GOOD:** examples with working code
- Examples should be minimal but complete enough to understand
- If the rule has a quick fix, add `**Quick fix available:** [description]`

### Problem Message Format

The `problemMessage` appears in IDEs and tells developers what's wrong:

```dart
problemMessage: '[What is wrong]. [Why it matters/consequence].',
```

**Guidelines:**
- Start with the specific issue detected (not "Avoid..." - that's the correction)
- Include the consequence when not obvious
- Keep under 80 characters when possible
- Use concrete language, not vague warnings

**Examples:**
| BAD | GOOD |
|-----|------|
| `'Avoid using print.'` | `'print() found. Will appear in production logs.'` |
| `'HTTP status should be checked.'` | `'HTTP response used without status check. Errors may be silently ignored.'` |
| `'Class has too many responsibilities.'` | `'Class has too many members (>15 fields or >20 methods). Violates Single Responsibility.'` |

### Correction Message Format

The `correctionMessage` tells developers how to fix it:

```dart
correctionMessage: '[Specific action to take]. [Optional example].',
```

**Guidelines:**
- Start with an imperative verb (Add, Use, Replace, Move, Wrap)
- Include a concrete example when helpful
- Show the fix pattern, not just "do it differently"

**Examples:**
| BAD | GOOD |
|-----|------|
| `'Use configuration constants.'` | `"Extract to config: Uri.parse('\${ApiConfig.baseUrl}/endpoint')."` |
| `'Add a timeout.'` | `'Add .timeout(Duration(seconds: 30)) or configure in client options.'` |
| `'Check the status code.'` | `'Check if (response.statusCode == 200) before parsing response.body.'` |

### Message Checklist

- [ ] Problem message explains WHAT is wrong and WHY it matters
- [ ] Correction message explains HOW to fix with specific action
- [ ] Both messages are under 100 characters
- [ ] No vague language like "should", "consider", "may want to"
- [ ] Includes concrete examples where helpful

## Commit Messages

Use conventional commits:

```
feat: add avoid_my_anti_pattern rule
fix: correct false positive in avoid_xyz
docs: update README with new tier
test: add tests for avoid_abc rule
```

## Documentation Requirements

**All documentation files must be referenced in README.md.** The README serves as the central hub for discoverability.

### When adding a new document

1. Create the `.md` file in the project root or `doc/` folder
2. Add it to the Documentation table in README.md:
   ```markdown
   | [NEW_DOC.md](NEW_DOC.md) | Brief description |
   ```

### When adding stylistic rules

Stylistic rules require extra documentation since they're not in any tier:

1. Add the rule to `lib/src/rules/stylistic_rules.dart`
2. Add to `lib/saropa_lints.dart` rule list
3. **Update [STYLISTIC.md](https://github.com/saropa/saropa_lints/blob/main/STYLISTIC.md)**:
   - Add to the Quick Reference table
   - Add full documentation section with Pros/Cons and examples
4. Update rule count in README.md and ROADMAP.md if needed

### Documentation files

| File | Purpose | Update when... |
|------|---------|----------------|
| README.md | Central hub, must reference all docs | Adding any new documentation |
| STYLISTIC.md | Stylistic rule details | Adding/changing stylistic rules |
| ROADMAP.md | Planned features | Implementing planned rules (remove from roadmap) |
| CHANGELOG.md | Version history | Any release |
| CONTRIBUTING.md | This file | Changing contribution process |

## Pull Request Checklist

- [ ] Rule extends `SaropaLintRule` (not `DartLintRule`)
- [ ] **Impact classification set** (not just defaulting to `medium`)
- [ ] Rule follows naming conventions
- [ ] Added to appropriate tier(s)
- [ ] Tests pass
- [ ] Documentation updated (see Documentation Requirements above)
- [ ] CHANGELOG.md updated
- [ ] If stylistic rule: STYLISTIC.md updated

## Questions?

Open an issue or discussion. We're happy to help!

**Email**: [dev@saropa.com](mailto:dev@saropa.com)

---

## About This Document

> "The only way to go fast is to go well." — Robert C. Martin

> "First, solve the problem. Then, write the code." — John Johnson

**Contributing to open source** makes you a better developer. You learn from code review, discover new patterns, and build a public portfolio. saropa_lints welcomes contributions at every skill level — from fixing typos to implementing complex AST visitors.

Start small: pick a rule from the roadmap, add test fixtures, or improve documentation. Every contribution matters.

**Keywords:** open source contribution, Flutter open source, Dart package development, custom_lint rules, AST visitor patterns, lint rule implementation, code review, pull request workflow, test fixtures, Dart analyzer plugins

**Hashtags:** #OpenSource #Flutter #Dart #Contributing #FlutterDev #DartLang #GitHub #CodeReview #Community #DevCommunity

---

## Sources

- **custom_lint_builder** — API for building lint rules
  https://pub.dev/packages/custom_lint_builder

- **Dart Analyzer** — AST visitor patterns and node types
  https://pub.dev/documentation/analyzer/latest/

- **Effective Dart** — Official style and documentation guidelines
  https://dart.dev/effective-dart

- **Conventional Commits** — Commit message format specification
  https://www.conventionalcommits.org/

- **Keep a Changelog** — Changelog format specification
  https://keepachangelog.com/

- **Semantic Versioning** — Version numbering standard
  https://semver.org/

- **GitHub Pull Request Guidelines** — Best practices for PRs
  https://docs.github.com/en/pull-requests
