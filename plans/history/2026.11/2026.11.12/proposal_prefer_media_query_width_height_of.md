# Proposal: flag `MediaQuery.sizeOf(context).width` / `.height` (GitHub #406)

Source: https://github.com/saropa/saropa_lints/issues/406 (requested name `avoid_unnecessary_listening_ofcontext`, tier Comprehensive).

## Request

When code reads only the width or height, use `MediaQuery.widthOf(context)` / `heightOf(context)` instead of `MediaQuery.sizeOf(context).width` (or `MediaQuery.of(context).size.width`). The narrower call rebuilds the widget only when that one dimension changes.

## Review (2026-11-12)

Verdict: valid, small, worth doing.

Evidence:
- Flutter added `widthOf`, `heightOf`, `maybeWidthOf`, `maybeHeightOf` in PR #167829 (2025-05-06), first stable release 3.35.0. Local SDK: `~/flutter/packages/flutter/lib/src/widgets/media_query.dart:1680-1712`.
- The existing rule `prefer_dedicated_media_query_method` (`lib/src/rules/code_quality/code_quality_prefer_rules.dart`, around line 92) already flags `MediaQuery.of(context).size` and suggests `sizeOf`. Nothing flags `sizeOf(context).width`. `MediaQuery.of(context).size.width` is today fixed to `sizeOf(context).width`, one step short.
- The repo has no Flutter-version gate for rules. Projects on Flutter older than 3.35 have no `widthOf`, so the rule must check, through type resolution, that the resolved `MediaQuery` class declares `widthOf` before reporting. Otherwise it would suggest an API that does not compile.

Risk: low. Pure syntax match plus one element lookup. Only false-positive risk is the old-SDK case above.

The requested name is unclear ("ofcontext"). Suggested name: `prefer_media_query_width_height_of`.

Scope of the rule (proposed):
- Flag `MediaQuery.sizeOf(context).width|height` and `MediaQuery.maybeSizeOf(context)?.width|height`.
- Flag `MediaQuery.of(context).size.width|height` with the same message (the `of(...).size` part is also flagged by the existing rule; both fixes lead to the same end state).
- Do not flag when both width and height are read in the same scope from one `sizeOf` result, since `sizeOf` is then correct.
- Quick fix: rewrite to `widthOf` / `heightOf` (and `maybe` forms).

## Owner decision

2026-11-12: new rule `prefer_media_query_width_height_of`, Comprehensive tier, with quick fix; silent when the resolved `MediaQuery` has no `widthOf`. (Recommended option; chosen over extending `prefer_dedicated_media_query_method` so current users see no behavior change.)

## Implementation (2026-11-12)

Implemented as `PreferMediaQueryWidthHeightOfRule` in `lib/src/rules/code_quality/code_quality_prefer_rules.dart`, fix in `lib/src/fixes/code_quality/prefer_media_query_width_height_of_fix.dart`. Comprehensive tier, INFO. Reports only the direct `sizeOf(...).width|height`, `maybeSizeOf(...)?.width|height` and `of(...).size.width|height` chains, and only when the resolved `MediaQuery` class declares `widthOf`. A stored `sizeOf` result is not flagged. Fixture: `example/lib/code_quality/prefer_media_query_width_height_of_fixture.dart` (the example mock `MediaQuery` gained `sizeOf`/`widthOf` members). Generated registry files were patched with only this rule (full regeneration also pulls in unrelated drift from other rules). Status: implemented.

## Follow-up decision (2026-11-12)

Generated lists (rule category map, rule pack codes, extension pack and tier definitions) miss entries for many existing rules. Owner chose: after this rule merges, regenerate them on main in a separate commit (recommended option).

## Scope notes (2026-11-12)

`maybeOf(c)?.size.width` and `maybeOf(c)!.size.width` are out of scope for now. The `?.` chain case (for example `maybeSizeOf(c)?.width.toInt()`) is skipped on purpose, because the rewrite to `maybeWidthOf(c)` leaves a nullable receiver and would not compile.
