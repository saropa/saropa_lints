# Native Analyzer Plugin Migration Roadmap

Plan for migrating saropa_lints from `custom_lint` to the native Dart 3.10+ analyzer plugin system.

## Rationale

Dart 3.10 introduced a first-party analyzer plugin system that offers:
- Native `dart analyze` / `flutter analyze` integration
- Works with `dart fix --apply`
- Better IDE performance (no separate isolate)
- No additional runtime command needed

**Primary motivation**: Current `custom_lint` implementation is slow. Native plugin addresses the root cause by eliminating isolate overhead and integrating directly with the analyzer.

**Trade-offs**:
- Breaking change for existing users
- Less mature ecosystem than custom_lint
- Different configuration format
- May lose some advanced features

## Relationship to Other Components

```
┌─────────────────────────────────────────────────────────────┐
│                    saropa_lints Architecture                │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Per-File Analysis (IDE integration)                        │
│  ┌─────────────────┐         ┌─────────────────┐           │
│  │ Current         │ ──────► │ Native          │           │
│  │ (custom_lint)   │ replace │ (analyzer plugin)│           │
│  │ • Slow          │         │ • Fast          │           │
│  │ • Works         │         │ • Same features │           │
│  └─────────────────┘         └─────────────────┘           │
│           │                           │                     │
│           └───────────┬───────────────┘                     │
│                       ▼                                     │
│              ┌─────────────────┐                            │
│              │ Shared Rules    │                            │
│              │ (detection logic)│                            │
│              └─────────────────┘                            │
│                                                             │
│  Cross-File Analysis (terminal/CI only)                     │
│  ┌─────────────────┐                                        │
│  │ CLI             │  Separate tool, complements both       │
│  │ • unused-files  │  See: ROADMAP_CLI.md                   │
│  │ • circular-deps │                                        │
│  └─────────────────┘                                        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Key points:**
- Native **replaces** Current (same 1,677 rules, faster engine)
- CLI is **separate** (cross-file analysis neither engine can do)
- Both Native and CLI can coexist

## Reporting Capabilities

| Output | Current (custom_lint) | Native | Notes |
|--------|----------------------|--------|-------|
| IDE "PROBLEMS" panel | Yes | Yes (faster) | Same UX |
| Editor squiggles | Yes | Yes (faster) | Same UX |
| Quick fixes | Yes | Yes | API differs |
| `dart analyze` | No | Yes | Major benefit |
| `dart fix --apply` | No | Yes | Major benefit |
| Terminal output | `dart run custom_lint` | `dart analyze` | Simpler |

## Current Architecture

| Component | Implementation | Files |
|-----------|---------------|-------|
| Plugin entry | `PluginBase` | `lib/saropa_lints.dart` |
| Base classes | `DartLintRule`, `SaropaLintRule` | `lib/src/saropa_lint_rule.dart` |
| Rule registration | `getLintRules()` | `lib/src/rules/all_rules.dart` |
| Configuration | `analysis_options.yaml` custom_lint format | User's project |
| Quick fixes | `DartFix` | Various `*_rules.dart` files |

**Stats**: 1,677 rules, 213 quick fixes, 5 tiers

## Target Architecture

| Component | New Implementation | Notes |
|-----------|-------------------|-------|
| Plugin entry | Extends `Plugin` | `lib/saropa_lints_plugin.dart` |
| Base classes | `AnalysisRule`, `MultiAnalysisRule` | From `analysis_server_plugin` |
| Rule registration | `register(PluginRegistry)` | Different pattern |
| Configuration | `analysis_options.yaml` plugins format | Standard format |
| Quick fixes | New fix classes | API changes |

## API Changes Reference

Based on [Dart SDK documentation](https://dart.dev/tools/analyzer-plugins):

| custom_lint | Native Plugin |
|-------------|---------------|
| `LintCode` | `DiagnosticCode` |
| `LintRule` | `AnalysisRule`, `MultiAnalysisRule` |
| `NodeLintRegistry` | `RuleVisitorRegistry` |
| `LinterContext` | `RuleContext`, `RuleContextUnit` |
| `DartFix` | New fix class pattern |
| `ErrorReporter` | Different reporting API |

## Migration Phases

### Phase 0: Preparation

**Goal**: Understand new system, create compatibility layer

#### 0.1 Research & Documentation

- [ ] Study `analysis_server_plugin` source code
- [ ] Document all API differences
- [ ] Identify features that may not migrate (tier system, rule ordering)
- [ ] Create test project with new plugin system

#### 0.2 Compatibility Assessment

Evaluate each saropa_lints feature:

| Feature | Migratable | Notes |
|---------|------------|-------|
| Basic lint rules | Yes | Core functionality |
| Quick fixes | Yes | Different API |
| Tier system | Unknown | May need custom config |
| Rule ordering by cost | Unknown | Performance optimization |
| Content pre-filtering | Unknown | `shouldAnalyze()` pattern |
| ProjectContext caching | Yes | Can keep internal caching |
| Baseline suppression | Partial | Native has different ignore system |

#### 0.3 Coexistence Strategy

Native and Current can coexist during migration using shared rule logic:

```
lib/
├── src/
│   ├── rules/
│   │   └── core/                    # Shared detection logic (no framework deps)
│   │       ├── avoid_print.dart     # Pure detection: shouldReport(node) → bool
│   │       └── ...
│   │
│   ├── adapters/
│   │   ├── custom_lint/             # custom_lint wrappers
│   │   │   └── avoid_print_rule.dart
│   │   └── native/                  # native plugin wrappers
│   │       └── avoid_print_rule.dart
│   │
│   └── saropa_lint_rule.dart        # Shared base (detection logic only)
│
├── saropa_lints.dart                # custom_lint entry (current)
└── saropa_lints_plugin.dart         # native entry (new)
```

**Benefits:**
- Users choose: `dart run custom_lint` OR `dart analyze`
- Gradual migration with subset of rules in Native
- Bug fixes apply to both adapters
- Eventually deprecate custom_lint adapter

#### 0.4 Decision Point

After Phase 0, decide:
- **Proceed**: Migration is feasible with acceptable trade-offs
- **Wait**: New system needs more maturity
- **Hybrid**: Maintain both using shared rule logic (recommended for gradual rollout)

---

### Phase 1: Infrastructure

**Goal**: New plugin entry point and base classes

#### 1.1 Create Plugin Entry Point

New file: `lib/saropa_lints_plugin.dart`

```dart
import 'package:analysis_server_plugin/plugin.dart';

