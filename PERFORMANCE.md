# Performance Optimization Guide

This guide documents the performance optimizations in saropa_lints v5.0.0 and how to configure the linter for optimal speed.

---

## Architecture: Native Analyzer Plugin

Saropa Lints (v5+) runs as a **native Dart analyzer plugin**, integrated directly into `dart analyze`. This replaces the previous custom_lint-based architecture and brings significant performance benefits:

1. **Native integration** - Rules run inside the analyzer process, eliminating IPC overhead
2. **Incremental analysis** - The analyzer only re-analyzes changed files
3. **Lazy rule instantiation** - Only rules in the selected tier are created (not all 1700+)
4. **Compile-time constant tier sets** - No runtime set-building overhead

With 1700+ rules, analysis can still be slow on large projects. The optimizations below help manage this.

---

## Quick Wins

### 1. Use Lower Tiers During Development

The single biggest performance improvement is using fewer rules. **Always generate your config with the CLI tool for reliable tier selection:**

```bash
# Fast local development (~290 rules)
dart run saropa_lints:init --tier essential

# Thorough CI checking (~1600 rules)
dart run saropa_lints:init --tier professional
```

**Speed comparison:**

| Tier            | Rule Count | Relative Speed         |
| --------------- | ---------- | ---------------------- |
| `essential`     | ~290       | **Fastest** (baseline) |
| `recommended`   | ~840       | ~2x slower             |
| `professional`  | ~1600      | ~3x slower             |
| `comprehensive` | ~1710      | ~3.5x slower           |
| `pedantic`      | ~1720      | **Slowest**            |

### 2. Exclude Generated Code

Add these excludes to your `analysis_options.yaml`:

```yaml
analyzer:
  exclude:
    # Generated code - cannot be manually fixed
    - "**/*.g.dart" # json_serializable, hive, built_value
    - "**/*.freezed.dart" # freezed immutable classes
    - "**/*.gr.dart" # auto_route generated routes
    - "**/*.gen.dart" # various generators
    - "**/*.mocks.dart" # mockito mocks
    - "**/*.config.dart" # injectable, get_it config
    - "**/generated/**" # catch-all for generated directories

    # Build artifacts
    - build/**
    - .dart_tool/**
```

**Why this matters:** Generated code can be 10x larger than your source code. Excluding it can cut analysis time in half.

### 3. Cap the Problems Tab (Default: 500)

By default, saropa_lints caps the IDE Problems tab at **500 non-ERROR issues**. After the cap is reached:

- **ERROR-severity issues** are always reported (never capped)
- **WARNING and INFO issues** stop appearing in the Problems tab
- **All violations** are still recorded in the report log
- Rules continue running — nothing is skipped

This prevents the IDE from becoming unresponsive on large codebases with many warnings.

**Configure the cap:**

```yaml
# In analysis_options_custom.yaml
max_issues: 500 # default; set 0 for unlimited
```

Or via environment variable:

```bash
SAROPA_LINTS_MAX=1000 dart analyze
```

**Tip:** Use `0` (unlimited) in CI where you want a complete count. Use the default `500` locally to keep the IDE responsive.

### 4. Clear Analyzer Cache When Stuck

If analysis seems stuck or slow:

```bash
# Clear Dart tool cache
rm -rf .dart_tool

# Clear pub cache (nuclear option)
dart pub cache clean

# Restart analysis
dart pub get
dart analyze
```

---

## Built-in Optimizations (v5.0.0)

These optimizations are automatic - no configuration needed.

### Compile-Time Constant Tier Sets

**Problem:** Tier rule sets could be expensive to rebuild at runtime.

**Solution:** All tier sets are `const Set<String>` literals, computed at compile time:

```dart
// Compile-time constant - zero runtime cost
const Set<String> essentialRules = <String>{
  'avoid_null_assertion',
  'avoid_debug_print',
  // ... ~290 rules
};
```

Higher tiers use `.union()` on these const sets. Since the base sets are immutable constants, this is efficient.

**Impact:** Zero runtime cost for tier set construction.

### Lazy Rule Instantiation

**Problem:** Instantiating all 1700+ rules consumes ~4GB of memory.

**Solution:** Rules are stored as factory functions and only instantiated when needed:

