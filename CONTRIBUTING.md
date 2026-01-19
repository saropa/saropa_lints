# Contributing to Saropa Lints

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

## Configuration Reference

For a complete reference of all available rules, tiers, and configuration options, see [example/analysis_options_template.yaml](./example/analysis_options_template.yaml). It includes all 1184+ rules organized by category with impact levels and tier membership documented.

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
    problemMessage: '[avoid_my_anti_pattern] Avoid using this anti-pattern because...',
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

### 3. Set performance optimizations (optional but recommended)

With 1400+ rules, performance matters. Two getters help the framework optimize rule execution:

#### Rule Cost Classification

Declare how expensive your rule is to execute. Rules are sorted by cost so fast rules run first:

```dart
@override
RuleCost get cost => RuleCost.low; // Single node inspection
```

| Cost | Use when... | Examples |
|------|-------------|----------|
| `trivial` | Simple pattern matching | Check for specific method name |
| `low` | Single AST node inspection | Check constructor parameters |
| `medium` | Traverse part of AST (default) | Check method body |
| `high` | Full AST traversal or type resolution | Complex type analysis |
| `extreme` | Cross-file analysis simulation | Dependency graph analysis |

#### File Type Filtering

Restrict your rule to specific file types for early exit. Files not matching are skipped entirely:

```dart
@override
Set<FileType>? get applicableFileTypes => {FileType.widget};
```

| FileType | Matches |
|----------|---------|
| `widget` | Files with `StatelessWidget`, `StatefulWidget`, `State<>` |
| `test` | `*_test.dart`, files in `test/`, `integration_test/` |
| `bloc` | Files with `Bloc<>`, `Cubit<>` |
| `provider` | Files with `Provider`, `Riverpod`, `ref.watch/read` |
| `model` | Data classes, entities |
| `service` | Service/repository files |
| `general` | Default for unclassified files |

**Example: A complete widget-specific rule**

```dart
class AvoidWidgetAntiPatternRule extends SaropaLintRule {
  const AvoidWidgetAntiPatternRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  // Only run on widget files - skip everything else
  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  // This rule is fast - single node inspection
  @override
  RuleCost get cost => RuleCost.low;

  static const _code = LintCode(
    name: 'avoid_widget_anti_pattern',
    problemMessage: '[avoid_widget_anti_pattern] Widget anti-pattern detected.',
    errorSeverity: ErrorSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      // Only called for widget files due to applicableFileTypes
      if (isAntiPattern(node)) {
        reporter.atNode(node, code);
      }
    });
  }
}
```

### 4. Register the rule

Add to `lib/src/rules/all_rules.dart`:

```dart
AvoidMyAntiPatternRule(),
```

### 5. Add to appropriate tier(s)

Edit `lib/tiers/*.yaml`:

```yaml
rules:
  avoid_my_anti_pattern: true
```

### 6. Add config aliases (optional)

If your rule name has a prefix (like `enforce_` or `require_`) that users might commonly omit, add a config alias:

```dart
/// Alias: my_anti_pattern
@override
List<String> get configAliases => const <String>['my_anti_pattern'];
```

This allows users to use either `avoid_my_anti_pattern: false` or `my_anti_pattern: false` in their config. Only add aliases when there's genuine ambiguity - most rules don't need them.

### 7. Add quick fixes (optional but recommended)

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
   - **Wrap/add required code**: Add missing parameters, wrap with widgets, etc.

#### HACK Comment Fixes Are Discouraged

**Do NOT use `// HACK:` comment fixes as a shortcut.** These provide no real value:

```dart
// BAD: Lazy fix that just adds a comment
builder.addSimpleInsertion(node.offset, '// HACK: Fix this manually\n');

// GOOD: Actual fix that transforms the code
builder.addSimpleReplacement(range, 'await $expression');
```

HACK fixes are acceptable ONLY when:
- The fix requires human judgment (e.g., choosing between multiple valid approaches)
- The fix requires context not available in the AST (e.g., business logic decisions)
- The rule is newly added and a real fix is planned for a follow-up PR

**If you can't write a real fix, don't add a fix at all.** A rule without a fix is better than a rule with a useless HACK comment fix that clutters the codebase.

#### Quick Fix Priority (for contributors)

When adding fixes, prioritize by impact:
1. **High-value fixes**: Actual code transformations (await, dispose, null checks)
2. **Wrap fixes**: Wrap expressions with required widgets/builders
3. **Parameter fixes**: Add missing required parameters with sensible defaults
4. **Remove fixes**: Comment out problematic code (preserves history)
5. **Last resort**: Skip the fix entirely — document why in the rule's doc comment

### 8. Add tests

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

## Audit New Rules Checklist

Before submitting a PR with new or modified lint rules, review **only the files you changed** against this checklist. This ensures consistency, performance, and completeness.

### Code Quality

- [ ] **Correct file placement** — Is each rule in the appropriate `lib/src/rules/<category>_rules.dart` file?

