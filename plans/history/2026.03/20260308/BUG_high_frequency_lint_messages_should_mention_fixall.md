# Feature Request: High-frequency lint messages should mention VS Code `source.fixAll` auto-fix

**Status: RESOLVED**

## Summary

Updated correction messages for `prefer_trailing_comma_always` and `prefer_type_over_var` to mention `source.fixAll` editor setting. Also implemented missing quick fixes for both rules so the tip is actionable.

## Changes Made

1. **`prefer_trailing_comma_always`** — Added `source.fixAll` tip to correction message. Wired existing `AddTrailingCommaFix` as quick fix.
2. **`prefer_type_over_var`** — Replaced alarming "Verify the change works correctly with existing tests" text with `source.fixAll` tip. Created new `ReplaceVarWithTypeFix` that replaces `var` with the inferred type.
3. **Tests** — Added fix-availability and message-content tests for both rules.
4. **pubspec.yaml** — Incremented quick fix count from 131 to 132.
