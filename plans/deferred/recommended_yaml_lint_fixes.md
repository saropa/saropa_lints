# Plan: Fix recommended.yaml Lint Issues in lib/

**Status:** In progress — Phase 1 complete, Phase 2a reviewed (no action), Phase 2b+3 pending
**Created:** 2026-08-04
**Updated:** 2026-08-06
**Estimated scope:** ~127 issues across lib/ (from dart analyze with recommended.yaml)
**Purpose:** Future-proof against pana baseline upgrades; cleaner codebase

---

## Background

The project's `analysis_options.yaml` excludes `lib/**` (line ~64) to prevent
the package's own lint rules from firing on their own source. pub.dev's pana
strips that exclude and applies `package:lints/core.yaml`. All 41 core.yaml
issues were fixed in v14.4.2.

`package:lints/recommended.yaml` is a superset of core.yaml. Running analysis
with recommended.yaml surfaces ~127 additional issues. These don't affect the
current pub.dev score but would if pana upgrades its baseline.

## Verification method

To see these issues locally:

1. Temporarily edit `analysis_options.yaml`:
   - Remove `lib/**` from `analyzer.exclude`
   - Set `include: package:lints/recommended.yaml`
2. Run `dart analyze lib/` (background, per project rules)
3. Restore `analysis_options.yaml` after

Do NOT commit `analysis_options.yaml` changes.

---

## Fix phases

### Phase 1 — Mechanical, high-confidence (do first)

These are safe, pattern-based fixes with no semantic risk.

#### 1a. `unnecessary_string_interpolations` (~44 sites)

**What:** String literals whose entire content is a single interpolation:
`'${variable}'` → `'$variable'`, or `'$variable'` where the string adds nothing
→ just use `variable` directly.

**Fix:** Remove the string wrapper or simplify the interpolation.

**Files (44 known locations):**
- `lib/saropa_lints.dart:3782`
- `lib/src/cli/project_vibrancy.dart:1358,1381,1382,1391,1402`
- `lib/src/init/stylistic_section.dart:254,261`
- `lib/src/init/composite_plugin_scaffold.dart:73`
- `lib/src/init/custom_overrides_core.dart:200,201,231,232,233`
- `lib/src/cli/project_health/git_signals.dart:39`
- `lib/src/fixes/control_flow/collapse_nested_if_fix.dart:70`
- `lib/src/saropa_lint_rule.dart:625,713`
- `lib/src/rules/architecture/disposal_rules.dart:457`
- `lib/src/ignore_utils.dart:99,101,122,124`
- `lib/src/config/rule_packs.dart:426`
- `lib/src/cli/project_health/ai_fix_handoff.dart:36`
- `lib/src/native/plugin_logger.dart:346`
- `lib/src/scan/scan_runner.dart:514`
- `lib/src/fixes/control_flow/prefer_null_aware_call_fix.dart:109`
- `lib/src/rules/resources/resource_management_rules.dart:711`
- `lib/src/rules/platforms/ios_capabilities_permissions_rules.dart:128`
- `lib/src/init/config_writer.dart:347,367,370`
- `lib/src/init/log_writer.dart:80,96,98,114`
- `lib/src/rules/architecture/architecture_rules.dart:849`
- `lib/src/init/project_info.dart:184`
- `lib/src/init/whats_new.dart:80`
- `lib/src/init/init_runner.dart:46,48,67`
- `lib/src/cli/project_health/health_export_markdown.dart:49`

**Risk:** None. Pure syntax simplification.

#### 1b. `unnecessary_string_escapes` (~17 sites)

**What:** Escaped characters that don't need escaping — e.g. `\"` inside
single-quoted strings where `"` is not a delimiter.

**Fix:** Remove the backslash.

**Files (17 escapes across 7 locations):**
- `lib/src/rules/widget/widget_patterns_ux_rules.dart:752` (2 escapes)
- `lib/src/rules/widget/widget_patterns_require_rules.dart:1360` (2), `:2142` (2), `:2144` (4), `:2770` (4)
- `lib/src/rules/core/naming_style_rules.dart:45` (2)
- `lib/src/rules/ui/internationalization_rules.dart:526` (1)

**Risk:** None. The unescaped character is identical in behavior.

---

### Phase 2 — Judgment required (review each site)

#### 2a. `prefer_interpolation_to_compose_strings` (~62+ sites)

**What:** String concatenation via `+` where interpolation would work.
Dominant pattern: `RegExp(r'\b' + RegExp.escape(word) + r'\b')`.

**Fix:** Replace `+` concatenation with `'..${expr}..'` interpolation. BUT:
many sites concatenate raw strings (`r'...'`) with computed values — converting
to interpolation means switching from raw to regular strings and re-escaping
all regex metacharacters. Each site needs individual judgment.