> **Note on file length**: Rule files in `lib/src/rules/` are exempt from file length
> restrictions. These files contain declarative rule definitions organized by domain
> (e.g., `flutter_widget_rules.dart`, `security_rules.dart`). Each rule is self-contained
> with no shared state—similar to data files, enums, or lookup tables. Domain grouping
> aids discoverability. Don't split rule files just because they're large.
- [ ] **Logic correctness** — Does the detection logic handle all edge cases correctly?
- [ ] **Heuristics safety** — If using name-based detection, have you avoided false positives? (See "Avoiding False Positives" section below)
- [ ] **No recursion risks** — Does the visitor avoid infinite loops or excessive tree traversal?
- [ ] **No duplication** — Check for duplicate logic or lint coverage; extract shared utilities if applicable
- [ ] **Clear code comments** — Concise inline comments explaining non-obvious logic

### Rule Configuration

- [ ] **`LintImpact` correctly set** — Impact reflects real-world severity (critical/high/medium/low), not defaulted to medium
- [ ] **`cost` override set** — Rule cost classification matches actual complexity (trivial/low/medium/high/extreme)
- [ ] **`applicableFileTypes` override set** — Restrict to specific file types when possible (widget/test/bloc/etc.) for performance
- [ ] **Error severity appropriate** — `ErrorSeverity` matches the rule's impact (ERROR/WARNING/INFO)

### Documentation

- [ ] **Doc header complete** — Verbose doc comment with: summary, why it matters, **BAD:** example, **GOOD:** example
- [ ] **Quick fix documented** — If quick fix exists, add `**Quick fix available:**` to doc header
- [ ] **Guide compatibility** — Review `doc/guides/` documents if your changes affect documented patterns

### Quick Fixes

- [ ] **Quick fix implemented** — Add quick fixes where feasible with real code transformations
- [ ] **No lazy HACK fixes** — HACK comment fixes are discouraged; prefer real fixes or no fix
- [ ] **Fix preserves intent** — Comment out code rather than deleting when removing debug statements
- [ ] **Fix is safe** — The fix doesn't introduce new issues or change behavior unexpectedly

### Registration & Configuration

- [ ] **Rule registered** — Added to `lib/saropa_lints.dart` rule list
- [ ] **Tier assignment** — Updated `lib/src/tiers.dart` with correct tier membership
- [ ] **Template updated** — Added to `example/analysis_options_template.yaml` with impact level and tier documented

### Testing

- [ ] **Test fixtures added** — Created test fixtures in `example/lib/<category>/`
- [ ] **BAD cases marked** — All expected violations have `// expect_lint: rule_name` comments
- [ ] **GOOD cases included** — Include passing cases without expect_lint to verify no false positives
- [ ] **Tests pass** — Run `cd example && dart run custom_lint` to verify

### Project Updates

