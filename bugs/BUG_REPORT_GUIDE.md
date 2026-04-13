# Bug Report Guide

How to file, investigate, and close bugs in `saropa_lints`.

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
| String matching for types | `name.contains('Stream')` matches `upstream` | Use `staticType?.isDartAsyncStream` |
| Unsafe parent cast | `node.parent as MethodDeclaration` crashes if parent is different | `if (node.parent is MethodDeclaration)` |
| Missing AST node in parent walk | Loop skips `AssignmentExpression` inside `IfStatement` | Handle all intermediate node types or don't break on unknown |
| Checking `node.name` instead of resolved element | Misses renamed imports, typedefs, extensions | Use `node.staticElement` or `node.staticType` |
| Quick fix targets wrong `sourceRange` | Fix replaces more or less code than intended | Verify the exact `offset` and `length` of the range |
| Rule fires on generated code | `.g.dart`, `.freezed.dart` files trigger false positives | Check `resolver.path` for generated file suffixes |
| Rule fires inside test files | Test code intentionally violates patterns | Check with `ProjectContext.isTestFile` if rule should skip tests |
| `// ignore:` on wrong line | Ignore comment is on the field but diagnostic is on `.listen()` | Report on the node that users expect to annotate |

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
- Reference related history: `Related: plan/history/YYYY.MM/YYYYMMDD/filename.md`
