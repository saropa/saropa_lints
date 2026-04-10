# Resolved: `prefer_single_blank_line_max` false positives

**Status:** Fixed in v8.0.9 (rule v3)

## Problem

The v2 rule compared top-level declaration positions (`nextLine - currentLine > 2`) which counted ALL lines between declarations — comments, doc comments, section separators — as blank lines. This caused false positives on every file with comments between declarations. The rule also only checked between top-level declarations, missing consecutive blank lines inside function bodies.

## Fix

Rewrote detection to scan actual line content. Only lines whose trimmed content is empty are counted as blank lines. Now scans the entire file, detecting consecutive blank lines everywhere.
