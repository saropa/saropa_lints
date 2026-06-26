# Bug Report Guide

How to file, investigate, and close bugs in `saropa_lints`.

**False positives are in scope.** If a rule flags code that is correct (or the diagnostic is clearly wrong), file it here under `bugs/` using the [False positive](#false-positive) naming pattern and the [template below](#bug-report-template)—not only in a downstream app’s chat or issue tracker. Downstream repos can link to the bug file once filed; the fix and fixture live in `saropa_lints`.

## Raised Reports (2026-04-29)

- `avoid_inert_animation_value_in_build_false_positive_animatedbuilder_child_reads.md`
- `avoid_redundant_await_false_positive_animationcontroller_forward_reverse.md`
- `avoid_unassigned_late_fields_false_positive_parent_data_render_object.md`
- `avoid_memory_intensive_operations_false_positive_non_string_loop_math.md`
- `avoid_unsafe_cast_false_positive_render_object_parent_data_cast.md`

## Raised Reports (2026-06-11)

- `require_cache_expiration_false_positive_bounded_lru_lfu_cache.md`
- `require_timezone_display_false_positive_rendering_primitive_and_pattern_introspection.md`

## Raised Reports (2026-06-12)

- `feature_lint_rule_prefer_us_english_spelling.md`
- `infra_us_spelling_dictionary_coverage_gaps.md`

## Raised Reports (2026-06-13)

- `prefer_layout_builder_for_constraints_false_positive_mediaquery_fallback_and_viewport_fraction.md`
- `prefer_no_commented_out_code_false_positive_prose_sentence_with_inline_call_example.md`
- `prefer_setup_teardown_false_positive_per_test_parameterized_sut_construction.md`

## Raised Reports (2026-06-18)

- `infra_drift_advisor_integration_duplicate_diagnostics_with_standalone_extension.md`

## Raised Reports (2026-06-19)

- `feature_lint_group_ui_excellence.md`

## Raised Reports (2026-06-23)

- `feature_lint_rule_prefer_static_final_for_session_constant.md`

## Raised Reports (2026-06-24)

- `infra_shrinkwrap_rule_overlap_four_rules_one_concern.md`
- `prefer_boolean_prefixes_false_positive_serialization_bound_field_names.md`
- `feature_lint_rule_require_named_for_acronym_drift_columns.md`

## Raised Reports (2026-06-25)

- `feature_lint_rule_avoid_animated_size_in_wrap.md`

## Raised Reports (2026-06-26)

- `avoid_hardcoded_api_urls_false_positive_url_already_extracted_to_config_constant.md`

---

## File Naming

| Type | Pattern | Example |
|------|---------|---------|
| False positive | `rule_name_false_positive_description.md` | `avoid_stream_subscription_in_field_false_positive_conditional_listen.md` |
| False negative | `rule_name_false_negative_description.md` | `no_hardcoded_secrets_false_negative_base64_literals.md` |
| Crash / error | `rule_name_crash_description.md` | `prefer_const_widgets_crash_generic_type_arg.md` |
| Quick fix bug | `rule_name_fix_description.md` | `prefer_final_locals_fix_applies_to_loop_variable.md` |
| Infrastructure | `infra_description.md` | `infra_tiers_mismatch_plugin_registry.md` |

Use lowercase with underscores. Check existing files before creating.

---

## Confirm Attribution Before Filing

**Before filing a bug here, grep to prove the rule lives in `saropa_lints`.** A diagnostic's `source` / `owner` label in the VS Code Problems panel is not attribution — it is a label the emitter chose. Sibling analyzer plugins and extensions (`drift-advisor`, `drift-linter`, `Saropa Drift Advisor`, other `custom_lint`-based plugins, etc.) emit diagnostics that can look similar to `saropa_lints` rules or carry similar-looking code names. Filing here without proof forces the first fix agent to waste a round-trip discovering the bug lives elsewhere — or worse, the agent guesses and ships a half-fix in the wrong repo.

### Positive attribution (required)

For every rule name mentioned in the report, paste the result of:

```bash
grep -rn "'<rule_name>'" lib/src/rules/
```

Expected match: the rule is defined in `lib/src/rules/<category>/<file>.dart` (e.g., `lib/src/rules/packages/drift_rules.dart`) and registered in `lib/src/rules/all_rules.dart`. **Zero matches means the rule does not live in `saropa_lints`** — do not file here.

### Negative attribution (required when multiple sources may overlap)

If the diagnostic's `source` / `owner` label is ambiguous (`drift-advisor`, `Saropa Drift Advisor`, `saropa-lints`, `saropa_lints` — they all look similar to a downstream reader), also grep the suspected sibling repos to confirm the rule is NOT defined there:

```bash
grep -rn "'<rule_name>'" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
```

Paste the zero-match result. If you get a match, file the bug in that repo instead.

### Reverse case: diagnostics whose emitter is not here

If the report is about a diagnostic whose label resembles `saropa_lints` but the positive grep returns nothing, **stop**. The emitter lives in another plugin or extension. Name the suspected emitter, paste the positive grep from that repo, and file the bug in that repo's `bugs/` folder. Do not open a bug here on the theory that "saropa_lints probably registers it somehow" — that guess has cost us real round-trips.

### Why this section exists

We have had bugs misattributed in both directions — `saropa_lints` rules filed against `saropa_drift_advisor` and `drift_advisor` diagnostics filed against `saropa_lints`. In every case, the fix agent saw a label, assumed a repo, and either punted the work as "somebody else's" or shipped a fix in the wrong tree. The only defense is grep evidence pasted directly in the bug report.

---

## Bug Report Template

Copy the block below into a new file.

````markdown
# BUG: `rule_name` — Short, Specific Title

**Status: Open**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: YYYY-MM-DD
Rule: `rule_name`
File: `lib/src/rules/category/xxx_rules.dart` (line ~NNN)
Severity: False positive / False negative / Crash / Wrong fix / Performance
Rule version: vN | Since: vX.Y.Z | Updated: vX.Y.Z

---

## Summary

One or two sentences: what happens, what should happen instead.

---

## Attribution Evidence

Grep proof that this rule lives in `saropa_lints`. If the positive grep is empty, the bug does not belong in this repo — do not file here. See "Confirm Attribution Before Filing" in the guide.

```bash
# Positive — rule IS defined here
grep -rn "'rule_name'" lib/src/rules/
# Expected: lib/src/rules/<category>/<file>.dart:NN: ... 'rule_name' ...

# Negative — rule is NOT in sibling repos (paste only if source label is ambiguous across projects)
grep -rn "'rule_name'" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# Expected: 0 matches
```

**Emitter registration:** `lib/src/rules/<category>/<file>.dart:NN`
**Rule class:** `XxxRule` — registered in `lib/src/rules/all_rules.dart:NN`
**Diagnostic `source` / `owner` as seen in Problems panel:** `...`

---

## Reproducer

Minimal Dart code that triggers the bug. This is the single most important section.

```dart
// Paste the smallest code that reproduces the issue.
// Mark expected behavior with comments.
class Example {
  void method() {
    final x = something; // LINT — but should NOT lint (false positive)
    // or: missing lint here (false negative)
  }
}
```

**Frequency:** Always / Only with specific patterns / Intermittent

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic (code is correct) |
| **Actual** | `[rule_name] Problem message text` reported at line N |

---

## AST Context

<!-- Show the AST parent chain from the flagged node to the enclosing declaration.
     Use `dart analyze` verbose output or manual inspection. -->

```
ClassDeclaration (Example)
  └─ MethodDeclaration (method)
      └─ Block
          └─ VariableDeclarationStatement
              └─ VariableDeclaration (x)
                  └─ MethodInvocation (.something)  ← node reported here
```

---

## Root Cause

<!-- Fill in during investigation. Explain the *mechanism*: which condition
     in the rule logic evaluates wrong, and why. Reference specific lines. -->

### Hypothesis A: ...

Explain the theory and what to check.

### Hypothesis B: ...

---

## Suggested Fix

<!-- Describe the code change needed. Reference line numbers in the rule file. -->

---

## Fixture Gap

<!-- What test cases are missing from the rule's fixture file? -->

The fixture at `example*/lib/category/rule_name_fixture.dart` should include:

1. **Case description** — expect LINT / expect NO lint
2. ...

---

## Changes Made

<!-- Fill in when a fix is written. -->

### File 1: `lib/src/rules/category/xxx_rules.dart` (line NN)

**Before:**
```dart
old code
```

**After:**
```dart
new code
```

---

## Tests Added

<!-- List new or updated fixture/test files and what they verify. -->

---

## Commits

<!-- Add commit hashes as fixes land. -->
- `abcdef0` fix: description

---

## Environment

- saropa_lints version:
- Dart SDK version:
- custom_lint version:
- Triggering project/file:
````

---

## What Makes a Good Bug Report

### Title

- Start with the rule name in backticks: `` `rule_name` ``
- Classify the bug type: "false positive", "false negative", "crash", "wrong fix"
- Be specific: "fires inside `Stream.multi` callback" beats "wrong behavior"

### Reproducer

- **Smallest possible code** that triggers the bug — strip everything unrelated
- Mark expected behavior: `// LINT` where a diagnostic should appear, `// OK` where it should not
- If the bug only triggers with specific context (inside `initState`, inside a `for` loop, with generics), include that context
- If the bug comes from a real codebase, anonymize it but preserve the structure that matters

### AST Context

- Show the parent chain from the flagged node up to the enclosing class/function
- This is what the rule's `context.registry` callback actually walks — it determines whether the detection logic matches
- Highlight which node the rule reports on vs which node you expect it to evaluate

### Root Cause

- Explain the **mechanism**: which `if` branch in the rule evaluates wrong, and why
- Reference specific line numbers in the rule source file
- If the parent walk skips a node, say which node type is not handled
- If a type check fails, say what `staticType` resolves to and why it does not match

---

## Bug Categories

### False Positive

The rule fires on correct code.

**How to report:** Create `bugs/rule_name_false_positive_<short_description>.md`, copy the [Bug Report Template](#bug-report-template), and complete **Reproducer** (minimal snippet) plus **Attribution Evidence** (grep). Severity is usually **High** if teams must add `// ignore:` workarounds on common patterns.

**Investigation focus:**
- What pattern does the rule fail to recognize as valid?
- Which condition in the detection logic is too broad?
- Does the rule handle all AST node types that can appear in this position?

### False Negative

The rule misses code it should flag.

**Investigation focus:**
- Is the rule registered for the right AST node type?
- Does the condition have an early return that excludes this case?
- Is the violation pattern structurally different from what the rule checks?

### Crash / Exception

The rule throws during analysis.

**Investigation focus:**
- Include the full stack trace
- Which node property is null that the rule assumes is non-null?
- Does the rule cast without checking (`as` instead of `is`)?

### Wrong Quick Fix

The fix applies incorrectly or produces broken code.

**Investigation focus:**
- Show the code before and after the fix is applied
- Does the fix account for imports, whitespace, surrounding context?
- Does `sourceRange` target the right span?

### Performance

A rule causes analysis to hang or take unreasonably long.

**Investigation focus:**
- Which file or pattern triggers the slowdown?
- Is the rule doing full-AST traversal instead of using a specific registry method?
- Is there an O(n^2) loop or repeated type resolution?

---

## Investigation Checklist

Use this when diagnosing a new bug.

- [ ] **Positive attribution grep** — `grep -rn "'rule_name'" lib/src/rules/` returns at least one match, pasted in the report. Zero matches = do not file here
- [ ] **Negative attribution grep** — if the diagnostic's `source` / `owner` label is ambiguous across sibling repos (`drift-advisor`, `Saropa Drift Advisor`, etc.), paste the zero-match grep from each suspected sibling repo
- [ ] **Reproduce it** — create a minimal Dart snippet that triggers the behavior
- [ ] **Check registration** — is the rule in `all_rules.dart` and `tiers.dart`?
- [ ] **Read the rule source** — find the `run()` method and trace the logic
- [ ] **Identify the AST node** — what does `context.registry.addXxx` register? Is it the right visitor?
- [ ] **Walk the parent chain** — from the flagged node, what does `node.parent` resolve to at each step?
- [ ] **Check type resolution** — does `node.staticType` / `element.type` resolve as expected?
- [ ] **Check null safety** — does the rule handle nullable properties without crashing?
- [ ] **Check the fixture** — does the existing fixture cover this pattern? If not, that is the fixture gap
- [ ] **Run the test** — `dart test test/rule_name_test.dart` to confirm current behavior

---

## Common Pitfalls

These patterns have caused bugs before. Check for them during investigation.

| Pitfall | Why It Breaks | Correct Pattern |
|---------|---------------|-----------------|
| Attributing a diagnostic by its label | `source: "drift-advisor"` does not mean "defined in `drift_advisor` repo" — it is a label the emitter chose | Grep the rule name in every plausible repo; attribution is `file:line`, not a label |
| Filing here without positive grep | Wastes a fix agent's round-trip when the rule actually lives in a sibling plugin | `grep -rn "'rule_name'" lib/src/rules/` must return at least one match before filing |
| String matching for types | `name.contains('Stream')` matches `upstream` | Use `staticType?.isDartAsyncStream` |
| Unsafe parent cast | `node.parent as MethodDeclaration` crashes if parent is different | `if (node.parent is MethodDeclaration)` |
| Missing AST node in parent walk | Loop skips `AssignmentExpression` inside `IfStatement` | Handle all intermediate node types or don't break on unknown |
| Checking `node.name` instead of resolved element | Misses renamed imports, typedefs, extensions | Use `node.staticElement` or `node.staticType` |
| Quick fix targets wrong `sourceRange` | Fix replaces more or less code than intended | Verify the exact `offset` and `length` of the range |
| Rule fires on generated code | `.g.dart`, `.freezed.dart` files trigger false positives | Check `resolver.path` for generated file suffixes |
| Rule fires inside test files | Test code intentionally violates patterns | Check with `ProjectContext.isTestFile` if rule should skip tests |
| `// ignore:` on wrong line | Ignore comment is on the field but diagnostic is on `.listen()` | Report on the node that users expect to annotate |
| Wrong line / column in Problems panel | After edits, the IDE can show a diagnostic on a stale line (e.g. doc comment or blank line) while the real node moved; `avoid_void_async` can appear offset from the actual `async` | Restart the Dart Analysis Server; confirm with `dart analyze` on the file; paste **both** the reported line:column and the actual offending snippet in the bug |
| `// ignore:` ignored for a `saropa_lints` rule | Analyzer ignores use the registered rule id; a mismatch silences nothing | Try `// ignore: saropa_lints/<rule_name> -- reason` on the line **immediately above** the violation (same pattern as analyzer `// ignore: name`); if still ignored, file a false positive—suppression wiring may be wrong |
| `read_lints` vs `dart analyze` disagree | Editor plugin cache or partial workspace analysis | Prefer `dart analyze` (or CI) as ground truth for the bug report; note IDE + plugin versions under **Environment** |

---

## Fix Requirements

Every bug fix must satisfy these before it can be closed.

### Code

- [ ] Fix addresses the **root cause**, not just the symptom
- [ ] Fix includes a comment explaining what was wrong and why the new code is correct
- [ ] Functions stay ≤50 lines, ≤3 parameters, ≤3 levels of nesting
- [ ] No `// ignore:` comments added to suppress diagnostics

### Tests

- [ ] Fixture updated with the exact reproduction case
- [ ] Violation lines marked with `// LINT`, compliant lines with `// OK` comments
- [ ] Unit test verifies the fix (detection count, fix output)
- [ ] Existing tests still pass: `dart test`

### Quality Gates

- [ ] `dart analyze --fatal-infos` — zero issues
- [ ] `dart format` — no changes needed
- [ ] `dart test` — all tests pass

### Documentation

- [ ] `CHANGELOG.md` updated under `[Unreleased]` → `### Fixed`
- [ ] `ROADMAP.md` updated if rule status changed
- [ ] Bug report file updated with root cause, changes, and commit hashes
- [ ] Status updated to `Closed`

---

## Lifecycle

```
Open
  │
  ▼
Investigating       ← actively diagnosing, root cause section being filled in
  │
  ▼
Fix Ready           ← code written, tests pass, awaiting commit
  │
  ▼
Closed              ← merged, verified, file moved to history
```

### Moving to History

When a bug is closed, move its file:

```
bugs/rule_name_false_positive_description.md
  → bugs/history/YYYYMMDD/rule_name_false_positive_description.md
```

Use the date the bug was closed. Create the date folder if it does not exist.

---

## Severity Guide

| Severity | Meaning | Examples |
|----------|---------|---------|
| Critical | Rule crashes analyzer, blocks all analysis | Null dereference in `run()`, infinite loop |
| High | False positive on common pattern, forces `// ignore:` workaround | Fires on standard `dispose()` pattern, flags valid `const` |
| Medium | False negative on important violation | Misses hardcoded secret in interpolation, skips nested callback |
| Low | Cosmetic or edge case | Wrong correction message text, fires on obscure syntax |

---

## Linking

- Reference bugs from commits: `fix: description (rule_name false positive)`
- Reference bugs from ROADMAP: `[bug file](bugs/rule_name_false_positive_description.md)`
- Reference related history: `Related: plans/history/YYYY.MM/YYYYMMDD/filename.md`

---

## Policy Note

Do not log project-specific bug findings directly in this guide again.

- This file is process documentation only.
- Every concrete issue must live in a separate bug file under `bugs/` using the naming rules above.
- If you discover this happened again, move the content into dedicated bug files immediately and leave only this policy note.

