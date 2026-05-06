# Init Redesign: Data-Driven Triage

**Status**: Proposed
**Priority**: High
**Impact**: User adoption, retention, upgrade experience

## Problem

### The Wizard

The current init wizard asks users to make decisions before they have information:

1. Pick a tier (without knowing what issues exist in their project)
2. Walk through stylistic rule categories one by one (up to 143 prompts)
3. Get hit with potentially thousands of violations after all that effort

This leads to:
- Users overwhelmed by volume of issues on first run
- No visibility into what actually matters for *their* project
- Desire to uninstall rather than configure
- No manageable upgrade path when new versions add rules

### The Custom Config File

`analysis_options_custom.yaml` is 272 lines, mostly a wall of stylistic rules
with full descriptions crammed into YAML comments. It lists all 170+ stylistic
rules one by one, plus platform settings, package settings, and override
sections. Users are expected to read this and manually toggle rules — nobody
does. It's unworkable.

The custom config also duplicates information:
- **Packages** can be auto-detected from `pubspec.yaml`
- **Platforms** can be auto-detected from `pubspec.yaml` (Flutter) or inferred
- **Stylistic rules** should go through the same triage as other rules
- **Rule overrides** are the only thing that genuinely needs a user-editable file

## Design Principle

**Analyze first, then decide.** Let the data drive the decisions, not the user's guesses.

## Command

```
dart run saropa_lints
```

No `:init` suffix needed — it's the default command when no argument is given.
Same command for first run and every subsequent run.

## New Flow

### Phase 1: Full Analysis (silent)

Run all 2047 rules against the project. No user interaction yet.

```
$ dart run saropa_lints

Saropa Static Analysis v8.1.0
Analyzing your project with 2047 rules...
[progress indicator]
```

This produces a map of `rule_name → issue_count` for the entire project.

### Phase 2: Critical Rules (non-negotiable)

Critical rules (essential tier, security, crash, memory) are always enabled.
Display their issues — these are the ones the user *needs* to see.

```
🔴 14 critical issues (5 rules) — always enabled:
   avoid_hardcoded_credentials      3 issues
   missing_dispose                  5 issues
   unchecked_null_assertion         4 issues
   insecure_http_connection         2 issues

These rules cannot be disabled.
```

### Phase 3: Auto-Enable Zero-Issue Rules

Rules that found zero issues in the project get enabled silently.
The user's code already passes them — they'll only fire on *future* violations.

```
✅ 1,412 rules found 0 issues — auto-enabled
   (Your code already passes these. They'll catch future violations.)
```

### Phase 4: Bulk Triage by Volume

The remaining rules (those with issues) are grouped by violation count.
The user makes **group-level decisions**, not per-rule decisions.

Threshold boundaries scale with project size (file count or total issue count).

```
Remaining 629 rules have issues in your project:

  Group A:  34 rules with 1–5 issues each      (87 total)
  Group B:  91 rules with 6–20 issues each      (1,102 total)
  Group C: 188 rules with 21–100 issues each    (9,840 total)
  Group D: 316 rules with 100+ issues each      (54,200 total)
```

User makes 4 decisions, not 629:

```
Group A — 34 rules, 87 issues (very manageable)
  [E] Enable all   [D] Disable all   [R] Review list

Group B — 91 rules, 1,102 issues (some work needed)
  [E] Enable all   [D] Disable all   [R] Review list

Group C — 188 rules, ~10K issues (significant effort)
  [E] Enable all   [D] Disable all

Group D — 316 rules, ~54K issues (overwhelming right now)
  [E] Enable all   [D] Disable all
```

The `[R] Review list` option for smaller groups shows the rules in that group
with their issue counts, and the user can toggle individual rules. This is
optional and only offered for manageable groups.

### Phase 5: Stylistic Rules

Stylistic rules follow the same pattern but are presented separately,
because they are opinionated and always opt-in:

