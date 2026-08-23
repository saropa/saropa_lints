# PROPOSAL: `require_sdk_syntax_match` — Flag Dart syntax features incompatible with declared SDK lower bound

**Status: Implemented**

Created: 2026-08-23
Category: `config/pubspec_constraint_rules`
Proposed tier: Comprehensive
Proposed severity: WARNING
Source: Whitepaper evaluation — "Overcoming AI Model Regression in Dart 3+"

---

## Summary

Cross-reference the SDK lower bound in `pubspec.yaml` against Dart syntax
features used in source files. Flag when code uses language features unavailable
at the declared minimum SDK version. AI code generators ignore SDK constraints
entirely and produce syntax for the latest Dart version regardless of the
project's declared minimum.

---

## Problem

A project declares `sdk: ">=3.0.0 <4.0.0"` but an AI generates code using
primary constructors (requires >=3.13.0), digit separators (requires >=3.6.0),
or other version-gated syntax. The code compiles on the developer's machine
(running a newer SDK) but fails for users or CI environments at the declared
minimum version.

No existing Dart SDK lint or saropa_lints rule catches this. The pubspec
constraint rules (`require_sdk_upper_bound`, `avoid_unbounded_dependency`, etc.)
validate constraint hygiene but never cross-reference actual syntax.

---

## Feature-to-Version Mapping

| Dart Version | Features |
|---|---|
| 3.0 | Records, patterns, sealed/final/base/interface class modifiers, switch expressions, if-case, guard clauses |
| 3.2 | Unnamed libraries |
| 3.3 | Extension types |
| 3.4 | Wildcard variables (`_` as non-binding), `macro` keyword (experimental) |
| 3.6 | Digit separators in numeric literals (`1_000_000`) |
| 3.13 | Primary constructors |

This mapping must be maintained as a versioned constant in the rule
implementation, updated when new Dart versions add syntax.

---

## Detection Logic

### At plugin init (once per analysis context):

1. Locate `pubspec.yaml` via `AnalysisContext.contextRoot.root`
2. Parse the `environment.sdk` constraint
3. Extract the lower bound version (e.g., `>=3.0.0` → `3.0.0`)
4. Cache the parsed version per context root

### Per source file:

For each AST node, check whether the syntax feature requires a version higher
than the cached lower bound:

- `RecordTypeAnnotation`, `RecordLiteral` → requires 3.0
- `SwitchExpression` → requires 3.0
- `SealedDeclaration` (class modifier) → requires 3.0
- `PatternVariableDeclaration`, `IfCaseClause` → requires 3.0
- `ExtensionTypeDeclaration` → requires 3.3
- `WildcardPattern` (non-binding `_`) → requires 3.4
- Numeric literals with `_` separators → requires 3.6
- Primary constructors on non-extension-type classes → requires 3.13

### Exclusions (expect NO lint)

- Features available at or below the declared lower bound
- Test files (may use a different SDK constraint via `test/pubspec.yaml`)
- Generated files (`*.g.dart`, `*.freezed.dart`)
- Files under `dependency_overrides/` or `example/`

---

## Implementation Challenges

1. **Pubspec access:** The analyzer plugin API provides
   `ResolvedUnitResult.session.analysisContext.contextRoot.root` to locate the
   workspace root. Reading and parsing `pubspec.yaml` at init is straightforward
   via `ResourceProvider`, but error handling is needed for malformed or missing
   pubspec files.

2. **Monorepo support:** In a monorepo, each package has its own pubspec. The
   rule must use the nearest ancestor `pubspec.yaml` to each source file, not a
   single root pubspec.

3. **Version constraint parsing:** The `pub_semver` package (already a
   saropa_lints dependency) handles constraint parsing. Extract the lower bound
   from `VersionConstraint.parse(sdkConstraint)`.

4. **AST node identification:** Some features (records, patterns) require
   checking specific node types that only exist in newer analyzer versions. The
   analyzer 12.x API covers all Dart 3.0–3.13 node types. Newer Dart features
   will need analyzer updates.

5. **Startup cost:** Parsing pubspec adds ~1ms per analysis context. Acceptable
   since it's cached per context root.

---

## Quick Fix

No automatic fix — the rule flags a constraint mismatch that requires a
human decision: either raise the SDK lower bound or rewrite the code to avoid
the newer syntax. A code action could offer "Raise SDK lower bound to >=X.Y.0"
as a pubspec edit, but this changes the project's compatibility surface and
should not be automatic.

---

## Fixture Cases

The fixture needs a mock pubspec with a low SDK constraint and source files
using various version-gated features:

1. Record type with SDK >=2.19.0 — expect LINT
2. Switch expression with SDK >=2.19.0 — expect LINT
3. Sealed class with SDK >=2.19.0 — expect LINT
4. Extension type with SDK >=3.0.0 — expect LINT (requires 3.3)
5. Record type with SDK >=3.0.0 — expect NO lint
6. Primary constructor with SDK >=3.0.0 — expect LINT (requires 3.13)
7. Primary constructor with SDK >=3.13.0 — expect NO lint
8. Digit separator with SDK >=3.0.0 — expect LINT (requires 3.6)
9. All features with SDK >=3.13.0 — expect NO lint
10. Generated file (.g.dart) with any feature — expect NO lint

---

## Risk Assessment

- **False positive risk: LOW** — the feature-to-version mapping is deterministic
  and based on Dart language spec. The main risk is an incomplete mapping that
  misses a version-gated feature (false negative, not false positive).
- **Codebase impact: MEDIUM** — comprehensive tier, WARNING severity. Projects
  with tight SDK constraints will see warnings on AI-generated code that uses
  newer syntax. This is the intended behavior.
- **Maintenance burden: MEDIUM** — the feature-to-version mapping must be
  updated with each Dart release. This is a ~quarterly task.
- **Analyzer compatibility:** Requires analyzer ^12.1.0 (current cap). All
  Dart 3.0–3.13 AST node types are available. Future Dart versions may add
  node types that require analyzer updates.
