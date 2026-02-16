# Native Analyzer Plugin Migration Roadmap

Plan for migrating saropa_lints from `custom_lint` to the native Dart 3.10+ analyzer plugin system.

**Branch**: `native-plugin-migration`
**Rollback tag**: `v4-final` (at v4.15.1)
**Target version**: `5.0.0`

## Rationale

Dart 3.10 introduced a first-party analyzer plugin system that offers:
- Native `dart analyze` / `flutter analyze` integration
- Works with `dart fix --apply`
- Better IDE performance (no separate isolate)
- No additional runtime command needed

**Primary motivation**: Quick fixes from `custom_lint` plugins **never appear in VS Code**. The Dart Analysis Server (DAS) never forwards `edit.getFixes` requests to old-protocol plugins. Dart SDK #61491 was fixed only for the native plugin system. This is the root cause and can only be solved by migrating.

**Secondary motivation**: Current `custom_lint` implementation is slow. Native plugin eliminates isolate overhead and integrates directly with the analyzer.

**Trade-offs**:
- Breaking change for existing users (v4 -> v5)
- Dependencies cannot coexist (`custom_lint_builder` requires `analyzer: ^8.0.0`, `analysis_server_plugin` v0.3.8 requires `analyzer: 10.0.2`)
- Different configuration format (`plugins:` instead of `custom_lint:`)

## Current Architecture (v4.x - custom_lint)

| Component | Implementation | Files |
|-----------|---------------|-------|
| Plugin entry | `createPlugin()` returning `PluginBase` | `lib/saropa_lints.dart` |
| Base class | `SaropaLintRule extends DartLintRule` | `lib/src/saropa_lint_rule.dart` |
| Rule registration | `_allRuleFactories` list | `lib/saropa_lints.dart` |
| Configuration | `custom_lint:` section in `analysis_options.yaml` | User's project |
| Quick fixes | `DartFix` subclasses | Various `*_rules.dart` files |
| Reporter | `SaropaDiagnosticReporter` wrapping `DiagnosticReporter` | `lib/src/saropa_lint_rule.dart` |

**Stats**: 1,677+ rules, 213 quick fixes, 5 tiers

## Target Architecture (v5.x - native plugin)

| Component | Implementation | Files |
|-----------|---------------|-------|
| Plugin entry | `final plugin` top-level variable | `lib/main.dart` |
| Base class | `SaropaAnalysisRule extends AnalysisRule` | `lib/src/native/saropa_analysis_rule.dart` |
| Rule registration | `registry.registerLintRule(rule)` in `Plugin.register()` | `lib/main.dart` |
| Configuration | Top-level `plugins:` section in `analysis_options.yaml` | User's project |
| Quick fixes | `ResolvedCorrectionProducer` + `registerFixForRule()` | TBD |
| Reporter | `SaropaDiagnosticReporter` wrapping `AnalysisRule.reportAtNode()` | `lib/src/native/saropa_reporter.dart` |

## API Changes Reference (Verified)

| custom_lint (v4) | Native Plugin (v5) | Notes |
|------------------|-------------------|-------|
| `SaropaLintRule extends DartLintRule` | `SaropaAnalysisRule extends AnalysisRule` | Different base class |
| `LintCode(name: 'x', problemMessage: 'y')` | `LintCode('x', 'y')` | Positional name/message |
| `errorSeverity: DiagnosticSeverity.WARNING` | `severity: DiagnosticSeverity.WARNING` | Parameter renamed |
| `context.registry.addMethodInvocation((node) {...})` | `context.addMethodInvocation((node) {...})` | Drop `.registry` |
| `reporter.atNode(node, code)` | `reporter.atNode(node)` | Code is implicit from rule |
| `CustomLintResolver resolver` | Removed from signature | Not needed |
| `CustomLintContext context` | `SaropaContext context` | Wraps `RuleVisitorRegistry` |
| `DartFix` | `ResolvedCorrectionProducer` | Different fix pattern |
| `NodeLintRegistry` | `RuleVisitorRegistry` | 144 `addXxx` methods |
| `PluginBase` (class) | `Plugin` (class) | Different lifecycle |
| `createPlugin()` function | `final plugin` variable | Entry point convention |