```
Stylistic rules (223 rules, separate from above):

  ✅ 189 rules: 0 issues — auto-enabled

  Remaining 34 stylistic rules with issues:

  Group A: 8 rules, 1–5 issues each     (24 total)   [E] [D]
  Group B: 11 rules, 6–20 issues each   (132 total)   [E] [D]
  Group C: 15 rules, 20+ issues each    (847 total)   [E] [D]

  ⚠️  Stylistic rules are opinionated. Disable all? [Y/N]
```

### Phase 6: Summary & Write

```
Summary:
  🔴  5 critical rules         14 issues (always on)
  ✅ 1,412 rules, 0 issues     auto-enabled
  ✅ 125 rules enabled          1,189 issues to address
  ⬚  504 rules disabled        63,040 issues (deferred)

  Total enabled: 1,542 / 2,047 rules
  Issues to address: 1,203

Writing analysis_options.yaml... ✓
```

## Subsequent Runs

Same command, always: `dart run saropa_lints`

On subsequent runs, the command detects existing configuration and shows
what has changed:

```
Analyzing with 2047 rules...

  🔴  5 critical rules          14 → 8 issues (6 fixed!)
  ✅ 1,531 enabled, 0 issues    healthy
  ⚠️  23 enabled rules          new violations since last run

  12 new rules in v8.1.0:
    10 rules: 0 issues → auto-enabled ✓
     2 rules with issues → grouped below

  Previously disabled (504 rules):
    38 rules now have 0 issues  → enable now? [Y/N]
    71 rules dropped below 5    → moved to Group A

  Group A: 71 rules, 1–5 issues each    [E] [D] [R]
  Group B: ...
```

Key behaviors on re-run:
- **New version rules**: Analyzed and triaged like any other rule
- **Disabled rules with improving counts**: Surfaced for reconsideration
- **Disabled rules reaching 0 issues**: Offered for auto-enable
- **User overrides**: Preserved. Rules the user explicitly enabled/disabled
  are not re-triaged unless `--reset` is passed
- **Progress visible**: Issue counts compared to last run

## Configuration Output

Rules are `true` or `false` in `analysis_options.yaml`. Disabled means `false`.
No suppression mechanism, no baseline files, no special syntax.

```yaml
plugins:
  saropa_lints:
    version: "^8.1.0"
    diagnostics:
      avoid_hardcoded_credentials: true    # critical — always on
      missing_dispose: true                # critical — always on
      prefer_trailing_comma: false         # disabled — 312 issues (Group D)
      some_clean_rule: true                # auto-enabled — 0 issues
```

## Eliminating `analysis_options_custom.yaml`

The current custom config file tries to do too much. In the new design, most
of its contents are handled automatically or moved elsewhere.

### What currently lives in `analysis_options_custom.yaml`

| Section | Lines | New Location |
|---------|-------|-------------|
| Analysis settings (`max_issues`) | 7 | `analysis_options.yaml` under `saropa_lints:` |
| Platform settings | 8 | **Auto-detected** from `pubspec.yaml`. Override in `analysis_options.yaml` if needed. |
| Package settings (21 packages) | 23 | **Auto-detected** from `pubspec.yaml`. No config needed. |
| Stylistic rules (170+ rules) | 170 | **Same triage as all other rules.** Written to `analysis_options.yaml` diagnostics. |
| Rule overrides | 12 | **Stays** — but simplified. |

### New approach: `analysis_options_custom.yaml` becomes minimal

```yaml
# Saropa Lints — User Overrides
# Rules here override triage decisions and are never changed by init.
# Format: rule_name: true/false

# Example:
# avoid_print: false         # Allow print statements in this project
# prefer_const_constructors: true   # Force-enable regardless of triage
```

That's it. A handful of lines. Only rules the user explicitly wants to
force-enable or force-disable. Everything else is handled by:

- **Auto-detection** (platforms, packages) from `pubspec.yaml`
- **Triage decisions** (written to `analysis_options.yaml` diagnostics)
- **Re-running init** (updates decisions based on current project state)

### Platform and package detection

On every run, init reads `pubspec.yaml` and determines:
- **Platforms**: Flutter project? Has `macos/`, `web/`, `linux/` directories?
  Auto-detects and filters platform-specific rules. Shows what was detected:

  ```
  Detected platforms: iOS, Android
  Skipped 47 rules for: macOS, Web, Windows, Linux
  ```

