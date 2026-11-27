# `dart analyze <parent folder>` reports plugin findings for only one of two packages

Status: open. Observed 2026-11-27 (accepted-findings checklist, step 32). Not fixed; cause unverified.

## Setup

`D:\tmp\accepted_check\live\` holds two packages, `one` and `two`. Neither the parent folder has a `pubspec.yaml` nor an `analysis_options.yaml`. Both packages turn on the plugin from `D:/src/saropa_lints` with `avoid_catch_all` and `avoid_print_error`, and both have the same `lib\g.dart`.

- `one`: `saropa_accepted.yaml` accepts `avoid_catch_all` with `max: 1`.
- `two`: `analysis_options_custom.yaml` names `saropa_baseline.json`, which hides `avoid_print_error`.

## Observed

`dart analyze D:\tmp\accepted_check\live` (exit 2): `3 issues found.`, all in `one\`:

- `one\lib\g.dart:6` `avoid_print_error`
- `one\lib\g.dart:13` `avoid_catch_all`
- `one\lib\g.dart:14` `avoid_print_error`

`dart analyze D:\tmp\accepted_check\live\two` (exit 2): `2 issues found.`, `avoid_catch_all` on lines 5 and 13.

## Expected

5 issues from the parent-folder run: the 3 above plus the 2 in `two`.

## Unverified

- Whether the order of the two packages changes which one is reported.
- Whether the Dart analysis server or saropa_lints drops the findings.
- Whether the live editor (step 30) shows the same gap.