### LintCode Migration

```dart
// BEFORE (custom_lint v4):
static const LintCode _code = LintCode(
  name: 'avoid_debug_print',
  problemMessage: '[avoid_debug_print] Description here...',
  correctionMessage: 'How to fix.',
  errorSeverity: DiagnosticSeverity.WARNING,
);

// AFTER (native v5):
static const _code = LintCode(
  'avoid_debug_print',
  '[avoid_debug_print] Description here...',
  correctionMessage: 'How to fix.',
  severity: DiagnosticSeverity.WARNING,
);
```

### Rule Migration

```dart
// BEFORE (custom_lint v4):
class AvoidDebugPrintRule extends SaropaLintRule {
  const AvoidDebugPrintRule() : super(code: _code);

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      if (node.methodName.name == 'debugPrint') {
        reporter.atNode(node, code);
      }
    });
  }
}

// AFTER (native v5):
class AvoidDebugPrintNativeRule extends SaropaAnalysisRule {
  AvoidDebugPrintNativeRule() : super(code: _code);

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((node) {
      if (node.methodName.name == 'debugPrint') {
        reporter.atNode(node);
      }
    });
  }
}
```

### Consumer Configuration Migration

```yaml
# BEFORE (custom_lint v4):
custom_lint:
  rules:
    - avoid_debug_print
    - require_dispose: false

# AFTER (native v5):
plugins:
  saropa_lints: ^5.0.0
    diagnostics:
      avoid_debug_print: true
      require_dispose: false
```

## Compatibility Layer Architecture

The migration uses a compatibility layer that preserves the callback-based
`runWithReporter()` pattern, so existing rule logic requires minimal changes.

