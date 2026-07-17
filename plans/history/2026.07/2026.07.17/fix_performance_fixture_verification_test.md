# Fix Performance Fixture Verification Test

The performance rules test's fixture-existence verification loop had two defects: one fixture file was named with a `_desktop` suffix that broke the naming convention (`require_window_close_confirmation_desktop_fixture.dart` vs the expected `require_window_close_confirmation_fixture.dart`), and eight fixture files that existed on disk were missing from the verification list, so their existence was never asserted.

## Finish Report (2026-07-17)

### Changes

- **Fixture rename:** `require_window_close_confirmation_desktop_fixture.dart` → `require_window_close_confirmation_fixture.dart` to match the `{rule_name}_fixture.dart` convention used by all other performance fixtures and enforced by the test loop.
- **8 missing entries added to the fixture verification list:** `avoid_backdrop_filter_in_scrollable`, `avoid_cache_stampede`, `avoid_clip_path_in_animated_builder`, `avoid_image_filter_in_scrollable`, `avoid_opacity_in_animated_builder`, `avoid_opacity_in_scrollable`, `avoid_shader_mask_in_scrollable`, `prefer_static_final_for_session_constant`. All eight files already existed on disk but were never included in the test's fixture list.

### Verification

`dart test test/rules/core/performance_rules_test.dart` — 107 tests passed (0 failures).
