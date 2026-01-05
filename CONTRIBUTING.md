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

### 4. Add tests

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