cspell:disable
```
┌─────────────────────────────────────────────────────────┐
│           Native Analyzer Plugin System                  │
│  ┌─────────────┐  ┌──────────────────┐  ┌───────────┐  │
│  │ AnalysisRule │  │ RuleVisitorReg.  │  │ RuleContext│  │
│  │ reportAtNode │  │ addXxx(rule,vis) │  │ content   │  │
│  └──────┬──────┘  └────────┬─────────┘  └─────┬─────┘  │
├─────────┼──────────────────┼───────────────────┼────────┤
│  Compatibility Layer (lib/src/native/)                    │
│  ┌──────┴──────┐  ┌────────┴─────────┐  ┌─────┴─────┐  │
│  │ SaropaAnalys│  │ SaropaContext    │  │CompatVis. │  │
│  │ Rule        │  │ addXxx(callback) │──│ onXxx     │  │
│  │ runWithRep()│  │ fileContent      │  │ visitXxx  │  │
│  └──────┬──────┘  └────────┬─────────┘  └───────────┘  │
│  ┌──────┴──────┐           │                             │
│  │ SaropaRepr. │           │                             │
│  │ atNode(node)│           │                             │
│  │ atToken()   │           │                             │
│  └─────────────┘           │                             │
├────────────────────────────┼────────────────────────────┤
│  Existing Rule Logic       │                             │
│  ┌─────────────────────────┴──────────────────────────┐ │
│  │ context.addMethodInvocation((node) {               │ │
│  │   if (condition) reporter.atNode(node);            │ │
│  │ });                                                 │ │
│  └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

**Files:**

| File | Purpose | Lines |
|------|---------|-------|
| `saropa_analysis_rule.dart` | Base class extending `AnalysisRule`, preserves `runWithReporter()` | ~90 |
| `saropa_context.dart` | Wraps `RuleVisitorRegistry` with 80 callback-based `addXxx()` methods | ~480 |
| `saropa_reporter.dart` | Wraps `AnalysisRule.reportAtNode()` with `atNode()`/`atToken()`/`atOffset()` | ~55 |
| `compat_visitor.dart` | `SimpleAstVisitor` bridge with 80 node type callbacks | ~270 |

## Migration Phases

### Phase 0: Research & Decision - DONE

- [x] Study `analysis_server_plugin` source code
- [x] Document all API differences (see table above)
- [x] Identify dependency incompatibility (cannot coexist - clean break required)
- [x] Confirm fix API is stable (`ResolvedCorrectionProducer`, `FixKind`, `CorrectionApplicability`)
- [x] Confirm tier system maps to `diagnostics:` configuration
- [x] Confirm `register(PluginRegistry)` provides init lifecycle

**Decision**: Proceed with in-place migration (same package, breaking v5.0.0 release).

---

### Phase 1: Infrastructure - DONE

- [x] Create feature branch `native-plugin-migration`
- [x] Tag `v4-final` at v4.15.1 for rollback
- [x] Swap dependencies: remove `custom_lint_builder`, add `analysis_server_plugin: ^0.3.0`
- [x] Bump SDK to `>=3.10.0`, version to `5.0.0-dev.1`
- [x] Create compatibility layer (4 files in `lib/src/native/`)
- [x] Create plugin entry point (`lib/main.dart`)
- [x] Migrate 2 proof-of-concept rules (AvoidDebugPrint, AvoidEmptySetState)
- [x] Verify: `dart pub get` succeeds, `dart analyze lib/src/native/ lib/main.dart` = zero issues

**Resolved to**: `analysis_server_plugin 0.3.3` with `analyzer 8.4.0`

---

### Phase 2: Quick Fix Infrastructure - TODO

**Goal**: Bridge `ResolvedCorrectionProducer` for existing fix patterns

#### 2.1 Fix Bridge

Create `lib/src/native/saropa_fix.dart`:

```dart
abstract class SaropaFix extends ResolvedCorrectionProducer {
  @override
  FixKind get fixKind;