**Decision rule:**
- If both operands are regular strings → convert to interpolation
- If raw strings (`r'...'`) are involved → leave as-is (escaping cost > lint benefit) or add `// ignore:` with "raw string concatenation" rationale

**Files (62+ known, partial list — grep floor, not exhaustive):**
- `lib/src/rules/architecture/disposal_rules.dart:470,473,481,488,1014,...`
- `lib/src/rules/architecture/architecture_rules.dart:62,175`
- `lib/src/rules/security/security_network_input_rules.dart:4557,4575`
- `lib/src/rules/packages/equatable_rules.dart:950,1060,1163,1166`
- `lib/src/rules/packages/hive_rules.dart:408,680,776,789,1697`
- `lib/src/rules/platforms/ios_capabilities_permissions_rules.dart:578,1375,2124,2195`
- `lib/src/rules/platforms/ios_platform_lifecycle_rules.dart:2017,3064`
- (see full list in grep output — search `' + ` in lib/)

**Risk:** Low-medium. Regex patterns could break if escaping is botched during
raw→regular string conversion.

#### 2b. `unnecessary_nullable_for_final_variable_declarations` (~58 reported by dart analyze)

**What:** `final Type? x = <non-nullable expr>` where the `?` is unnecessary
because the RHS is provably non-null.

**Fix:** Remove the `?` from the type annotation.

**Caveat:** Grep cannot resolve Dart static types — the original ~58 count comes
from a `dart analyze` run with recommended.yaml. A fresh `dart analyze` pass is
needed to get exact locations. Many apparent hits assign from nullable APIs
(analyzer getters, `?.`-chains) and are correctly nullable.

**Risk:** Low. Removing `?` from a truly non-nullable assignment is always safe.
But misidentifying a nullable RHS would cause a compile error (caught by tests).

---

### Phase 3 — Requires dart analyze confirmation

These categories can't be reliably inventoried by grep.

#### 3a. `unnecessary_breaks` (~30+ estimated)

**What:** Explicit `break;` at the end of non-empty switch cases (Dart 3+ makes
these implicit).

**Fix:** Remove the `break;` statement.

**Risk:** None — Dart 3 switch semantics guarantee implicit break.

#### 3b. `use_super_parameters` (count unknown)

**What:** Constructor parameters that are immediately forwarded to `super()`
without transformation.

**Fix:** Convert to super-parameter syntax: `MyClass({super.key})`.

**Risk:** None — syntactic sugar, identical semantics.

#### 3c. `no_leading_underscores_for_local_identifiers` (count unknown)

**What:** Local variables or parameters named with leading underscore (e.g.
`final _result = ...`). In Dart, leading underscore means library-private at
the top level but has no special meaning for locals.

**Fix:** Rename to remove the leading underscore. May require updating all
references within the function.

**Risk:** Low. Purely local scope — no API surface changes.

#### 3d. Other scattered rules (count unknown)

May include `prefer_final_locals`, `avoid_function_literals_in_foreach_calls`,
`prefer_for_elements_to_map_fromIterable`, etc. Exact inventory requires a
`dart analyze` pass.

---

## Execution steps

1. **Get exact inventory:** Run `dart analyze lib/` with recommended.yaml
   enabled (background). Record every issue with file:line:rule.
2. **Phase 1a+1b:** Mechanical fixes. ~61 sites. One commit: `fix: remove
   unnecessary string interpolations and escapes (recommended.yaml cleanup)`.
3. **Phase 2a:** Review each `prefer_interpolation_to_compose_strings` site.
   Fix where clean; `// ignore:` with rationale where raw strings make
   interpolation worse. One commit.
4. **Phase 2b:** Fix `unnecessary_nullable_for_final_variable_declarations`
   from the dart analyze output. One commit.
5. **Phase 3:** Fix remaining rules (breaks, super params, underscore locals,
   etc.). One commit per logical group or one combined commit.
6. **Verify:** Re-run `dart analyze lib/` with recommended.yaml — 0 issues.
7. **Test:** `dart test` — all passing.
8. **Restore:** Ensure `analysis_options.yaml` is back to its original state.

## Commit strategy

3-5 commits, grouped by rule category. Each commit message follows the
`fix: description` format. No version bump — these are internal quality
improvements, not user-facing changes.

## CHANGELOG

One entry under `[Unreleased]` in the Maintenance details expander:
`Internal code quality: resolved recommended.yaml lint issues across lib/`

## Time estimate

- Phase 1: ~30 min (mechanical)
- Phase 2: ~45 min (judgment calls on 62+ concat sites + 58 nullable types)
- Phase 3: ~30 min (depends on dart analyze output)
- Verify + test: ~15 min
- **Total: ~2 hours**
