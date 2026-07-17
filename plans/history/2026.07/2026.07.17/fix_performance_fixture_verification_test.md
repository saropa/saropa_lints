# Fix Performance Fixture Verification Test

The performance rules test's fixture-existence verification loop had two defects: one fixture file was named with a `_desktop` suffix that broke the naming convention (`require_window_close_confirmation_desktop_fixture.dart` vs the expected `require_window_close_confirmation_fixture.dart`), and eight fixture files that existed on disk were missing from the verification list, so their existence was never asserted.

## Finish Report (2026-07-17)

### Changes

- **Fixture rename:** `require_window_close_confirmation_desktop_fixture.dart` → `require_window_close_confirmation_fixture.dart` to match the `{rule_name}_fixture.dart` convention used by all other performance fixtures and enforced by the test loop.
- **8 missing entries added to the fixture verification list:** `avoid_backdrop_filter_in_scrollable`, `avoid_cache_stampede`, `avoid_clip_path_in_animated_builder`, `avoid_image_filter_in_scrollable`, `avoid_opacity_in_animated_builder`, `avoid_opacity_in_scrollable`, `avoid_shader_mask_in_scrollable`, `prefer_static_final_for_session_constant`. All eight files already existed on disk but were never included in the test's fixture list.

### Verification

`dart test test/rules/core/performance_rules_test.dart` — 107 tests passed (0 failures).

## Finish Report — Phase 2 (2026-07-17)

### Problem

The phase-1 fix added the 8 missing fixture names to a hardcoded list, but the list itself was the root vulnerability: every new fixture file required a manual list update, and omissions silently passed (the `for` loop ran zero iterations for missing entries). The same pattern exists in 128 other test files across the project.

Additionally, the handoff reflection flagged a stale `_desktop` suffix on `require_window_close_confirmation_desktop_good.dart` — the rule name `require_window_close_confirmation` has no `_desktop` segment (unlike `require_menu_bar_for_desktop`, which does).

### Changes

- **Auto-discovery replaces hardcoded list:** The 57-entry fixture name list in `performance_rules_test.dart` was replaced with a `Directory.listSync()` scan filtered to `*_fixture.dart`. New fixture files are now verified automatically with no manual maintenance.
- **Guard test added:** A `fixture directory exists and is not empty` test catches a missing or empty `example/lib/performance/` directory before the per-file loop silently passes on zero iterations.
- **Stale good-example rename:** `require_window_close_confirmation_desktop_good.dart` → `require_window_close_confirmation_good.dart`. The cross-reference comment in the fixture file was updated to match.
- **CHANGELOG:** Maintenance entry added.

### Verification

`dart test test/rules/core/performance_rules_test.dart` — 108 tests passed (0 failures). The extra test is the new directory guard.

### Scope limitation

128 other test files use the same hardcoded fixture list pattern and remain vulnerable to the same drift. Converting them is a mechanical but large change (129 files total) and was not requested.