  @override
  CorrectionApplicability get applicability =>
    CorrectionApplicability.singleLocation;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    // Subclasses implement fix logic
  }
}
```

Register fixes with:
```dart
registry.registerFixForRule(rule.code, (context) => MyFix(context));
```

#### 2.2 PoC Fix

Migrate `_CommentOutDebugPrintFix` as proof-of-concept.

#### Deliverables
- [ ] `lib/src/native/saropa_fix.dart` - Fix base class
- [ ] Migrate 1-2 proof-of-concept fixes
- [ ] Verify quick fixes appear in VS Code (the whole reason for this migration)

---

### Phase 3: Reporter Features - TODO

**Goal**: Add back saropa features to `SaropaDiagnosticReporter`

Currently the reporter is minimal (Phase 1). Add back:

| Feature | Priority | Notes |
|---------|----------|-------|
| Ignore comment checking (`IgnoreUtils`) | High | Already works with pure `analyzer` imports |
| Baseline suppression (`BaselineManager`) | Medium | Needs import cleanup from custom_lint deps |
| Impact tracking (`ImpactTracker`) | Low | Analytics feature |
| Progress tracking (`ProgressTracker`) | Low | Analytics feature |
| Severity overrides | Medium | Via `diagnostics:` config in `analysis_options.yaml` |

#### Deliverables
- [ ] Add ignore comment checking to reporter
- [ ] Add baseline suppression
- [ ] Add severity override support
- [ ] Add impact/progress tracking

---

### Phase 4: Bulk Rule Migration - TODO

**Goal**: Migrate all 1,677+ rules using the compatibility layer

#### 4.1 Migration per Rule (Mechanical Changes)

Each rule needs these changes:
1. `extends SaropaLintRule` -> `extends SaropaAnalysisRule`
2. `LintCode(name: 'x', problemMessage: 'y', errorSeverity: s)` -> `LintCode('x', 'y', severity: s)`
3. Drop `resolver` parameter from `runWithReporter`
4. `context.registry.addXxx(` -> `context.addXxx(`
5. `reporter.atNode(node, code)` -> `reporter.atNode(node)`
6. Remove `custom_lint_builder` imports, add native imports

#### 4.2 Batch Strategy

| Batch | Category | Count | Complexity |
|-------|----------|-------|------------|
| 1 | Core Dart rules | ~200 | Low (simple patterns) |
| 2 | Flutter widget rules | ~300 | Low (MethodInvocation/InstanceCreation) |
| 3 | Security rules | ~150 | Medium (string analysis) |
| 4 | Accessibility rules | ~100 | Low (widget patterns) |
| 5 | Package-specific (Riverpod, Bloc, etc.) | ~500 | Medium (package detection) |
| 6 | Performance/Architecture rules | ~400 | Medium-High (cross-node analysis) |

#### 4.3 Automated Migration Script

Create `scripts/migrate_to_native.dart` to handle mechanical transformations:
- Import rewrites
- LintCode constructor migration
- `runWithReporter` signature change
- `context.registry.` -> `context.` prefix removal
- `reporter.atNode(node, code)` -> `reporter.atNode(node)` argument removal

Manual review needed for:
- Rules using `CustomLintResolver` features
- Rules with custom `shouldAnalyze()` / content pre-filtering
- Complex fix implementations
- Rules accessing `ProjectContext` features that need adaptation

#### Deliverables
- [ ] Migration script (`scripts/migrate_to_native.dart`)
- [ ] Migrate and verify batch 1 (core rules)
- [ ] Migrate and verify batches 2-6
- [ ] Update `lib/main.dart` to register all migrated rules
- [ ] Remove old `lib/saropa_lints.dart` custom_lint entry point
- [ ] Remove `custom_lint_builder` dependency entirely

---

### Phase 5: Configuration & Tier System - TODO

**Goal**: New configuration format and tier presets

#### 5.1 Preset Files

Create preset configs in `lib/presets/`:

```yaml
# lib/presets/recommended.yaml
plugins:
  saropa_lints:
    diagnostics:
      avoid_debug_print: warning
      avoid_empty_set_state: warning
      # ... all recommended-tier rules
```

#### 5.2 Init Command Update

Update `bin/init.dart` to generate new format:

```bash
dart run saropa_lints:init --tier recommended
# Generates analysis_options.yaml with plugins: section
```

#### Deliverables
- [ ] Preset configuration files for each tier
- [ ] Update init command for new format
- [ ] Migration guide for v4 -> v5 users

---

### Phase 6: Testing & Release - TODO

**Goal**: Comprehensive testing and release

#### 6.1 Testing

| Test Type | Coverage |
|-----------|----------|
| Unit tests | All migrated rules detect correctly |
| Quick fix tests | Fixes appear in VS Code, apply correctly |
| Integration tests | Plugin loads, registers rules, analyzes files |
| Regression tests | Compare output with v4 on same codebase |
| Performance tests | Benchmark against custom_lint on large projects |
| IDE tests | VS Code squiggles, Problems panel, quick fixes |

#### 6.2 Release Plan

1. `5.0.0-dev.1` - Current state (infrastructure + PoC)
2. `5.0.0-beta.1` - All rules migrated, basic quick fixes
3. `5.0.0-beta.2` - All quick fixes, reporter features
4. `5.0.0` - Stable release after beta feedback
5. Maintain `4.x` security fixes during transition

#### Deliverables
- [ ] Test suite covering all migrated rules
- [ ] Beta releases for feedback
- [ ] Migration guide (`MIGRATION_V5.md`)
- [ ] Stable release
- [ ] Deprecation notice for v4

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| API instability | Low | High | Using `^0.3.0` constraint, resolved to 0.3.3 with analyzer 8.4.0 |
| Quick fixes still don't work | Low | Critical | This is the primary motivation; verify in Phase 2 |
| Feature loss (baseline, impact) | Medium | Medium | Compatibility layer preserves reporter; re-add features in Phase 3 |
| Performance regression | Low | Medium | Native should be faster; benchmark in Phase 6 |
| User migration friction | High | Medium | Comprehensive migration guide, preset configs |
| `analyzer` version conflicts | Medium | High | Consumer may pin different analyzer version |

## Verified Facts

- `analysis_server_plugin` 0.3.3 resolves with `analyzer` 8.4.0
- `SimpleAstVisitor` has 179 visit methods (no `visitFormalParameter`, `visitStringLiteral`, `visitFunctionBody`)
- `RuleVisitorRegistry` has 144 `addXxx(AbstractAnalysisRule, AstVisitor)` methods
- `LintCode` constructor: `const LintCode(String name, String problemMessage, {correctionMessage, severity = DiagnosticSeverity.INFO})`
- `AnalysisRule` has `reportAtNode()`, `reportAtToken()`, `reportAtOffset()` - code is implicit from `diagnosticCode`
- `PluginRegistry` has `registerLintRule()`, `registerWarningRule()`, `registerFixForRule(LintCode, ProducerGenerator)`
- `IgnoreUtils` only depends on `analyzer` (no custom_lint imports) - can be reused directly
- Plugin entry point: `lib/main.dart` with `final plugin = MyPlugin()` top-level variable
- Consumer config: top-level `plugins:` section in `analysis_options.yaml`

## File Index

### New Files (Phase 1)

| File | Status | Purpose |
|------|--------|---------|
| `lib/main.dart` | Done | Plugin entry point |
| `lib/src/native/saropa_analysis_rule.dart` | Done | Base class preserving `runWithReporter()` |
| `lib/src/native/saropa_context.dart` | Done | Registry wrapper (80 callback methods) |
| `lib/src/native/saropa_reporter.dart` | Done | Reporter wrapper (minimal Phase 1) |
| `lib/src/native/compat_visitor.dart` | Done | SimpleAstVisitor bridge (80 node types) |
| `lib/src/native/poc_rules.dart` | Done | 2 migrated PoC rules |

### Modified Files

| File | Change |
|------|--------|
| `pubspec.yaml` | Swapped deps, bumped SDK/version |

### Files to Remove (Phase 4)

| File | Reason |
|------|--------|
| `lib/saropa_lints.dart` | Old custom_lint entry point |
| `lib/custom_lint_client.dart` | Old custom_lint client |

## References

- [Dart Analyzer Plugins](https://dart.dev/tools/analyzer-plugins)
- [GitHub #53402 - New analyzer plugin system](https://github.com/dart-lang/sdk/issues/53402)
- [GitHub #61491 - Quick fixes not forwarded to old plugins](https://github.com/dart-lang/sdk/issues/61491)
- [analysis_server_plugin package](https://github.com/dart-lang/sdk/tree/main/pkg/analysis_server_plugin)
- [Writing rules guide](https://github.com/dart-lang/sdk/blob/main/pkg/analysis_server_plugin/doc/writing_rules.md)
- [Migration blog post](https://leancode.co/blog/migrating-to-dart-analyzer-plugin-system)

---

## Appendix: Reporting Capabilities

| Output | v4 (custom_lint) | v5 (native) | Notes |
|--------|------------------|-------------|-------|
| IDE "PROBLEMS" panel | Yes | Yes (faster) | Same UX |
| Editor squiggles | Yes | Yes (faster) | Same UX |
| Quick fixes (lightbulb) | **Broken** (never appears) | Yes | Primary motivation |
| `dart analyze` | No | Yes | Major benefit |
| `dart fix --apply` | No | Yes | Major benefit |
| Terminal output | `dart run custom_lint` | `dart analyze` | Simpler |

---

_Last updated: 2026-02-16_