```dart
// Factories stored, not instances
final List<SaropaLintRule Function()> _allRuleFactories = [
  AvoidNullAssertionRule.new,
  AvoidDebugPrintRule.new,
  // ...
];

// Only instantiate rules in the selected tier
List<SaropaLintRule> getRulesFromRegistry(Set<String> ruleNames) {
  final rules = <SaropaLintRule>[];
  for (final name in ruleNames) {
    final factory = _ruleFactories[name];
    if (factory != null) {
      rules.add(factory());
    }
  }

  return rules;
}
```

**Impact:** Essential tier uses ~500MB instead of ~4GB. Only the rules you need are instantiated.

---

## Profiling Slow Rules

Enable timing instrumentation to identify slow rules:

```bash
# Enable profiling
SAROPA_LINTS_PROFILE=true dart analyze
```

### What You'll See

Rules taking >10ms are logged immediately:

```
SLOW RULE: avoid_deeply_nested_widgets took 15ms
SLOW RULE: avoid_god_class took 23ms
```

### Accessing the Full Report

In your code, you can access timing data:

```dart
import 'package:saropa_lints/saropa_lints.dart';

// Get summary of 20 slowest rules
print(RuleTimingTracker.summary);

// Get detailed timing records
for (final timing in RuleTimingTracker.sortedTimings) {
  print('${timing.ruleName}: ${timing.totalTime.inMilliseconds}ms total, '
      '${timing.callCount} calls, '
      '${timing.averageTime.inMilliseconds}ms avg');
}

// Reset timing data
RuleTimingTracker.reset();
```

### Sample Timing Report

```
=== SAROPA LINTS TIMING REPORT ===
Top 20 slowest rules (by total time):

  avoid_god_class: 1234ms total, 156 calls, 7.9ms avg
  avoid_circular_dependencies: 987ms total, 156 calls, 6.3ms avg
  avoid_deeply_nested_widgets: 876ms total, 156 calls, 5.6ms avg
  ...

=== RULES ELIGIBLE FOR DEFERRAL (>50ms) ===
Use SAROPA_LINTS_DEFER=true to defer these rules.

  avoid_god_class (3 slow executions)
```

### What to Do With Timing Data

1. **Rules with high total time** - Consider moving to higher tiers
2. **Rules with high average time** - May need algorithmic optimization
3. **Rules with many calls** - Expected, not a problem
4. **Rules >10ms average** - Candidates for optimization or tier promotion
5. **Rules eligible for deferral** - Use `SAROPA_LINTS_DEFER=true` to run them in a second pass

---

## CI/CD Configuration

### GitHub Actions

```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1

      - name: Install dependencies
        run: dart pub get

      - name: Run lints (professional tier)
        run: dart analyze --fatal-infos
        env:
          # Optional: Enable profiling in CI to track performance
          SAROPA_LINTS_PROFILE: true
```

### Two-Tier Strategy

Use different tiers for local development vs CI:

```bash
# Local: Fast feedback loop (~290 rules)
dart run saropa_lints:init --tier essential

# CI: Thorough checking (~1710 rules)
dart run saropa_lints:init --tier comprehensive -o analysis_options.ci.yaml
```

---

## Memory Optimization

### Out of Memory Errors

If you see OOM errors:

```bash
# Increase Dart heap size (PowerShell)
$env:DART_VM_OPTIONS="--old_gen_heap_size=4096"
dart analyze

# Increase Dart heap size (bash)
export DART_VM_OPTIONS="--old_gen_heap_size=4096"
dart analyze
```

### Reduce Memory Usage

1. **Use lower tiers** - Fewer rules = less memory (~500MB for essential vs ~4GB for all)
2. **Exclude generated code** - Fewer files to analyze
3. **Clear caches** - `rm -rf .dart_tool && dart pub get`

---

## Handling Legacy Codebases (Baseline Feature)

### The Problem

You want to adopt saropa_lints on an existing project. You run analysis and see:

```
... 500+ violations in legacy code
```

You can't fix them all before your next sprint. But ignoring linting entirely means new bugs slip through.

### The Solution

The **baseline feature** records existing violations and hides them:

```bash
dart run saropa_lints:baseline
```

- **Old code**: Violations hidden (baselined)
- **New code**: Violations reported normally

### Why Use Baseline