- **Packages**: Scans `dependencies` and `dev_dependencies`. Auto-filters
  rules for packages not in use. Shows what was detected:

  ```
  Detected packages: Riverpod, Firebase, Dio
  Skipped 83 rules for: Bloc, GetX, Provider, Hive, Isar...
  ```

No manual platform/package config needed. If auto-detection is wrong,
the user can override in `analysis_options_custom.yaml`:

```yaml
# Override auto-detection:
platforms:
  web: true    # init didn't detect web, but we need it
```

### Migration from current custom config

On first run with an existing `analysis_options_custom.yaml`:
- Read all existing rule overrides and honor them
- Auto-detect platforms/packages (ignore the manual settings)
- Show what changed: "Previously manual, now auto-detected"
- Rewrite the file to the minimal format
- Back up the old file as `analysis_options_custom.yaml.bak`

## Preserving Existing Features

| Feature | Status |
|---------|--------|
| Platform filtering | **Improved** — auto-detected, no manual config |
| Package filtering | **Improved** — auto-detected, no manual config |
| User rule overrides | **Simplified** — minimal file, only explicit overrides |
| V4/V7 migration detection | Preserved — runs in pre-flight |
| Post-write validation | Preserved |
| `--dry-run` | Preserved |
| `--reset` | Preserved — clears triage decisions, re-triages all |
| `--no-stylistic` | Preserved — skips stylistic triage |
| Log file generation | Preserved |

## Removed / Changed

| Feature | Change |
|---------|--------|
| `--tier` flag | **Removed.** Tiers become internal. The triage replaces tier selection. |
| `:init` suffix | **Removed.** `dart run saropa_lints` is the default command. |
| Tier selection prompt | **Removed.** Replaced by data-driven triage. |
| Per-rule stylistic walkthrough | **Removed.** Replaced by bulk group triage. |
| `--stylistic-all` | **Removed.** Stylistic triage handles this. |
| `--reset-stylistic` | **Merged into `--reset`.** |
| `--upgrade` | **Never existed, never will.** Same command always. |
| `analysis_options_custom.yaml` (massive) | **Replaced** with minimal overrides-only file. |
| Manual platform config | **Replaced** with auto-detection from `pubspec.yaml`. |
| Manual package config | **Replaced** with auto-detection from `pubspec.yaml`. |
| Stylistic rules in custom config | **Removed.** Stylistic rules go through triage like all other rules. |
| Tier presets (`tiers/recommended.yaml`) | **TBD.** May still be useful for zero-config, or may be deprecated. |

## Tier Presets (Open Question)

Currently users can skip the wizard entirely with:

```yaml
include: package:saropa_lints/tiers/recommended.yaml
```

Options:
1. **Keep as-is.** Presets are the "I don't want a wizard" path. The new init
   is the "I want smart setup" path. Both coexist.
2. **Deprecate presets.** The new init is fast enough that presets add no value.
3. **Replace with a single preset.** `essential.yaml` only, for users who want
   the minimum viable setup without running init.

Recommendation: Option 1 for now. Revisit after the new init ships.

## Group Threshold Scaling

The boundaries between Group A/B/C/D should scale with project size.
A 10-file project with 5 issues per rule is different from a 500-file project
with 5 issues per rule.

Proposed scaling factor: `issues_per_rule / total_files`

Or simpler: fixed thresholds that work for most projects, tuned by experience.
Start with fixed thresholds, add scaling later if needed.

Suggested initial thresholds:
- Group A: 1–5 issues
- Group B: 6–20 issues
- Group C: 21–100 issues
- Group D: 100+ issues

## Status Command

A lightweight command to check progress without re-running init:

```
$ dart run saropa_lints:status

Saropa Static Analysis v8.1.0

  Enabled:  1,542 rules
  Disabled:   505 rules

  Disabled rules by effort:
    38 rules now have 0 issues    ← ready to enable
    71 rules have < 5 issues      ← quick wins
    82 rules have 5–20 issues     ← moderate effort
    314 rules have 20+ issues     ← significant work

  Run 'dart run saropa_lints' to update.
```

