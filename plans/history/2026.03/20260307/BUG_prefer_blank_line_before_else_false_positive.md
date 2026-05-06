# Bug: `prefer_blank_line_before_else` false positive on `else if` chains

**Status:** Fixed (v2)
**Rule:** `prefer_blank_line_before_else` (v1)
**Severity:** False positive — flags valid code that should not trigger
**Plugin version:** saropa_lints v8.0.7 (professional tier)

## Problem

The rule flags `} else if (...)` as needing a blank line before the `else if`, even though:

1. Dart syntax requires `} else if` to be contiguous — inserting a blank line between `}` and `else if` is a syntax error.
2. The rule's intent (separating branches for readability) makes sense for standalone `} else {` blocks but not for `else if` chains, which are logically a single multi-branch construct.

## Reproduction

**File:** `lib/main.dart`, line 161

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.paused ||
      state == AppLifecycleState.inactive) {
    SoundService.instance.stopAmbient();
  } else if (state == AppLifecycleState.resumed) {
    SoundService.instance.startAmbient();
    LaunchActionService.instance.refreshLaunchShortcut();
  }
}
```

**Diagnostic output:**

```
[prefer_blank_line_before_else] Adding a blank line before else/else if
separates branches and improves readability. Enable via the stylistic tier. {v1}
Add a blank line before this else clause.
```

## Why this is wrong

1. **`else if` chains are a single control-flow construct.** An `if / else if / else if / else` ladder is one logical decision tree, not independent blocks. Adding blank lines between each branch breaks the visual grouping and makes it harder to see the chain as a unit.

2. **A blank line before `else if` is a syntax error.** Dart requires the `else` keyword to immediately follow the closing `}` of the preceding `if` body (on the same line or the next). Inserting a blank line would cause a compile error:

```dart
  // This does NOT compile:
  if (x) {
    ...
  }

  else if (y) {  // ERROR: unexpected 'else'
    ...
  }
```

3. **The rule should only target standalone `else` blocks.** A blank line before a final `} else {` (where the `else` body is a distinct code path, not another condition) is a defensible style choice. But `else if` is syntactically and semantically different.

## Expected behavior

The rule should NOT fire when:

- The `else` is followed by `if` (i.e., `} else if (...)`)
- The construct is part of an `if / else if` chain

The rule SHOULD fire (if enabled) only when:

- The `else` is a standalone final branch: `} else {`

## Impact

Every `else if` in the project generates a false positive. This is an extremely common construct — most Flutter apps have dozens of `if / else if` chains (lifecycle handlers, theme checks, platform checks, etc.), making this rule very noisy.

## Resolution

**Fix:** Added `if (elseStmt is IfStatement) return;` guard in `NewlineBeforeElseRule.runWithReporter()`. When the `elseStatement` is itself an `IfStatement` (i.e., `else if`), the rule now skips it. Only standalone `} else {` blocks are reported. Problem message updated to v2, docs and fixture updated to match.
