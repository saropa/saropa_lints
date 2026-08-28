# Analyzer 12 → 13 Migration Plan

**Created:** 2026-08-23
**Trigger:** Flutter 3.47.1 ships `meta ^1.18.3`, clearing the blocker.
**Status:** Not started
**Related:** `PLAN_migration_plugin_system.md` (plugin system migration, separate concern)

---

## Background

Flutter 3.47.1 (Dart 3.13.1) ships `meta ^1.18.3`. Previously Flutter 3.44.9 pinned
meta exactly `1.18.0`, which blocked analyzer 13+ (requires `meta ^1.18.3`). The HARD
STOP comments in `pubspec.yaml` are now stale — the constraint can move.

## Scope Summary

| Metric | Count |
|--------|-------|
| Files importing `package:analyzer/` | 526 |
| `NamedExpression` references | 804 across 144 files |
| `DefaultFormalParameter\|SimpleFormalParameter\|FunctionTypedFormalParameter` | 191 across 42 files |
| `visitNamedExpression` etc. (visitor overrides) | 16 across 7 files |
| `.arguments` property access | 1,073 across 169 files |
| Private API imports (`src/`) | 3 files |
| `RecordPatternField` | 0 (no impact) |

---

## Phase 1: Preparation (no analyzer bump yet)

### 1A. Compatibility layer in `compat_visitor.dart`

`lib/src/native/compat_visitor.dart` already exists. Extend it to abstract over
the renamed types so rule files don't need conditional imports.

- [ ] Audit `compat_visitor.dart` for existing shims
- [ ] Design typedefs/wrappers for the renamed classes (if feasible under analyzer 12)

### 1B. Reduce `NamedExpression` surface area

804 references is the biggest cost. Before bumping, refactor to centralize
`NamedExpression` handling into shared utilities where possible, reducing the
number of individual call sites that need updating.

- [ ] Grep for patterns: `is NamedExpression`, `as NamedExpression`, `NamedExpression(`
- [ ] Identify clusters (widget rules have the most — 40+ in `widget_patterns_avoid_prefer_rules.dart`)
- [ ] Extract helper methods in shared utils for common `NamedExpression` operations

### 1C. Audit private API imports

3 files use `package:analyzer/src/` imports that will likely break:

| File | Import | Purpose |
|------|--------|---------|
| `lib/src/scan/scan_runner.dart` | `src/string_source.dart` | String-based analysis |
| `test/support/resolved_rule_harness.dart` | `src/string_source.dart` | Test harness |
| `test/integrity/saropa_plugin_registration_test.dart` | `src/lint/config.dart` | `RuleConfig` |

- [ ] Find public API replacements for each
- [ ] If none exist, document workaround

---

## Phase 2: Bump dependencies

### 2A. Update `pubspec.yaml`

```yaml
environment:
  sdk: ">=3.13.0 <4.0.0"    # was >=3.9.0

dependencies:
  analyzer: ^13.1.0           # was ^12.1.0
  analyzer_plugin: ^0.15.0    # was ^0.14.8
  analysis_server_plugin: TBD # was ^0.3.14; verify compatible version
  meta: ^1.18.3               # was ^1.18.0

dev_dependencies:
  test: ^1.31.2               # was ^1.31.1 (cap removed)
```

- [ ] Remove all HARD STOP comments (lines ~87–140 in pubspec.yaml)
- [ ] Update the `re-verified` comment with new date
- [ ] Run `dart pub get` and resolve any transitive conflicts

### 2B. Update `analysis_server_plugin` pin

The pinned version `0.3.14` targets analyzer 12. Check which version targets
analyzer 13 and is compatible.

- [ ] Check `analysis_server_plugin` changelog for analyzer 13 compatibility
- [ ] Verify no breaking API changes in the plugin registration

---

## Phase 3: Apply AST renames

### Rename table

| Old | New | Strategy |
|-----|-----|----------|
| `NamedExpression` | `NamedArgument` (in ArgumentList) / `RecordLiteralNamedField` (in RecordLiteral) | Context-dependent — most saropa usage is arguments, not record fields. Audit each file. |
| `SimpleFormalParameter` | `RegularFormalParameter` | Simple rename |
| `FunctionTypedFormalParameter` | `RegularFormalParameter` | Simple rename (merged) |
| `DefaultFormalParameter` | Removed — use `defaultClause` property on `FormalParameter` | Structural change |
| `visitNamedExpression` | `visitNamedArgument` + `visitRecordLiteralNamedField` | Visitor split |
| `visitSimpleFormalParameter` | `visitRegularFormalParameter` | Simple rename |
| `visitFunctionTypedFormalParameter` | `visitRegularFormalParameter` | Simple rename |
| `visitDefaultFormalParameter` | Removed | Remove overrides, use `defaultClause` |
| `RecordPatternField` | `PatternField` | 0 references — no work |
| `RecordPatternFieldName` | `PatternFieldName` | 0 references — no work |

