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

**Stats**: 1,677+ rules, 108 quick fixes (all with real AST-based implementations), 5 tiers

## Target Architecture (v5.x - native plugin)

| Component | Implementation | Files |
|-----------|---------------|-------|
| Plugin entry | `final plugin` top-level variable | `lib/main.dart` |
| Base class | `SaropaLintRule extends AnalysisRule` | `lib/src/saropa_lint_rule.dart` |
| Rule registration | `registry.registerLintRule(rule)` in `Plugin.register()` | `lib/main.dart` |
| Configuration | Top-level `plugins:` section in `analysis_options.yaml` | User's project |
| Quick fixes | `SaropaFixProducer` + `registerFixForRule()` | `lib/src/native/saropa_fix.dart`, `lib/src/fixes/` |
| Reporter | `SaropaDiagnosticReporter` wrapping `AnalysisRule.reportAtNode()` | `lib/src/saropa_lint_rule.dart` |
| Per-file filtering | `SaropaContext._wrapCallback()` with path/content caching | `lib/src/native/saropa_context.dart` |

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

## Architecture

The migration uses a compatibility layer that preserves the callback-based
`runWithReporter()` pattern, so existing rule logic requires minimal changes.

cspell:disable
```
┌──────────────────────────────────────────────────────────┐
│           Native Analyzer Plugin System                   │
│  ┌─────────────┐  ┌──────────────────┐  ┌────────────┐  │
│  │ AnalysisRule │  │ RuleVisitorReg.  │  │ RuleContext │  │
│  │ reportAtNode │  │ addXxx(rule,vis) │  │ content    │  │
│  └──────┬──────┘  └────────┬─────────┘  └──────┬─────┘  │
├─────────┼──────────────────┼────────────────────┼────────┤
│  Compatibility Layer (lib/src/native/)                     │
│  ┌──────┴──────┐  ┌────────┴─────────┐  ┌──────┴─────┐  │
│  │SaropaLint   │  │ SaropaContext    │  │CompatVis.  │  │
│  │Rule         │  │ addXxx(callback) │──│ onXxx      │  │
│  │ runWithRep()│  │ _wrapCallback()  │  │ visitXxx   │  │
│  │ fixGens     │  │ fileContent      │  └────────────┘  │
│  └──────┬──────┘  └────────┬─────────┘                   │
│  ┌──────┴──────┐  ┌────────┴─────────┐                   │
│  │SaropaRepr.  │  │SaropaFixProducer │                   │
│  │ atNode(node)│  │ compute(builder) │                   │
│  │ atToken()   │  │ fixKind          │                   │
│  └─────────────┘  └──────────────────┘                   │
├──────────────────────────────────────────────────────────┤
│  Existing Rule Logic                                      │
│  ┌────────────────────────────────────────────────────┐  │
│  │ context.addMethodInvocation((node) {               │  │
│  │   if (condition) reporter.atNode(node);            │  │
│  │ });                                                 │  │
│  └────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

**Files:**

| File | Purpose | Lines |
|------|---------|-------|
| `saropa_lint_rule.dart` | Base class extending `AnalysisRule`, `runWithReporter()`, `SaropaDiagnosticReporter` | ~2400 |
| `native/saropa_context.dart` | Wraps `RuleVisitorRegistry` with 83 `addXxx()` methods + per-file filtering | ~660 |
| `native/saropa_fix.dart` | `SaropaFixProducer` base class, `SaropaFixGenerator` typedef | ~67 |
| `native/compat_visitor.dart` | `SimpleAstVisitor` bridge with 83 node type callbacks | ~270 |
| `fixes/<category>/*.dart` | 108 quick fix implementations (all with real AST-based logic) | ~40 each |

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
- [x] Swap dependencies: remove `custom_lint_builder`, add `analysis_server_plugin: ^0.3.3`
- [x] Bump SDK to `>=3.10.0`, version to `5.0.0-dev.1`
- [x] Create compatibility layer (`saropa_context.dart`, `compat_visitor.dart`)
- [x] Create plugin entry point (`lib/main.dart`)
- [x] Migrate 2 proof-of-concept rules (AvoidDebugPrint, AvoidEmptySetState)
- [x] Verify: `dart pub get` succeeds, `dart analyze` = zero issues

**Resolved to**: `analysis_server_plugin 0.3.3` with `analyzer 8.4.0`

---

### Phase 2: Quick Fix Infrastructure - DONE

**Goal**: Bridge `ResolvedCorrectionProducer` for existing fix patterns

#### 2.1 Fix Bridge — Done

Created `lib/src/native/saropa_fix.dart` with `SaropaFixProducer` base class and `SaropaFixGenerator` typedef.

Added `fixGenerators` getter to `SaropaLintRule` (default: empty list). Rules override to declare fixes.

Registration in `lib/main.dart`:
```dart
for (final rule in allSaropaRules) {
  registry.registerLintRule(rule);
  for (final generator in rule.fixGenerators) {
    registry.registerFixForRule(rule.code, generator);
  }
}
```

#### 2.2 PoC Fixes — Done

- `CommentOutDebugPrintFix` — comments out `debugPrint()` statements
- `RemoveEmptySetStateFix` — deletes empty `setState(() {})` calls

#### 2.3 Per-File Filtering — Done

Re-enabled in `SaropaContext._wrapCallback()`. All 83 `addXxx()` callbacks wrapped with per-file filtering that checks `applicableFileTypes`, `requiredPatterns`, `requiresWidgets`, `requiresFlutterImport`, etc. Result cached per file path.

#### 2.4 Cleanup — Done

- Deleted redundant PoC files: `saropa_analysis_rule.dart`, `poc_rules.dart`, `saropa_reporter.dart`
- Updated `ignore_fixes.dart` with native framework documentation
- Native framework provides ignore-comment fixes automatically

#### Deliverables
- [x] `lib/src/native/saropa_fix.dart` — Fix base class
- [x] `lib/src/fixes/` — 2 proof-of-concept fixes
- [x] `fixGenerators` getter on `SaropaLintRule`
- [x] Per-file filtering re-enabled via `_wrapCallback()`
- [x] Redundant PoC files cleaned up

---

### Phase 3: Reporter Features - DONE

**Goal**: Add back saropa features to `SaropaDiagnosticReporter`

| Feature | Priority | Status | Notes |
|---------|----------|--------|-------|
| Ignore comment fixes | High | **DONE** | Native framework provides automatically |
| Ignore comment checking (`IgnoreUtils`) | High | **SKIP** | Native framework handles `// ignore:` automatically |
| Baseline suppression (`BaselineManager`) | Medium | **DONE** | Wired into reporter via `RuleContext` |
| Impact tracking (`ImpactTracker`) | Low | **DONE** | Every reported violation tracked by impact level |
| Progress tracking (`ProgressTracker`) | Low | **DONE** | Files + violations tracked per-file and per-rule |
| Severity overrides | Medium | **DONE** | Via `severities:` in `analysis_options_custom.yaml` |

#### Implementation

- `config_loader.dart` — loads severity overrides, baseline config, output settings from yaml + env vars
- `Plugin.start()` — calls `loadNativePluginConfig()` once per analysis context
- `diagnosticCode` getter — returns modified `LintCode` with overridden severity (cached)
- `SaropaDiagnosticReporter` — checks baseline before reporting, records to ImpactTracker + ProgressTracker after
- `SaropaContext` — calls `ProgressTracker.recordFile()` on each new file

#### Deliverables
- [x] Ignore comment fixes (provided by native framework)
- [x] Ignore comment checking (native framework handles automatically)
- [x] Baseline suppression wired into reporter
- [x] Severity override support via config + `diagnosticCode` getter
- [x] Impact/progress tracking in reporter

---

### Phase 4: Bulk Rule Migration - DONE

**Goal**: Migrate all 1,677+ rules using the compatibility layer

All 96 rule files were migrated in a single pass using `scripts/migrate_to_native.py`. The script handled the mechanical changes:

1. `LintCode(name: 'x', problemMessage: 'y', errorSeverity: s)` → `LintCode('x', 'y', severity: s)`
2. Drop `resolver` parameter from `runWithReporter`
3. `context.registry.addXxx(` → `context.addXxx(`
4. `reporter.atNode(node, code)` → `reporter.atNode(node)`
5. Import rewrites (remove `custom_lint_builder`, add native imports)

Base class stayed as `SaropaLintRule` (now extends `AnalysisRule` directly instead of `DartLintRule`).

#### Deliverables
- [x] Migration script (`scripts/migrate_to_native.py`)
- [x] All 96 rule files migrated
- [x] `lib/main.dart` registers all rules
- [x] `custom_lint_builder` dependency removed
- [x] `lib/custom_lint_client.dart` deleted
- [x] `dart analyze --fatal-infos` = zero issues
- [x] `dart test` = 1543 tests pass

---

### Phase 5: Configuration & Tier System - DONE

**Goal**: New configuration format and tier presets

#### Implementation

- Updated 5 tier preset YAML files (`lib/tiers/*.yaml`) from `custom_lint: rules:` to `plugins: saropa_lints: diagnostics:`
- Updated `bin/init.dart` to generate native plugin format with `plugins:` section
- Native analyzer handles `diagnostics:` configuration automatically (severity overrides, rule enable/disable)
- Created `MIGRATION_V5.md` with complete v4 → v5 upgrade instructions

#### Deliverables
- [x] Preset configuration files updated to native format
- [x] Init command generates `plugins: saropa_lints: diagnostics:` format
- [x] Migration guide (`MIGRATION_V5.md`)

---

### Phase 6: Testing & Release - IN PROGRESS

**Goal**: Comprehensive testing and release

#### 6.1 Quick Fix Migration - DONE

108 rules have real `fixGenerators` with working `SaropaFixProducer` implementations. All fix files contain real AST-based logic (zero TODO placeholders). HackCommentFix placeholder pattern was removed entirely — rules without a real fix simply have no `fixGenerators`.

| Fix category | Count | Implementation |
|---|---|---|
| Individual fix files | 108 | Dedicated `SaropaFixProducer` subclasses in `lib/src/fixes/<category>/`, all with real implementations |
| Base classes | 3 | `InsertTextFix`, `ReplaceNodeFix`, `DeleteNodeFix` |
| Rules without fixes | ~1,569 | No `fixGenerators` — honest about no auto-fix |

#### 6.2 Testing

| Test Type | Coverage |
|-----------|----------|
| Unit tests | All migrated rules detect correctly |
| Quick fix tests | Fixes appear in VS Code, apply correctly |
| Integration tests | Plugin loads, registers rules, analyzes files |
| Regression tests | Compare output with v4 on same codebase |
| Performance tests | Benchmark against custom_lint on large projects |
| IDE tests | VS Code squiggles, Problems panel, quick fixes |

#### 6.3 Release Plan

1. ~~`5.0.0-dev.1` - Infrastructure + PoC~~ DONE
2. ~~`5.0.0-beta.1` - All rules migrated, basic quick fixes~~ DONE
3. ~~`5.0.0-beta.2` - All quick fixes, reporter features~~ DONE (108 real fixes + reporter features)
4. `5.0.0` - Stable release after beta feedback
5. Maintain `4.x` security fixes during transition

#### Deliverables
- [x] Quick fix migration (108 rules with real fix implementations)
- [x] Migration guide (`MIGRATION_V5.md`)
- [ ] Test suite covering all migrated rules
- [ ] Beta releases for feedback
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

### New Files

| File | Phase | Purpose |
|------|-------|---------|
| `lib/main.dart` | 1 | Plugin entry point (`SaropaLintsPlugin`) |
| `lib/src/native/saropa_context.dart` | 1 | Registry wrapper (83 `addXxx` methods + per-file filtering) |
| `lib/src/native/compat_visitor.dart` | 1 | `SimpleAstVisitor` bridge (83 node type callbacks) |
| `lib/src/native/saropa_fix.dart` | 2 | `SaropaFixProducer` base class + `SaropaFixGenerator` typedef |
| `lib/src/native/config_loader.dart` | 3 | Config loading (severities, baseline, output settings) |
| `lib/src/fixes/<category>/*.dart` (108 files) | 6 | Real `SaropaFixProducer` implementations with AST-based logic |
| `lib/src/fixes/common/*.dart` (3 files) | 6 | Reusable fix base classes (`InsertTextFix`, `ReplaceNodeFix`, `DeleteNodeFix`) |
| `scripts/migrate_to_native.py` | 4 | Automated rule migration script |

### Modified Files

| File | Change |
|------|--------|
| `pubspec.yaml` | Swapped deps, bumped SDK/version |
| `lib/saropa_lints.dart` | Rewired as `allSaropaRules` list (was `createPlugin()`) |
| `lib/src/saropa_lint_rule.dart` | Base class now extends `AnalysisRule`, added `fixGenerators`, `shouldSkipFile` made public |
| `lib/src/rules/*.dart` (96 files) | Migrated to native API (LintCode, runWithReporter, context, reporter) |
| `lib/src/tiers.dart` | Commented out 4 phantom rules pending migration |
| `lib/src/ignore_fixes.dart` | Documentation-only (native framework provides ignore fixes) |

### Deleted Files

| File | Phase | Reason |
|------|-------|--------|
| `lib/custom_lint_client.dart` | 4 | Old custom_lint client |
| `lib/src/native/saropa_analysis_rule.dart` | 2 | Redundant PoC base class (merged into `SaropaLintRule`) |
| `lib/src/native/poc_rules.dart` | 2 | Redundant PoC rules (merged into real rule files) |
| `lib/src/native/saropa_reporter.dart` | 2 | Redundant PoC reporter (merged into `saropa_lint_rule.dart`) |

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

_Last updated: 2026-02-17_
