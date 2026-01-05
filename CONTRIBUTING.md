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
class AvoidMyAntiPatternRule extends DartLintRule {
  const AvoidMyAntiPatternRule() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_my_anti_pattern',
    problemMessage: 'Avoid using this anti-pattern because...',
    correctionMessage: 'Instead, use the recommended pattern.',
    errorSeverity: ErrorSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
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

### 2. Register the rule

Add to `lib/src/rules/all_rules.dart`:

```dart
AvoidMyAntiPatternRule(),
```

### 3. Add to appropriate tier(s)

Edit `lib/tiers/*.yaml`:

```yaml
rules:
  avoid_my_anti_pattern: true
```

### 4. Add quick fixes (optional but recommended)

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

### 5. Add tests

Create `test/rules/my_rule_test.dart`:

```dart
void main() {
  group('AvoidMyAntiPatternRule', () {
    test('triggers on anti-pattern', () async {
      // Test code
    });

    test('passes on correct pattern', () async {
      // Test code
    });
  });
}
```

## Rule Naming Conventions

| Prefix | Meaning | Example |
|--------|---------|---------|
| `avoid_` | Don't do this | `avoid_print_in_production` |
| `prefer_` | Do this instead of alternatives | `prefer_const_constructors` |
| `require_` | Must have this | `require_dispose` |
| `no_` | Absolute prohibition | `no_empty_catch` |

## Commit Messages

Use conventional commits:

```
feat: add avoid_my_anti_pattern rule
fix: correct false positive in avoid_xyz
docs: update README with new tier
test: add tests for avoid_abc rule
```

## Pull Request Checklist

- [ ] Rule follows naming conventions
- [ ] Added to appropriate tier(s)
- [ ] Tests pass
- [ ] Documentation updated
- [ ] CHANGELOG.md updated

## Questions?

Open an issue or discussion. We're happy to help!

**Email**: [dev@saropa.com](mailto:dev@saropa.com)