- **Adopt linting today** - Don't wait until legacy code is fixed
- **Catch new bugs** - New code is still checked
- **Gradual cleanup** - Fix old violations over time, run `--update` to shrink baseline
- **Priority filtering** - Keep seeing critical issues while baselining low-severity ones

### Three Baseline Types

| Type           | Config           | Description                      | Performance        |
| -------------- | ---------------- | -------------------------------- | ------------------ |
| **File-based** | `baseline.file`  | JSON listing specific violations | O(1) lookup        |
| **Path-based** | `baseline.paths` | Glob patterns for directories    | Pre-compiled regex |
| **Date-based** | `baseline.date`  | Git blame - ignore old code      | Cached per-file    |

### Full Configuration

Generate tier config and baseline via CLI:

```bash
# Generate rule config for your tier
dart run saropa_lints:init --tier professional

# Generate baseline to suppress legacy violations
dart run saropa_lints:baseline
```

### Workflow

1. **Initial setup**: Run `dart run saropa_lints:baseline`
2. **Development**: New code is linted normally, old violations hidden
3. **Cleanup sprints**: Fix violations, then `dart run saropa_lints:baseline --update`
4. **Goal**: Eventually remove baseline entirely

### Performance Impact

The baseline feature has minimal performance impact:

| Component     | Implementation     | Impact                                   |
| ------------- | ------------------ | ---------------------------------------- |
| File baseline | Hash table lookup  | O(1) per violation                       |
| Path baseline | Pre-compiled regex | O(patterns) per file                     |
| Date baseline | Cached git blame   | First access: O(lines), subsequent: O(1) |
| Impact filter | String comparison  | Negligible                               |

**Best practice**: Use file-based and path-based baselines for best performance. Date-based baseline involves git operations and is slower on first access (but cached afterwards).

See [README.md](README.md#baseline-for-brownfield-projects) for full documentation.

---

## Benchmarking

### Measure Analysis Time

```bash
# Time the full analysis
time dart analyze

# Compare tiers (generate config first with: dart run saropa_lints:init --tier <name>)
time dart analyze  # after init --tier essential
time dart analyze  # after init --tier professional
```

### Expected Performance

On a typical project (100 Dart files):

| Tier           | Expected Time |
| -------------- | ------------- |
| `essential`    | 5-15 seconds  |
| `recommended`  | 10-30 seconds |
| `professional` | 20-60 seconds |
| `pedantic`     | 30-90 seconds |

Times vary based on:

- File count and size
- Rule complexity
- Machine specs
- Whether generated code is excluded

---

## Troubleshooting

### Analysis Never Finishes

1. Check for infinite loops in custom rules
2. Exclude very large generated files
3. Use `essential` tier to isolate the issue
4. Enable profiling to find the slow rule

### Inconsistent Performance

1. Clear `.dart_tool` cache
2. Restart the Dart analysis server
3. Check for background processes

### IDE Integration Slow

saropa_lints runs as a native analyzer plugin, so IDE performance depends on the Dart analysis server. For best results:

1. Use a lower tier during active development (`essential` or `recommended`)
2. Exclude generated code directories
3. Restart the analysis server if it becomes unresponsive (VS Code: "Dart: Restart Analysis Server")

---

## Future Optimizations

Potential improvements not yet implemented:

1. **Lazy rule loading** - Load rule categories on-demand
2. **Parallel rule execution** - Run independent rules in isolates
3. **Rule dependency ordering** - Run fast rules first, skip slow rules if fast rules fail

---

## Summary

| Optimization                | Where                       | Impact                           |
| --------------------------- | --------------------------- | -------------------------------- |
| Use lower tiers             | `analysis_options.yaml`     | 3-5x faster                      |
| Exclude generated code      | `analysis_options.yaml`     | 2x faster                        |
| Compile-time constant tiers | Built-in (v5.0.0)           | Zero runtime cost for tier sets  |
| Lazy rule instantiation     | Built-in (v5.0.0)           | ~500MB vs ~4GB memory            |
| Problems tab cap (500)      | Built-in (v5.0.0)           | Keeps IDE responsive             |
| Profiling                   | `SAROPA_LINTS_PROFILE=true` | Identify slow rules              |
| Rule deferral               | `SAROPA_LINTS_DEFER=true`   | Fast first pass, slow rules last |

**Best practice:** Start with `essential` tier locally, use `professional` in CI, and profile periodically to identify optimization opportunities.
