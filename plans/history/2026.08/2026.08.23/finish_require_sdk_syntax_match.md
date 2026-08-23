# Finish Report: require_sdk_syntax_match rule

New lint rule `require_sdk_syntax_match` cross-references the Dart SDK lower bound declared in `pubspec.yaml` against syntax features used in source files, flagging code that requires a newer SDK than the project declares.

## Finish Report (2026-08-23)

### What changed

A new `SaropaLintRule` subclass `RequireSdkSyntaxMatchRule` was added at `lib/src/rules/config/sdk_syntax_match_rule.dart`. The rule caches the parsed SDK lower bound per project root using `ProjectContext.findProjectRoot` and `parsePubspecConstraints`, then conditionally registers AST visitor callbacks for version-gated syntax features:

- **Dart 3.0:** `RecordTypeAnnotation`, `RecordLiteral`, `SwitchExpression`, `PatternVariableDeclaration`, and `ClassDeclaration` with `sealed`/`base`/`interface`/`final` modifiers.
- **Dart 3.3:** `ExtensionTypeDeclaration`.
- **Dart 3.6:** `IntegerLiteral` and `DoubleLiteral` with `_` digit separators in the token lexeme.

Dart 3.4 wildcard variables and 3.13 primary constructors are documented as undetectable at the AST level (syntax is identical to older Dart; only semantics changed).

The rule is registered in `_allRuleFactories` (`lib/saropa_lints.dart`), exported from `all_rules.dart`, and assigned to `comprehensiveOnlyRules` in `tiers.dart`. Tier: Comprehensive. Severity: WARNING. Impact: warning. RuleType: bug. Cost: low.

Generated files are excluded by the default `skipGeneratedCode` behavior. Test files are excluded via `TestRelevance.never`.

### Registration

- Factory: `lib/saropa_lints.dart` — `RequireSdkSyntaxMatchRule.new`
- Export: `lib/src/rules/all_rules.dart` — `export 'config/sdk_syntax_match_rule.dart'`
- Tier: `lib/src/tiers.dart` — `'require_sdk_syntax_match'` in `comprehensiveOnlyRules`

### Testing

- Instantiation + metadata pin test added to `test/config/pubspec_constraint_parser_test.dart`.
- Integrity tests (24/24) and parser tests (25/25) pass.
- Behavioral testing follows the same convention as the five existing pubspec constraint rules: scan CLI verification (the rules target .yaml state read from .dart file context, so unit-level behavioral tests cannot exercise the real code path).

### Design decisions

- **Caching pattern:** Uses `static final Map<String, SemverParts?>` with `putIfAbsent`, matching the `static final Set<String> _reportedRoots` pattern used by all five existing pubspec constraint rules. No mtime invalidation — a live pubspec edit during an IDE session requires analysis server restart, consistent with all sibling rules.
- **Per-file reporting:** Unlike the existing pubspec rules (which report once per root on the first lib/ file), this rule reports on each violating AST node, giving precise editor squiggles on the problematic syntax.
- **Quick fix:** `RaiseSdkLowerBoundFix` (`lib/src/fixes/config/raise_sdk_lower_bound_fix.dart`) offers "Raise SDK lower bound in pubspec.yaml" — the first fix in the codebase to edit a non-Dart file, using `addGenericFileEdit` on the pubspec path. Maps the diagnostic's covering AST node type to the required SDK version and replaces the `>=X.Y.Z` lower bound via regex offset.

### Proposal origin

Implemented from `bugs/proposal_require_sdk_syntax_match.md` (whitepaper evaluation — "Overcoming AI Model Regression in Dart 3+"). Archived to `plans/history/2026.08/2026.08.23/`.
