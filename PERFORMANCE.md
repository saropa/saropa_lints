# Performance Optimization Guide

This guide documents the performance optimizations in saropa_lints v3.0.0 and how to configure the linter for optimal speed.

---

## Why custom_lint is Slow

custom_lint runs as a Dart analyzer plugin. With 1400+ rules, the analysis can be slow because:

1. **Every rule runs on every file** - No incremental analysis support
2. **Set operations on each file** - Tier rule sets were rebuilt per-file
3. **Rule filtering overhead** - 1400+ rules filtered for each file
4. **Generated code analysis** - Analyzing files you can't fix anyway

v3.0.0 addresses all of these bottlenecks.

---

## Quick Wins

### 1. Use Lower Tiers During Development

The single biggest performance improvement is using fewer rules:

```yaml
# Fast local development (~400 rules)
custom_lint:
  saropa_lints:
    tier: essential

# Thorough CI checking (~1400 rules)
custom_lint:
  saropa_lints:
    tier: professional
```

**Speed comparison:**

| Tier            | Rule Count | Relative Speed         |
| --------------- | ---------- | ---------------------- |
| `essential`     | ~400       | **Fastest** (baseline) |
| `recommended`   | ~900       | ~2x slower             |
| `professional`  | ~1400      | ~3x slower             |
| `comprehensive` | ~1450      | ~3.5x slower           |
| `insanity`      | ~1600      | **Slowest**            |

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

### 3. Clear Analyzer Cache When Stuck

If analysis seems stuck or slow:

```bash
# Clear Dart tool cache
rm -rf .dart_tool

# Clear pub cache (nuclear option)
dart pub cache clean

# Restart analysis
dart pub get
dart run custom_lint
```

---

## Built-in Optimizations (v3.0.0)

These optimizations are automatic - no configuration needed.

### Tier Set Caching

**Problem:** `getRulesForTier()` was rebuilding Set unions on every file.

**Solution:** Tier sets are now computed once on first access and cached:

```dart
// Before (slow): Rebuilt on every call
case 'professional':
  return <String>{...essentialRules, ...recommendedOnlyRules, ...professionalOnlyRules};

// After (fast): Computed once, cached forever
case 'professional':
  return _TierCache.professional;
```

**Impact:** ~5-10x faster tier lookups after first access.

### Rule Filtering Cache

**Problem:** The 1400+ rule list was filtered for every single file.

**Solution:** Filtered rule list is computed once per analysis session:

```dart
// Return cached rules if tier hasn't changed
if (_cachedFilteredRules != null && _cachedTier == tier) {
  return _cachedFilteredRules!;
}
```

**Impact:** Eliminates O(n) filtering on each of thousands of files.

---

## Profiling Slow Rules

Enable timing instrumentation to identify slow rules:

```bash
# Enable profiling
SAROPA_LINTS_PROFILE=true dart run custom_lint
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
  print('${timing.ruleName}: ${timing.totalTime.inMilliseconds}ms');
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
```

### What to Do With Timing Data

1. **Rules with high total time** - Consider moving to higher tiers
2. **Rules with high average time** - May need algorithmic optimization
3. **Rules with many calls** - Expected, not a problem
4. **Rules >10ms average** - Candidates for optimization or tier promotion

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
        run: dart run custom_lint
        env:
          # Optional: Enable profiling in CI to track performance
          SAROPA_LINTS_PROFILE: true
```

### Two-Tier Strategy

Use different tiers for local development vs CI:

```yaml
# Local: analysis_options.yaml
custom_lint:
  saropa_lints:
    tier: essential # Fast feedback loop


# CI: Override with comprehensive checking
# Set via environment or separate config
```

---

## Memory Optimization

### Out of Memory Errors

If you see OOM errors:

```bash
# Increase Dart heap size (PowerShell)
$env:DART_VM_OPTIONS="--old_gen_heap_size=4096"
dart run custom_lint

# Increase Dart heap size (bash)
export DART_VM_OPTIONS="--old_gen_heap_size=4096"
dart run custom_lint
```

### Reduce Memory Usage

1. **Use lower tiers** - Fewer rules = less memory
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

```yaml
custom_lint:
  saropa_lints:
    tier: professional
    baseline:
      file: "saropa_baseline.json" # Specific violations
      date: "2025-01-15" # Code unchanged since date
      paths: # Directories to ignore
        - "lib/legacy/"
        - "lib/deprecated/"
        - "**/generated/"
      only_impacts: [low, medium] # Keep seeing critical/high
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
time dart run custom_lint

# Compare tiers
time dart run custom_lint  # with tier: essential
time dart run custom_lint  # with tier: professional
```

### Expected Performance

On a typical project (100 Dart files):

| Tier           | Expected Time |
| -------------- | ------------- |
| `essential`    | 5-15 seconds  |
| `recommended`  | 10-30 seconds |
| `professional` | 20-60 seconds |
| `insanity`     | 30-90 seconds |

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

The Dart analyzer plugin system has known reliability issues. For consistent performance:

1. Use CLI (`dart run custom_lint`) instead of IDE integration
2. Set up VS Code tasks for on-demand linting
3. Use pre-commit hooks for automated checking

---

## Future Optimizations

Potential improvements not yet implemented:

1. **Lazy rule loading** - Load rule categories on-demand
2. **Parallel rule execution** - Run independent rules in isolates
3. **Incremental analysis** - Only re-analyze changed files
4. **Rule dependency ordering** - Run fast rules first, skip slow rules if fast rules fail

These would require significant refactoring or upstream changes to custom_lint.

---

## Summary

| Optimization           | Where                       | Impact                    |
| ---------------------- | --------------------------- | ------------------------- |
| Use lower tiers        | `analysis_options.yaml`     | 3-5x faster               |
| Exclude generated code | `analysis_options.yaml`     | 2x faster                 |
| Tier set caching       | Built-in (v3.0.0)           | 5-10x faster tier lookups |
| Rule filtering cache   | Built-in (v3.0.0)           | O(1) vs O(n) per file     |
| Profiling              | `SAROPA_LINTS_PROFILE=true` | Identify slow rules       |

**Best practice:** Start with `essential` tier locally, use `professional` in CI, and profile periodically to identify optimization opportunities.
