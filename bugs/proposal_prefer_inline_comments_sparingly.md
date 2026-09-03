# PROPOSAL: Prefer Inline Comments Sparingly

**Status: Open**

Created: 2026-09-02

## Summary

Flags dense trailing `//` comments stacked on consecutive lines that should be consolidated into one block comment placed above the code they describe.

## Existing Coverage

`RequireComplexLogicCommentsRule` (`lib/src/rules/core/documentation_rules.dart`) enforces the opposite direction — requiring a comment exist for complex logic. It does not check comment *density* or *placement*; this rule targets over-fragmented trailing comments, not their absence.

## Motivation

A trailing `//` comment on every one of several consecutive statements fragments a single explanation across many lines, makes diffs noisy (comment text changes or shifts on every touched line even when the underlying reasoning is unchanged), and is harder to read as one coherent unit of intent than a single block comment above the code. This project's own CLAUDE.md mandates dense WHY comments — this rule keeps that density readable instead of noisy.

## Detection / Behavior

Fires when N or more consecutive statements each carry a trailing `//` comment (default threshold: 3), suggesting the comments describe one overall intent that belongs above the block.

#### BAD:
```dart
final x = a + b; // add a and b
final y = x * 2; // double it
final z = y - 1; // subtract one for the offset
```

#### GOOD:
```dart
// Compute the offset-adjusted doubled sum: (a + b) * 2 - 1.
final x = a + b;
final y = x * 2;
final z = y - 1;
```

## Quick Fix

Merge the consecutive trailing comments into a single block comment inserted above the first statement, concatenating their text in order.

## Alternatives Considered

Flagging any 2 consecutive trailing comments was considered too aggressive and rejected — settled on a configurable threshold (default 3) so short per-line annotations stay allowed. Scoping to `///` doc comments only was rejected since the pattern mostly appears in ordinary `//` implementation comments.
