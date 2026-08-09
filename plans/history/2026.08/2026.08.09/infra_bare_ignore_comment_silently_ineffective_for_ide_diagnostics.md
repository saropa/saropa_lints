# BUG: infra — bare `// ignore: rule_name` silently fails to suppress IDE/native-plugin diagnostics

**Status: Fixed**

Created: 2026-08-09
Rule: N/A (infrastructure — spans `ignore_utils.dart` suppression matching and the native-plugin ignore-comment convention; also a candidate new self-check rule)
File: `lib/src/ignore_utils.dart` (matching logic), `lib/src/saropa_lint_rule.dart:3217` (call site), `lib/src/rules/stylistic/formatting_rules.dart:1039` (precedent rule to model a fix after)
Severity: High — silently ineffective suppression on every `saropa_lints` rule, discovered independently by a downstream user in `contacts` (2026-08-09) despite an existing documented pitfall for this exact issue

---

## Summary

A `// ignore: <bare_rule_name>` comment (no `saropa_lints/` prefix) is accepted and appears to work when suppressing rule reports via `IgnoreUtils.hasIgnoreComment` (used by `dart run saropa_lints scan` and the rule's own `_isSuppressed` check), but is **silently NOT honored** by the IDE / Dart analysis server when `saropa_lints` runs as a native analyzer plugin (top-level `plugins:` in `analysis_options.yaml`, no `custom_lint`). The analyzer's own plugin-diagnostic ignore convention requires the `saropa_lints/` prefix (`// ignore: saropa_lints/rule_name`) to namespace plugin-contributed diagnostics from core/other-plugin lints of the same name. A user who writes the bare form gets no error, no warning, and no strikethrough — the ignore comment just does nothing, and the diagnostic keeps reappearing after every analyzer reset. This is already flagged as a known pitfall in `bugs/BUG_REPORT_GUIDE.md`'s Common Pitfalls table, but there is no automated diagnostic (in `saropa_lints` itself, or in the scan tool) that catches the mistake at write-time — a downstream engineer has to independently discover it (again) via trial and error.

**Expected:** either (a) the analyzer/plugin machinery accepts the bare form transparently, or (b) `saropa_lints` proactively flags a bare-form ignore comment targeting one of its own rule IDs, telling the author to add the `saropa_lints/` prefix — instead of leaving the suppression silently broken.

**Actual:** the bare form is silently ineffective for IDE-surfaced diagnostics; nothing in `saropa_lints` detects or warns about this.

---

## Attribution Evidence

```bash
# ignore_utils.dart owns the bare-name matching logic used by saropa_lints' own suppression checks
grep -n "static bool hasIgnoreComment\|_commentNamesRule" lib/src/ignore_utils.dart
# lib/src/ignore_utils.dart:113:  static bool _commentNamesRule(
# lib/src/ignore_utils.dart:128:  static bool hasIgnoreCommentOnToken(Token? token, String ruleName) {
# lib/src/ignore_utils.dart:135:        if (_commentNamesRule(text, ruleName, hyphenatedName)) {
# lib/src/ignore_utils.dart:222:  static bool hasIgnoreComment(AstNode node, String ruleName) {
# lib/src/ignore_utils.dart:540:        if (_commentNamesRule(text, ruleName, hyphenatedName)) {
# lib/src/ignore_utils.dart:671:          if (_commentNamesRule(text, ruleName, hyphenatedName)) {

# Call site: _ruleName passed in is the BARE code name (code.lowerCaseName), no prefix
grep -n "code.lowerCaseName\|IgnoreUtils.hasIgnoreComment" lib/src/saropa_lint_rule.dart
# lib/src/saropa_lint_rule.dart:2143:      super(name: code.lowerCaseName, description: code.problemMessage);
# lib/src/saropa_lint_rule.dart:3217:    if (IgnoreUtils.hasIgnoreComment(node, _ruleName)) {

# Precedent: an existing rule already inspects raw ignore-comment text and reports on the comment token itself
grep -n "class RequireIgnoreCommentSpacingRule" lib/src/rules/stylistic/formatting_rules.dart
# lib/src/rules/stylistic/formatting_rules.dart:1039:class RequireIgnoreCommentSpacingRule extends SaropaLintRule {
grep -n "formatting_rules.dart" lib/src/rules/all_rules.dart
# lib/src/rules/all_rules.dart:91:export 'stylistic/formatting_rules.dart';

# The pitfall is already documented (but unenforced) in the bug guide itself
grep -n "ignored for a .saropa_lints. rule" bugs/BUG_REPORT_GUIDE.md
# bugs/BUG_REPORT_GUIDE.md:333: | `// ignore:` ignored for a `saropa_lints` rule | ... |
```

**Emitter registration:** N/A — no rule currently owns this check. If implemented as a new rule, it belongs in `lib/src/rules/stylistic/formatting_rules.dart` near `RequireIgnoreCommentSpacingRule` (line ~1039) and would need an export/registration entry in `lib/src/rules/all_rules.dart` (already exports the file at line 91) plus `lib/src/tiers.dart`.
**Diagnostic `source` / `owner` as seen in Problems panel:** `dartAnalysisLSP` (the diagnostics this bug is *about* — `avoid_datetime_constructor`, `avoid_datetime_constructor_unvalidated` — reported that way; the bug is that suppressing them requires knowledge undocumented at the point of use)

---

## Reproducer

Downstream repro from `contacts` (`d:\src\contacts\lib\utils\primitive\date_time\date_formatting.dart`):

```dart
// Attempt 1 — bare rule name, follows .claude/rules/dart.md's documented
// convention ("Use the bare rule name (matches the diagnostic `code`)").
// This is accepted by the editor with no error, but the diagnostic
// reappears after an analyzer restart — the suppression silently no-ops.
).format(DateTime(now.year, month)); // ignore: avoid_datetime_constructor, avoid_datetime_constructor_unvalidated -- month is this.month, already a valid component