### Type/return changes

| API | Old type | New type | References |
|-----|----------|----------|-----------|
| `ArgumentList.arguments` | `NodeList<Expression>` | `NodeList<Argument>` | ~1,073 `.arguments` accesses (not all are ArgumentList — need filtering) |
| `Label.name` | `SimpleIdentifier` | `Token` | Low usage |
| `BreakStatement.label` | `SimpleIdentifier?` | `LabelReference?` | Low usage |
| `ContinueStatement.label` | `SimpleIdentifier?` | `LabelReference?` | Low usage |

### Element API changes

| Old | New |
|-----|-----|
| `FormalParameterElement.isInitializingFormal` | `element is FieldFormalParameterElement` |
| `FormalParameterElement.isSuperFormal` | `element is SuperFormalParameterElement` |

### Execution order

1. `SimpleFormalParameter` → `RegularFormalParameter` (simple rename, 42 files)
2. `FunctionTypedFormalParameter` → `RegularFormalParameter` (merge, same 42 files)
3. `DefaultFormalParameter` → structural refactor (42 files)
4. Visitor method renames (7 files)
5. `NamedExpression` → context-split (144 files — the big one)
6. `ArgumentList.arguments` type changes (filter to actual ArgumentList usages)
7. Element API changes (grep for `isInitializingFormal`, `isSuperFormal`)
8. Private API replacements (3 files)
9. `ClassBody` sealed class handling (if any rules inspect class bodies directly)

---

## Phase 4: Handle primary constructor syntax

Dart 3.13 makes primary constructors stable. Rules that inspect constructors,
class declarations, or formal parameters must handle the new form:

```dart
class Point(final int x, final int y);
```

- [ ] Identify rules that visit `ConstructorDeclaration` (159 refs) or `ClassDeclaration` (656 refs)
- [ ] Test each against primary constructor fixtures
- [ ] Add fixture files in `example/lib/` for primary constructor patterns

---

## Phase 5: Review overlap with new official lints

Six new lints in Dart 3.13 for primary constructor adoption:

1. `use_declaring_parameters`
2. `initialize_in_field_declaration`
3. `unnecessary_const_in_enum_constructor`
4. `unnecessary_type_name_in_constructor`
5. `unnecessary_primary_constructor_body`
6. `empty_container_bodies`

Three deprecated lints:
1. `avoid_private_typedef_functions`
2. `one_member_abstracts`
3. `avoid_null_checks_in_equality_operators`

- [ ] Check if any saropa rules duplicate these
- [ ] Check if any saropa rules reference deprecated lints in docs/messages
- [ ] Consider adding the new lints to tier recommendations

---

## Phase 6: Validation

- [ ] `dart pub get` resolves cleanly
- [ ] `dart test` passes (scoped to changed files, then full suite)
- [ ] `dart format .` — reformat if needed (3.13 formatter changes)
- [ ] Scan CLI works against test projects
- [ ] All example fixtures compile
- [ ] No regressions in existing rule behavior

---

## Risk Notes

- **`NamedExpression` split is the hardest part.** 804 references across 144 files,
  each needs context analysis. Most will be `NamedArgument` (widget constructor
  named params), but some may be record fields. Batch by directory (widget rules
  first — they have the most).

- **`ArgumentList.arguments` type change** may cause cascading type errors if code
  does `arguments.whereType<NamedExpression>()` (double rename needed).

- **Private API imports** may not have public replacements — may need to vendor
  or find alternative approaches.

- **Minimum SDK bump to 3.13.0** drops support for consumers on older Flutter.
  This is acceptable since the package already targets >=3.9.0 and Flutter 3.47
  is now stable.

---

## Session Strategy

This is too large for a single session. Recommended breakdown:

1. **Session 1 (Opus):** Phase 1 — preparation, refactor NamedExpression helpers
2. **Session 2 (Sonnet):** Phase 2 + Phase 3 steps 1–4 (bump deps, simple renames)
3. **Session 3 (Sonnet):** Phase 3 step 5 (NamedExpression split — the big one)
4. **Session 4 (Sonnet):** Phase 3 steps 6–9 + Phase 4 (remaining renames + primary constructors)
5. **Session 5 (Sonnet):** Phase 5 + Phase 6 (lint overlap review + full validation)
