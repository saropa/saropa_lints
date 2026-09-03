# PROPOSAL: Newline Before Pubspec Entry

**Status: Open**

Created: 2026-09-02

## Summary

Flags a missing blank line between two top-level sections of `pubspec.yaml` (e.g. `dependencies:` immediately followed by `dev_dependencies:` with no separating blank line).

## Motivation

`pubspec.yaml` has no enforced formatter (unlike `.dart` files, which `dart format` normalizes), so section spacing drifts freely across a codebase and between contributors. A pubspec where every top-level section is visually separated is faster to scan when hunting for `dev_dependencies:` vs `dependencies:` vs `flutter:` — cramming sections together is a small but constant readability tax on a file every contributor opens.

## Detection / Behavior

Fires when a top-level (column-0) key in `pubspec.yaml` is immediately preceded by a non-blank line that is itself part of a different top-level section (i.e. the previous line is not blank and not a continuation/comment belonging to the same section).

**BAD:**
```yaml
dependencies:
  http: ^1.0.0
dev_dependencies:
  lints: ^4.0.0
```

**GOOD:**
```yaml
dependencies:
  http: ^1.0.0

dev_dependencies:
  lints: ^4.0.0
```

## Quick Fix

Insert a single blank line before the offending top-level key.

## Alternatives Considered

Could also enforce exactly one blank line (flagging two-or-more as well, to standardize spacing tightly). Scoped down to "at least one" for the initial proposal — flagging excess blank lines is a separate, lower-value concern (`prefer_no_multiple_blank_lines`-style) that would double the false-positive surface for comment-separated sections without adding much readability benefit.

## Existing Coverage

None found. No rule in `lib/src/rules/config/` reasons about blank-line spacing within `pubspec.yaml`; the closest analog, `newline_before_return`-style Dart-formatting rules, operates on the Dart AST via `dart format` conventions and has no YAML counterpart. This would need a new line-based scanner similar in shape to `SortPubDependenciesRule`'s `_hasSortingIssue` (read pubspec.yaml, walk lines, look for column-0 keys), reusing the existing `_reportPubspecOnce`-style "attach to top of a `lib/` Dart file, once per root" reporting pattern.