- [ ] **CHANGELOG.md updated** — Added entry under appropriate version (bump version if current is deployed)
- [ ] **README.md counts updated** — Update rule counts in README if total changed
- [ ] **pubspec.yaml updated** — Update version and rule count if applicable
- [ ] **ROADMAP.md cleaned** — Remove implemented rules completely (don't just mark as complete)

### Quick Reference

```bash
# Run these before submitting:
dart analyze                           # Check for analyzer issues
cd example && dart run custom_lint     # Verify test fixtures
dart test                              # Run unit tests
```

## Avoiding False Positives (Critical)

**Heuristic-based detection is the #1 source of bugs in lint rules.** Many rules that seem "easy" turn out to require multiple revisions due to false positives.

### What NOT to do

| Anti-Pattern | Problem | Example |
|--------------|---------|---------|
| **Substring matching on variable names** | Matches unintended words | `aud` in `audioVolume`, `cad` in `cadence` |
| **Generic term detection** | Terms have multiple meanings | `cost` (computational), `fee` (service callback), `balance` (physics) |
| **Short abbreviations** | Too ambiguous even as words | `iv` matches `activity`, `private`, `derivative` |
| **String interpolation without context** | Flags safe usage | `${password.length}` doesn't expose the password |

### Lessons Learned (from our own revisions)

1. **`avoid_double_for_money`** — Required 3 revisions:
   - v1.7.9: Broad word list (`total`, `amount`, `cost`, `fee`...) → many false positives
   - v1.8.0: Removed generic terms, kept only `price`, `money`, `currency`, `salary`, `wage`
   - v1.8.1: Still matching `audioVolume` → `aud`. Switched to **word-boundary matching** with camelCase/snake_case splitting

2. **`avoid_sensitive_data_in_logs`** — Changed regex to only match direct interpolation (`$password`), not expressions like `${password != null}` or `${token.length}`

3. **`require_unique_iv_per_encryption`** — Had to add word boundary detection to avoid matching `activity`, `private`, `derivative`

### What TO do

| Good Pattern | Why It Works | Example |
|--------------|--------------|---------|
| **Match exact API calls** | Unambiguous | `jsonDecode()`, `DateTime.parse()` |
| **Check specific named parameters** | Clear semantics | `shrinkWrap: true`, `autoPlay: true` |
| **Detect missing required parameters** | Binary yes/no | `Image.network` without `errorBuilder` |
| **Match constructor + specific type** | Type-safe | `ScrollController` field without `dispose()` |

### Before implementing a rule

Ask yourself:
1. Can this be detected by exact API/method name matching?
2. If using variable names, will `audioVolume` or `cadenceTracker` cause false positives?
3. If matching strings, have I tested with property access (`.length`) and null checks (`!= null`)?
4. Is there a word that appears inside other common words?

**If you must use heuristics:** Use word-boundary matching (split camelCase/snake_case into words) and test extensively with real codebases.

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

The `problemMessage` appears in IDEs and tells developers what's wrong. **All messages must be prefixed with the rule name in brackets** for easy identification in VS Code's Problems panel:

```dart
problemMessage: '[rule_name] [What is wrong]. [Why it matters/consequence].',
```

#### The DX Principle: Warnings That Drive Action

A warning is only "nagging" if the developer doesn't understand *why* it matters or *how* to solve it.

| Type | Example | Developer Reaction |
|------|---------|-------------------|
| **Bad DX** | `[Error] Avoid hardcoded keys.` | "Whatever, I'll fix it later." |
| **Good DX** | `[Error] Hardcoded keys are extractable via APK decompilation (OWASP M2). Move to FlutterSecureStorage.` | "Oh, that's a real security risk." |

**Every problem message should answer:**
1. **What's wrong?** — The specific issue detected
2. **Why it matters?** — The concrete consequence (security risk, crash, memory leak, perf hit)
3. **What's the fix?** — Provided in `correctionMessage`, but hint at it when space allows

#### AI Copilot Compatibility

Developers increasingly paste lint errors into AI assistants (ChatGPT, Cursor, Copilot). Messages should contain enough factual context for an AI to understand and suggest a fix - no fluff, just problem statements and facts.

| Quality | Example | AI Can Help? |
|---------|---------|--------------|
| **Bad** | `Undisposed controller.` | No - which controller? What widget type? |
| **Good** | `TextEditingController field in StatelessWidget without disposal. Memory leak - controller outlives widget.` | Yes - AI knows to suggest StatefulWidget refactor with dispose() |

**Write messages that work as AI prompts:**
- Include the specific type (TextEditingController, not just "controller")
- Include the context (StatelessWidget, build method, async gap)
- State the consequence factually (memory leak, crash, invalid state)
- Skip marketing language - AIs don't need persuasion, just facts

**Guidelines:**
- **Always prefix with `[rule_name]`** — This makes the rule name visible in IDE Problems panels
- Start with the specific issue detected (not "Avoid..." - that's the correction)
- Include the consequence when not obvious
- Keep under 100 characters when possible (including the prefix)
- Use concrete language, not vague warnings
- Reference standards where applicable (OWASP, WCAG, platform guidelines)

**Examples:**
| BAD | GOOD |
|-----|------|
| `'Avoid using print.'` | `'[avoid_print] print() found. Will appear in production logs and expose debug info.'` |
| `'HTTP status should be checked.'` | `'[require_http_status_check] HTTP response used without status check. Crashes on 4xx/5xx.'` |
| `'Class has too many responsibilities.'` | `'[avoid_large_class] Class has >15 fields or >20 methods. Hard to test and maintain.'` |
| `'Missing tooltip.'` | `'[avoid_icon_buttons_without_tooltip] IconButton missing tooltip. Screen readers announce nothing (WCAG 2.4.4).'` |

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

- [ ] Problem message starts with `[rule_name]` prefix
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
3. **Update [README_STYLISTIC.md](https://github.com/saropa/saropa_lints/blob/main/README_STYLISTIC.md)**:
   - Add to the Quick Reference table
   - Add full documentation section with Pros/Cons and examples
4. Update rule count in README.md and ROADMAP.md if needed

### Documentation files

| File | Purpose | Update when... |
|------|---------|----------------|
| README.md | Central hub, must reference all docs | Adding any new documentation |
| README_STYLISTIC.md | Stylistic rule details | Adding/changing stylistic rules |
| ROADMAP.md | Planned features | Implementing planned rules (remove from roadmap) |
| CHANGELOG.md | Version history | Any release |
| CONTRIBUTING.md | This file | Changing contribution process |

## Pull Request Checklist

- [ ] Rule extends `SaropaLintRule` (not `DartLintRule`)
- [ ] **Impact classification set** (not just defaulting to `medium`)
- [ ] **Performance optimizations considered** (set `cost` and/or `applicableFileTypes` if appropriate)
- [ ] Rule follows naming conventions
- [ ] Added to appropriate tier(s)
- [ ] Tests pass
- [ ] Documentation updated (see Documentation Requirements above)
- [ ] CHANGELOG.md updated
- [ ] If stylistic rule: README_STYLISTIC.md updated

## Questions?

Open an issue or discussion. We're happy to help!

**Email**: [dev@saropa.com](mailto:dev@saropa.com)

---

## About This Document

> "The only way to go fast is to go well." — Robert C. Martin

> "First, solve the problem. Then, write the code." — John Johnson

**Contributing to open source** makes you a better developer. You learn from code review, discover new patterns, and build a public portfolio. Saropa Lints welcomes contributions at every skill level — from fixing typos to implementing complex AST visitors.

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