## Modularization

The current `bin/init.dart` is 4,800 lines. This redesign MUST decompose it.

### Proposed Module Structure

```
bin/
  init.dart                        # Entry point only (~50 lines)

lib/src/init/
  init_runner.dart                 # Main orchestrator (~100 lines)
  cli_args.dart                    # Argument parsing
  preflight.dart                   # Pre-flight checks (SDK, pubspec, migration)
  analyzer.dart                    # Run full analysis, collect issue counts
  triage.dart                      # Group rules by volume, present choices
  triage_groups.dart               # Group threshold logic and scaling
  stylistic_triage.dart            # Stylistic rules triage (separate flow)
  config_reader.dart               # Read existing YAML configs
  config_writer.dart               # Generate and write YAML configs
  custom_overrides.dart            # analysis_options_custom.yaml management
  migration.dart                   # V4/V7 migration detection and conversion
  platform_filter.dart             # Platform-based rule filtering
  package_filter.dart              # Package-based rule filtering
  validation.dart                  # Post-write config validation
  reporter.dart                    # Console output, colors, progress bars
  log_writer.dart                  # Log file generation
  models/
    init_state.dart                # State passed between phases
    triage_result.dart             # Triage decisions
    analysis_result.dart           # Per-rule issue counts
    rule_decision.dart             # Enable/disable decision + reason
```

### Orchestrator Pattern

`init_runner.dart` calls phases in sequence, passing state forward:

```dart
Future<void> runInit(CliArgs args) async {
  final state = InitState();

  await preflight(state, args);
  await analyzeProject(state);
  presentCriticalIssues(state);
  autoEnableCleanRules(state);
  await triageByVolume(state, args);
  await triageStylistic(state, args);
  await writeConfig(state, args);
  await validate(state);
  writeLog(state);
}
```

Each phase is a focused module with a clear input/output contract.

### File Size Targets

No module should exceed 200 lines. If it does, split further.

## Implementation Plan

### Phase 1: Modularize (no behavior change)

Extract the existing init.dart into modules. Same behavior, same output,
same tests. Just split into files. This is a prerequisite for everything else.

### Phase 2: Add Analysis Step

Add the "run all rules and count issues" capability. This is the foundation
for data-driven triage. May require a custom analysis runner or integration
with `dart analyze` output parsing.

Key question: How do we run all 2047 rules against the project and get
per-rule issue counts efficiently? Options:
- Run `dart analyze` with all rules enabled, parse output
- Use the plugin API to run analysis programmatically
- Run the plugin in a special "count only" mode

### Phase 3: Implement Triage UI

Replace tier selection with the Group A/B/C/D triage flow.
Replace stylistic walkthrough with bulk stylistic triage.

### Phase 4: Implement Re-run Detection

Detect existing config, compare current analysis to previous state,
show progress and surface rules ready to enable.

### Phase 5: Status Command

Add `dart run saropa_lints:status` as a lightweight progress check.

## Open Questions

1. **Analysis performance**: Running all 2047 rules on a large project could
   be slow. Is there a fast path? Can we run analysis in parallel?
   Memory concern: all rules = ~4GB.

2. **Tier presets**: Keep, deprecate, or simplify? (See section above.)

3. **Group thresholds**: Fixed or scaled? Start fixed, tune later?

4. **Auto-fix awareness**: Should triage show which rules have auto-fixes?
   A rule with 200 issues but an auto-fix is more manageable than a rule
   with 20 issues and no fix. This could influence grouping.

5. **CI mode**: Non-interactive `--ci` flag that auto-enables Groups A+B,
   disables C+D? Or just use existing `--reset` with a tier?

6. **Quick fix counts**: "34 rules with auto-fix available" — does this
   change the user's decision? Probably yes. Show it.

7. **Backward compatibility**: Users with existing configs generated by
   the old wizard. The new init should read and preserve their decisions,
   only triaging rules that have no existing decision.
