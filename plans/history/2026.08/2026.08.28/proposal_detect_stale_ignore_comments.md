# PROPOSAL: Detect stale `// ignore:` comments where the suppressed diagnostic no longer fires

**Status: Partial — CLI detection shipped; IDE integration pending upstream**

Created: 2026-08-28
Type: New rule
Related rules: all rules (meta-rule)

---

## Summary

A new rule that detects `// ignore: <rule_name>` comments where the suppressed
diagnostic no longer fires — the underlying code was fixed or refactored but the
ignore comment was left behind. Stale ignores accumulate silently, obscure the
real suppression count, and mask future regressions (if the pattern reappears,
the stale ignore silently suppresses it without the developer noticing).

User request (verbatim): "we should also have a bug report that surfaces
unnecessary //ignores when the code is fixed."

---

## Motivation

In the downstream project (`contacts`), a full audit found 1200+ `// ignore:`
comments across 130+ distinct rules. An unknown fraction of these are stale —
the code was fixed but the ignore was never removed. Stale ignores:

1. **Inflate suppression counts** — audits overcount FPs because stale ignores
   look identical to active suppressions.
2. **Mask regressions** — if the same code pattern reappears (e.g., after a
   merge), the stale ignore silently suppresses the new diagnostic.
3. **Reduce trust in the codebase** — developers see ignore comments and assume
   the diagnostic still fires, making them hesitant to touch the code.
4. **Accumulate indefinitely** — no existing tooling detects or removes them.

---

## Detection / Behavior

### Should flag (stale ignore — diagnostic no longer fires)

```dart
// Code was refactored to use DateTime.parse() instead of constructor
final DateTime date = DateTime.parse(dateString);
// ignore: saropa_lints/avoid_datetime_constructor -- STALE: no DateTime() on next line
```

```dart
// Variable was made final, but ignore for prefer_final_locals remains
// ignore: prefer_final_locals -- STALE: variable is already final
final String name = getName();
```

### Should pass (active ignore — diagnostic would fire without it)

```dart
// ignore: saropa_lints/avoid_context_in_async_static -- context passed to awaited call only
static Future<void> show(BuildContext context) async {
  await showDialog(context: context, builder: (_) => const MyDialog());
}
```

---

## Proposed Tier

Tier: **Recommended**

Justification: stale ignores are maintenance debt with no upside. Every stale
ignore is safe to remove — by definition, removing it changes nothing because
the diagnostic it suppresses no longer fires. This is a zero-risk cleanup rule.

---

## Edge Cases

1. **Ignore for a rule that was removed from the linter** — the ignore is stale
   (no diagnostic can fire), but the rule name won't be recognized. The rule
   should still flag it as stale if no diagnostic with that code exists in the
   current analyzer session.
2. **Ignore on a line that has multiple diagnostics** — only flag if NONE of the
   diagnostics match the ignored rule name. If the ignore suppresses one of
   several diagnostics, it is still active.
3. **`// ignore_for_file:` directives** — harder to detect staleness (requires
   whole-file analysis). Could be Phase 2.
4. **Conditional compilation (`// ignore:` inside `kDebugMode` blocks)** — the
   diagnostic may fire only in certain configurations. Conservative approach:
   only flag file-level ignores as stale if the rule never fires anywhere in
   the file.
5. **`// ignore:` with rationale comment** — the ignore itself is the detection
   target, not the rationale. Flag the ignore; the quick fix removes both.

---

## Alternatives Considered

1. **External script (`find_stale_ignores.py`)** — works but requires manual
   invocation and doesn't integrate with IDE diagnostics. A lint rule provides
   real-time feedback.
2. **Dart SDK built-in `unnecessary_ignore`** — Dart's analyzer has
   `unnecessary_ignore` but it only covers core analyzer codes, not
   `custom_lint` / plugin rules. This proposal fills that gap for saropa_lints
   rules specifically.

---

## Investigation Results (2026-08-28)

**A lint rule cannot detect stale ignores for plugin diagnostics.** Three
blockers were confirmed by source inspection:

1. **`unnecessary_ignore` skips plugin codes** — the analyzer's built-in
   `IgnoreValidator` (line 209-213 of `ignore_validator.dart`) explicitly skips
   any diagnostic code not in `Registry.ruleRegistry` (core lints only). Plugin
   rule names like `avoid_datetime_constructor` are silently ignored.

2. **No cross-rule diagnostic query** — each rule gets a write-only
   `DiagnosticReporter`. The collected diagnostics land in a
   `RecordingDiagnosticListener` owned by `PluginServer`, inaccessible to rules.
   There is no inter-rule communication channel.

3. **`afterLibrary` hook exists but carries no shared state** — the callback
   receives no arguments. A rule can accumulate its own state but cannot read
   other rules' results.

---

## Implementation Paths (ranked)

### Option A: Standalone CLI tool (shippable now)

Extend the existing `scan` CLI to detect stale ignores:
1. Parse all `// ignore: saropa_*` comments and their locations.
2. Run full analysis (the scan CLI already does this).
3. Diff: any ignore whose rule name does not appear in the diagnostics for that
   line is stale.

**Pros:** works today, no upstream dependency, leverages existing `scan` infra.
**Cons:** no real-time IDE feedback — requires manual invocation or CI hook.

### Option B: Upstream PR to `analysis_server_plugin` (right long-term answer)

Add ~20 lines to `PluginServer` (after line 491) to run `IgnoreValidator`
against plugin diagnostics. The infrastructure is already in place: `ignoreInfo`
is parsed, `listener.diagnostics` holds the reported set, the subtracted ignore
names are the stale ones. There is even a TODO comment at line 213 of
`ignore_validator.dart` acknowledging this gap.

**Pros:** IDE-native detection, works for all plugin rules, zero saropa-side code.
**Cons:** depends on upstream maintainer acceptance and release timing.

### Option C: Self-only per-rule detection (not recommended)

Each saropa rule re-checks its own logic on lines with matching `// ignore:`
comments. Impractical at 2300+ rules — the maintenance cost and performance
impact are prohibitive.

---

## Resolution (2026-08-28)

**Option A implemented:** `--find-stale-ignores` flag added to the scan CLI.

Usage:
```bash
dart run saropa_lints scan . --find-stale-ignores
dart run saropa_lints scan . --find-stale-ignores --format json
dart run saropa_lints scan . --find-stale-ignores --tier comprehensive
```

Algorithm: the scan CLI does not honor `// ignore:` directives (rules fire
regardless of ignore comments), so the detector parses all `// ignore:`
comments referencing saropa_lints rules, then checks whether the scan produced
a matching diagnostic on the target line. No match = stale.

Handles both standalone ignores (own line, suppresses next line) and inline
ignores (end of code line, suppresses same line). Skips `// ignore_for_file:`
for now (requires whole-file analysis, deferred to Phase 2). Exits 1 if any
stale ignores found, 0 if clean.

**What's still missing:** Real-time IDE integration (Option B) depends on an
upstream `analysis_server_plugin` change to run `IgnoreValidator` against
plugin diagnostics.

---

## Environment

- saropa_lints version: 15.2.4
- Dart SDK version: 3.13.1
- Triggering project: `contacts` (d:\src\contacts)