// Attempt 2 — saropa_lints/-prefixed form. This one actually works.
).format(DateTime(now.year, month)); // ignore: saropa_lints/avoid_datetime_constructor, saropa_lints/avoid_datetime_constructor_unvalidated -- month is this.month, already a valid component
```

Nothing in `saropa_lints` (scan output, IDE diagnostics, a lint rule) flags attempt 1 as malformed or ineffective. The only signal is that the original diagnostic keeps recurring.

**Frequency:** Always, for every bare-form `// ignore:` targeting a `saropa_lints`-owned rule ID when `saropa_lints` runs as a native analyzer plugin (not `custom_lint`).

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | Either the bare form is honored end-to-end, or `saropa_lints` reports a diagnostic ("this ignore comment references `saropa_lints` rule `X` without the required `saropa_lints/` prefix — the analyzer will not honor it") at write time |
| **Actual** | Bare form is silently accepted by nothing-in-particular: no analyzer error, no `saropa_lints` diagnostic, but the targeted rule's diagnostic keeps firing anyway. The only way to discover this is trial-and-error plus an analyzer restart, or reading `bugs/BUG_REPORT_GUIDE.md`'s pitfalls table (which downstream consumers do not have open) |

---

## AST Context

N/A for the underlying analyzer-vs-plugin namespacing behavior (that lives outside `saropa_lints`, in the Dart SDK's plugin ignore-comment handling). For the proposed new rule, the relevant walk is the same one `RequireIgnoreCommentSpacingRule` already uses:

```
CompilationUnit
  └─ Token stream walk (node.beginToken .. node.endToken)
      └─ Token.precedingComments
          └─ Comment lexeme containing "ignore:" or "ignore_for_file:"
              ← new rule reports here when the referenced rule name
                is a known saropa_lints code (present in
                kRulePackRuleCodesGenerated, see
                lib/src/config/rule_pack_codes_generated.dart) but the
                comment text does NOT contain "saropa_lints/" immediately
                before it
```

---

## Root Cause

### Hypothesis A: Dart's native-analyzer-plugin ignore convention is namespaced; `saropa_lints`'s own suppression matching (`IgnoreUtils`) is not

`IgnoreUtils.hasIgnoreComment`/`_commentNamesRule` (`lib/src/ignore_utils.dart:113-124`) matches the **bare** rule name as a whole word anywhere in the comment text — it has no knowledge of, and does not require, a `saropa_lints/` prefix. This path is what `dart run saropa_lints scan` and the rule's internal `_isSuppressed` (`lib/src/saropa_lint_rule.dart:3208-3222`) use to decide whether to report/track a violation, so a bare-form ignore comment *does* suppress there.

The IDE's live diagnostics, however, come from the native analyzer plugin pipeline (`AnalysisRule.reportAtOffset` → standard SDK diagnostic reporting), which the core Dart analyzer itself filters using its own ignore-comment recognition — and for plugin-contributed diagnostics that recognition is namespaced (`<plugin_name>/<rule_name>`) precisely so a plugin's `avoid_print`-alike does not accidentally get suppressed (or accidentally suppress) a same-named core lint. `saropa_lints` does not control this layer; it is SDK/plugin-protocol behavior. This produces two suppression paths with two different accepted syntaxes for the *same* `// ignore:` comment, and nothing surfaces the mismatch to the user.

### Hypothesis B: `.claude/rules/dart.md`-style downstream guidance actively teaches the broken (bare) form

Per `[[project_saropa_lints_ignore_trailing_placement]]` (contacts-repo memory), `.claude/rules/dart.md` in the downstream `contacts` repo says "Use the bare rule name (matches the diagnostic `code`)" and is flagged there as predating the v5 prefix migration. If `saropa_lints`' own `init`/`migration.dart` (`convertIgnoreComments`) already migrates bare → prefixed on `dart run saropa_lints init`, but plenty of ignore comments are hand-written after that migration ran once, the drift will keep recurring for every new suppression a downstream engineer writes by hand — with no local signal that they've done it wrong.

---

## Suggested Fix

Two complementary changes:

1. **New rule** (models `RequireIgnoreCommentSpacingRule`, `lib/src/rules/stylistic/formatting_rules.dart:1039-1115`, almost line-for-line): walk `CompilationUnit` tokens, inspect `precedingComments` for `ignore:`/`ignore_for_file:` directives, extract each comma-separated rule name, and for each name that (a) matches (case-sensitive) an entry in `kRulePackRuleCodesGenerated`'s value sets (`lib/src/config/rule_pack_codes_generated.dart`) and (b) is NOT immediately preceded by `saropa_lints/` in the comment text, report a diagnostic on the comment token: *"This `// ignore:` targets saropa_lints rule `X` without the `saropa_lints/` prefix the IDE requires — the analyzer will not suppress this diagnostic. Use `saropa_lints/X`."* Provide a quick fix that inserts the prefix (mirrors `RequireIgnoreCommentSpacingFix`, `lib/src/fixes/formatting/require_ignore_comment_spacing_fix.dart`).
2. **Extend `migration.dart`'s `convertIgnoreComments`** (`lib/src/init/migration.dart`) so `dart run saropa_lints scan`/`init` can be re-run idempotently as a one-shot bulk fixer across a repo, not only at initial `init` time — so existing bare-form comments written after the v5 migration (the common case here) get caught by a sweep, not only by the new rule firing one site at a time.

Do not change `IgnoreUtils` to require the prefix — that would break the internal `_isSuppressed`/scan path's existing bare-form acceptance and is a separate, larger compatibility decision.

---

## Fixture Gap

New fixture at `example/lib/stylistic/require_ignore_comment_plugin_prefix_fixture.dart` (name TBD by whoever picks the final rule name) should include:

1. **Bare-form ignore targeting a real saropa_lints rule id** — expect LINT (e.g. `// ignore: avoid_datetime_constructor`)
2. **Prefixed-form ignore targeting the same rule id** — expect NO lint (e.g. `// ignore: saropa_lints/avoid_datetime_constructor`)
3. **Bare-form ignore targeting a name that is NOT a saropa_lints rule id** (e.g. a core analyzer lint like `unused_import`) — expect NO lint; this rule must not flag suppressions of non-saropa_lints diagnostics
4. **`ignore_for_file:` variant**, both bare and prefixed — same expectations as 1/2
5. **Multiple comma-separated rule names on one directive, mixed bare/prefixed** — expect LINT only for the bare entries, at the correct column for each
6. **Hyphenated rule name variant** (`avoid-datetime-constructor`) bare vs prefixed — should follow the same hyphen/underscore flexibility `IgnoreUtils.toHyphenated` already provides elsewhere

---

## Changes Made

1. **New rule `require_ignore_comment_plugin_prefix`** in `lib/src/rules/stylistic/formatting_rules.dart` — walks `CompilationUnit` tokens, inspects `precedingComments` for `ignore:`/`ignore_for_file:` directives, extracts comma-separated rule names, and reports when a bare name matches a known saropa_lints rule (from all tier sets in `tiers.dart`). Supports hyphenated variants and trailing `--` comments.
2. **Quick fix `RequireIgnoreCommentPluginPrefixFix`** in `lib/src/fixes/formatting/require_ignore_comment_plugin_prefix_fix.dart` — inserts `saropa_lints/` prefix before each bare saropa_lints rule name in the flagged comment.
3. **Registered** in `_allRuleFactories` (`lib/saropa_lints.dart`) and assigned to `essentialRules` tier (`lib/src/tiers.dart`).

---

## Tests Added

1. **Fixture** `example/lib/formatting/require_ignore_comment_plugin_prefix_fixture.dart` — covers bare-form ignore (LINT), prefixed-form (OK), non-saropa rule bare (OK), `ignore_for_file:` bare (LINT) and prefixed (OK), mixed bare/prefixed in one directive (LINT), hyphenated bare (LINT), and bare with trailing `--` comment (LINT).
2. **Test entry** in `test/rules/stylistic/formatting_rules_test.dart` — instantiation pin + fix file existence check.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: v5.x (per `[[project_saropa_lints_plugin_version_pin]]` / `.claude/rules` pin in downstream `contacts` repo; exact version not captured at time of filing)
- Dart SDK version: not captured at time of filing
- Plugin mode: native analyzer plugin (`plugins:` top-level block), **not** `custom_lint` — per `[[project_saropa_lints_native_plugin]]`
- Triggering project/file: `d:\src\contacts\lib\utils\primitive\date_time\date_formatting.dart` and `d:\src\contacts\lib\views\event\event_list_screen.dart` (rules `avoid_datetime_constructor`, `avoid_datetime_constructor_unvalidated`); the underlying mismatch is rule-agnostic and reproduces for any `saropa_lints` rule

---

## Finish Report (2026-08-09)

### Defect

A bare `// ignore: rule_name` targeting a saropa_lints rule is silently ineffective in the IDE when saropa_lints runs as a native analyzer plugin. The Dart analyzer's plugin-diagnostic ignore convention requires the `saropa_lints/` prefix (`// ignore: saropa_lints/rule_name`). Without it, the suppression appears syntactically valid but does nothing — the diagnostic persists with no error or warning.

### Resolution

New rule `require_ignore_comment_plugin_prefix` (Essential tier, WARNING) detects bare-form ignore comments targeting known saropa_lints rules and offers a quick fix that inserts the `saropa_lints/` prefix.

### Files changed

- `lib/src/rules/stylistic/formatting_rules.dart` — `RequireIgnoreCommentPluginPrefixRule` class. Walks `CompilationUnit` token stream, inspects `precedingComments` for `// ignore:` / `// ignore_for_file:` directives (anchored to comment start, skips `///` doc comments), extracts comma-separated rule names, and reports when a bare name matches a known saropa_lints rule via `tiers.getAllDefinedRules()`. Supports hyphenated variants and trailing `--` comments.
- `lib/src/fixes/formatting/require_ignore_comment_plugin_prefix_fix.dart` — `RequireIgnoreCommentPluginPrefixFix`. Inserts `saropa_lints/` before each bare rule name. Uses covering-node-first with whole-file fallback (same pattern as sibling `RequireIgnoreCommentSpacingFix`).
- `lib/saropa_lints.dart` — registered `RequireIgnoreCommentPluginPrefixRule.new` in `_allRuleFactories`.
- `lib/src/tiers.dart` — added `'require_ignore_comment_plugin_prefix'` to `essentialRules`.
- `example/lib/formatting/require_ignore_comment_plugin_prefix_fixture.dart` — 7 fixture cases (bare, prefixed, non-saropa, ignore_for_file, mixed, hyphenated, trailing `--`).
- `test/rules/stylistic/formatting_rules_test.dart` — instantiation pin + fix file existence check.
- `CHANGELOG.md` — entry under `[Unreleased]`.

### Review fixes applied

1. **Unanchored regex** — original used `RegExp(r'//\s*ignore...')` with `firstMatch`, matching anywhere in a comment (including `///` doc comments). Fixed to anchor: strip `//` prefix, check not `///`, then `startsWith('ignore:')` / `startsWith('ignore_for_file:')` — matching the sibling `RequireIgnoreCommentSpacingRule`'s pattern.
2. **Tier misplacement** — original inserted rule into `recommendedOnlyRules` (the set ending near line 1742). Moved to `essentialRules` as specified in the bug report.
3. **Duplicated `_allSaropaRuleNames`** — both rule and fix manually unioned all tier sets. Replaced with `tiers.getAllDefinedRules()` (single source of truth).
4. **Fix missing fallback** — original bailed silently when `coveringNode.length > 500`. Added whole-file fallback scan (same pattern as sibling fix).
5. **Fixture directory** — moved from `example/lib/stylistic/` to `example/lib/formatting/` where the test's fixture verification group looks.

### Hardening (reflection gate pass)

6. **`endToken` edge case** — the token walk `beginToken .. endToken` excluded `endToken`'s own `precedingComments`. Added an explicit `_checkPrecedingComments(end, reporter)` after the loop.
7. **Fix doc-comment false match** — `_extractInsertions` could match `// ignore:` embedded inside a `///` doc comment line. Replaced the simple `text[idx-1] == '/'` guard with a proper line-start check: the text before `// ignore:` on its line must be whitespace-only.

### Bulk fix migration

8. **`dart run saropa_lints scan --fix-ignores`** — added `--fix-ignores` flag to the scan CLI. Calls the existing `convertIgnoreComments` from `migration.dart` with `getAllDefinedRules()`, printing per-file conversion counts. Enables idempotent repo-wide sweeps without re-running `init`.

### Test results

- 49/49 formatting rule tests pass (up from 48 — new fixture verification entry auto-discovered).
- 24/24 integrity tests pass (tier coverage, tier integrity, no duplicates).
- Scan CLI compiles and shows `--fix-ignores` in `--help` output.
