# Copilot & AI Agent Instructions for saropa_lints

## Project Overview

**saropa_lints** is a Dart/Flutter custom lint rules package with 1600+ rules for security, accessibility, performance, and library-specific anti-patterns. The project is highly modular, with rules grouped by severity ("tiers") and by domain (Flutter, Riverpod, Bloc, etc.).

### Key Directories

- lib/ — Core lint rule implementations and registration
- example/ — Fixtures and test cases for rules (violations marked with // LINT)
- test/ — Unit tests for lint rules
- doc/guides/ — Integration guides for major libraries (GetX, Riverpod, Bloc, etc.)
- bin/ — CLI tools for config generation and reporting

## Architecture & Patterns

- Rule Implementation: Each rule is a Dart class (usually extending DartLintRule or SaropaLintRule) in lib/src/rules/. Rules must be registered in both lib/src/rules/all_rules.dart and assigned to a tier in lib/src/tiers.dart.

* Tier System: Rules are grouped into 5 tiers (essential, recommended, professional, comprehensive, insanity). Config is generated via CLI, not plugin config. See README.md for tier details.
* Domain-Specific Rules: Many rules target specific libraries (e.g., Riverpod, Bloc, GetX, Isar, Hive, Firebase). See doc/guides/ for anti-patterns and integration details.
* Security/OWASP Mapping: Security rules expose OWASP categories programmatically. See README.md for OWASP mapping.

- Fixtures & Tests: Example violations must be marked with // LINT in both fixtures and tests for automated validation.

## Developer Workflows

- Run linter: dart run custom_lint (or use the VS Code task "Run Saropa Lints")

* Generate config: dart run saropa_lints:init --tier <tier> (see README.md for options)

- Test rules: dart test
- Format code: dart format .
- CI: GitHub Actions in .github/workflows/ci.yml runs analysis and tests

## Project-Specific Conventions

- Rule registration is mandatory in both all_rules.dart and tiers.dart.
- ROADMAP.md: All rules must be documented in ROADMAP.md as | rule_name | Tier | Severity | Description |.
- Suppression: Use // ignore: rule_name or // ignore_for_file: rule_name (hyphenated or snake_case) and always add a comment explaining why.

* AI/Agent Message Style: Lint error messages should be factual, specific, and context-rich (see CONTRIBUTING.md).

- After structural changes: Update CODEBASE_INDEX.md and CODE_INDEX.md.

## Integration Points

- Library-specific rules: See doc/guides/ for patterns and anti-patterns for Riverpod, Bloc, GetX, Hive, Isar, etc.
- Performance/CI: Use different tiers for local vs CI (see PERFORMANCE.md). Example:
  - Local: dart run saropa_lints:init --tier essential
  - CI: dart run saropa_lints:init --tier comprehensive -o analysis_options.ci.yaml

## References

README.md Project intro, tier system, and quick start  
CONTRIBUTING.md Rule authoring, message style, and AI compatibility  
ROADMAP.md Rule list and roadmap  
doc/guides/ Library integration patterns  
CLAUDE.md Agent/AI-specific workflow and skills

---

For unclear or missing conventions, see CLAUDE.md and README.md for the latest project-specific guidance.