final plugin = SaropaLintsPlugin();

class SaropaLintsPlugin extends Plugin {
  @override
  void register(PluginRegistry registry) {
    // Register all rules
    for (final rule in allRules) {
      registry.registerRule(rule);
    }

    // Register fixes
    for (final fix in allFixes) {
      registry.registerFix(fix);
    }
  }
}
```

#### 1.2 Create New Base Classes

Abstract the differences to minimize rule changes:

```dart
// lib/src/native/saropa_analysis_rule.dart

import 'package:analysis_server_plugin/analysis_server_plugin.dart';

/// Base class for saropa_lints rules using native plugin system.
abstract class SaropaAnalysisRule extends AnalysisRule {
  SaropaAnalysisRule({
    required this.code,
  });

  final DiagnosticCode code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    // Subclasses implement this
  }
}
```

#### 1.3 Create Migration Helpers

Utility to help migrate existing rules:

```dart
// Helper to convert LintCode to DiagnosticCode
DiagnosticCode convertCode(LintCode oldCode) {
  return DiagnosticCode(
    name: oldCode.name,
    problemMessage: oldCode.problemMessage,
    correctionMessage: oldCode.correctionMessage,
    // Map severity
  );
}
```

#### Deliverables
- [ ] `lib/saropa_lints_plugin.dart` - New plugin entry
- [ ] `lib/src/native/saropa_analysis_rule.dart` - New base class
- [ ] `lib/src/native/saropa_analysis_fix.dart` - New fix base class
- [ ] Migration helper utilities
- [ ] Test with 5-10 simple rules

---

### Phase 2: Rule Migration

**Goal**: Migrate all 1,677 rules

#### 2.1 Migration Strategy

Migrate rules in batches by category:

| Priority | Category | Count | Complexity |
|----------|----------|-------|------------|
| 1 | Core Dart rules | ~200 | Low |
| 2 | Flutter rules | ~300 | Low |
| 3 | Security rules | ~150 | Medium |
| 4 | Accessibility rules | ~100 | Low |
| 5 | Package-specific (Riverpod, Bloc, etc.) | ~500 | Medium |
| 6 | Performance rules | ~200 | Medium |
| 7 | Architecture rules | ~200 | High |

#### 2.2 Rule Migration Template

Before (custom_lint):
```dart
class AvoidPrint extends DartLintRule {
  AvoidPrint() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_print',
    problemMessage: 'Avoid using print in production code.',
    correctionMessage: 'Use a logger instead.',
    errorSeverity: ErrorSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      if (node.methodName.name == 'print') {
        reporter.atNode(node, code);
      }
    });
  }
}
```

After (native plugin):
```dart
class AvoidPrint extends SaropaAnalysisRule {
  AvoidPrint() : super(
    code: DiagnosticCode(
      name: 'avoid_print',
      problemMessage: 'Avoid using print in production code.',
      correctionMessage: 'Use a logger instead.',
      // Severity mapping TBD
    ),
  );

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addMethodInvocation(this, (node) {
      if (node.methodName.name == 'print') {
        context.reportDiagnostic(Diagnostic(code, node));
      }
    });
  }
}
```

#### 2.3 Automated Migration Script

Create script to automate mechanical changes:

```bash
dart run scripts/migrate_rules.dart --input lib/src/rules/ --output lib/src/native_rules/
```

Script handles:
- Import changes
- Base class changes
- `LintCode` → `DiagnosticCode`
- `context.registry` → `registry`
- `reporter.atNode` → `context.reportDiagnostic`

Manual review needed for:
- Complex fix implementations
- Rules using `CustomLintResolver` features
- Rules with custom `shouldAnalyze()` logic

#### Deliverables
- [ ] Migration script
- [ ] Migrate core Dart rules (batch 1)
- [ ] Migrate Flutter rules (batch 2)
- [ ] Migrate remaining categories (batches 3-7)
- [ ] Update all_rules.dart for new registration

---

### Phase 3: Quick Fix Migration

**Goal**: Migrate all 213 quick fixes

#### 3.1 New Fix Pattern

Before (custom_lint):
```dart
class _AvoidPrintFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((node) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Replace with logger',
        priority: 80,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.sourceRange,
          'logger.info(${node.argumentList})',
        );
      });
    });
  }
}
```

After (native plugin):
```dart
// API TBD - need to research native fix registration
```

#### 3.2 Fix Registration

Native plugin fix registration differs from custom_lint. Need to research:
- How fixes are associated with rules
- Fix priority system
- Multi-fix support

#### Deliverables
- [ ] Document new fix API
- [ ] Create fix base class
- [ ] Migrate all 213 fixes
- [ ] Test fix application with `dart fix`

---

### Phase 4: Configuration Migration

**Goal**: New configuration format and tier system

#### 4.1 New Configuration Format

custom_lint format:
```yaml
custom_lint:
  rules:
    - avoid_print
    - require_dispose: false
```

Native plugin format:
```yaml
analyzer:
  plugins:
    - saropa_lints

linter:
  rules:
    avoid_print: true
    require_dispose: false
```

#### 4.2 Tier System Migration

Options:
1. **Presets**: Create preset packages (`saropa_lints_essential`, `saropa_lints_recommended`, etc.)
2. **Single package with presets**: Include preset configs in main package
3. **Drop tiers**: Let users configure individually

Recommendation: Option 2 - Include preset analysis_options files:

```yaml
# In user's analysis_options.yaml
include: package:saropa_lints/presets/recommended.yaml
```

#### 4.3 Init Command Update

Update `bin/init.dart` to generate new format:

```bash
dart run saropa_lints:init --tier recommended
# Generates analysis_options.yaml with new format
```

#### Deliverables
- [ ] Preset configuration files
- [ ] Update init command
- [ ] Migration guide for existing users
- [ ] Update documentation

---

### Phase 5: Testing & Release

**Goal**: Comprehensive testing and release

#### 5.1 Testing Strategy

| Test Type | Coverage |
|-----------|----------|
| Unit tests | All migrated rules |
| Integration tests | Plugin loading, rule execution |
| Regression tests | Compare results with custom_lint version |
| Performance tests | Analyze large projects |
| IDE tests | VS Code, IntelliJ integration |

#### 5.2 Beta Release

1. Release as `saropa_lints: ^3.0.0-beta.1`
2. Requires Dart SDK `>=3.10.0`
3. Document breaking changes
4. Gather feedback

#### 5.3 Stable Release

1. Address beta feedback
2. Release `saropa_lints: ^3.0.0`
3. Deprecate 2.x branch
4. Maintain security fixes for 2.x during transition period

#### Deliverables
- [ ] Comprehensive test suite
- [ ] Beta release
- [ ] Migration guide
- [ ] Stable release
- [ ] 2.x deprecation plan

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| API instability | Low | High | Dart 3.10.8 is stable; monitor SDK releases |
| Feature loss | Medium | Medium | Document limitations, provide alternatives |
| Performance regression | Low | Medium | Benchmark early, optimize |
| User migration friction | High | Medium | Comprehensive migration guide |
| Maintenance burden | Medium | High | Use shared rule logic; drop custom_lint after stable |

## Decision Criteria

**Proceed with migration when**:
- [ ] Phase 0 research confirms API compatibility
- [ ] Test project validates core rule patterns work
- [ ] Performance benchmarks show improvement over custom_lint
- [ ] Critical features (quick fixes, tier system) have viable paths

**Pause if**:
- Critical features cannot be implemented
- Performance is worse than custom_lint
- API changes significantly in upcoming Dart releases

## References

- [Dart Analyzer Plugins](https://dart.dev/tools/analyzer-plugins)
- [GitHub #53402 - New analyzer plugin system](https://github.com/dart-lang/sdk/issues/53402)
- [analysis_server_plugin package](https://github.com/dart-lang/sdk/tree/main/pkg/analysis_server_plugin)
- [Migration blog post](https://leancode.co/blog/migrating-to-dart-analyzer-plugin-system)
- [Writing rules guide](https://github.com/dart-lang/sdk/blob/main/pkg/analysis_server_plugin/doc/writing_rules.md)

---

## Appendix: Feature Comparison

| Feature | custom_lint | Native Plugin | Notes |
|---------|-------------|---------------|-------|
| Lint rules | Yes | Yes | API differs |
| Quick fixes | Yes | Yes | API differs |
| Assists | No | Yes | New capability |
| `dart analyze` integration | No | Yes | Major benefit |
| `dart fix` integration | No | Yes | Major benefit |
| IDE integration | Via plugin | Native | Better performance |
| Hot reload during development | Yes | Unknown | custom_lint advantage |
| Debugger support | Yes | Unknown | custom_lint advantage |
| Configuration | custom_lint section | plugins section | Different format |

---

_Last updated: 2026-01-28_
