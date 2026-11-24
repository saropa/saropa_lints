# False-positive sweep for 17.8.0

Twenty-two reported false positives were triaged. Seventeen were fixed in rule logic or the VS Code LSP launcher; five were closed as not-a-saropa-bug, by design, or not reproducible.

## Finish Report (2026-11-24)

### Fixed (17 reports)

- `avoid_change_notifier_in_widget`: `field ??= Notifier()` on a class field is cached, not re-created per build.
- `avoid_ios_hardcoded_status_bar`: `SizedBox` that is a list-literal element is spacing.
- `avoid_keyboard_overlap`: skipped when no Scaffold is in `build()` itself. Helper methods keep reporting (review fix).
- `avoid_undisposed_instances`: for-in loop over a list literal that disposes the loop variable credits each element.
- `prefer_abstraction_injection`: function-typed (`Dio Function()?`) parameters are skipped.
- `prefer_number_format`: `DateTime` day/hour/minute/second/millisecond/microsecond/month/weekday skipped; `year` still reports. Bounded-slider and small-`.length` cases are not detectable in the AST and remain.
- `prefer_positioned_directional`: `left`/`right` containing `.dx`/`.dy` skipped (regex heuristic on source text).
- `prefer_scalable_text`: reports only `Text`/`RichText` that disable scaling.
- `prefer_skeleton_over_spinner`: indicator in `icon:`/`child:`/`label:` of a `*Button` skipped.
- `prefer_static_method`: non-static field reads count as instance state; the unresolved-identifier fallback matches by name and can over-suppress on shadowing locals or property names.
- `require_copy_with_null_handling`: `??` guarded by a clear flag (`no|clear|remove|reset|unset|null` + param) skipped.
- `require_hover_states`, `prefer_cursor_for_buttons`, `require_focus_indicator`: only `GestureDetector` reported; `InkWell`/`InkResponse` skipped.
- `require_ios_multitasking_support`: skipped when the project has no `ios/` directory (`ProjectContext.hasIosPlatform`).
- `require_semantic_label_icons`: decorative icon beside a text label skipped.
- `require_text_overflow_handling`: `Text` in ListTile-family title/subtitle and `Expanded`/`Flexible` child skipped.
- Mobile tile / non-scrolling list report: eight rules (hover, focus, cursor, refresh indicator, scroll controller, intrinsic dimensions, gesture behavior, refresh-on-lists) via the shared helper `lib/src/widget_ancestor_utils.dart`.
- VS Code LSP server: launches with the workspace-pinned SDK (`dart.sdkPath`, `dart.flutterSdkPath`, `.fvm/flutter_sdk`, PATH) and `--no-pub`.

### Closed without code change (5)

- `deprecated_member_use`, `unused_result`: Dart SDK diagnostics, not emitted by saropa_lints.
- `text_field_form_rules`: the six rules match `TextField`/`TextFormField` by exact name; not reproducible by code reading.
- `require_webview_ssl_error_handling`: the callback is already accepted; reporter's 4.15.1 predates it.
- `require_disabled_state`: by design; the reported code is the rule's documented bad example.

### Tooling

- `scripts/checks/check_report_attribution.py` proves a diagnostic is a saropa_lints rule; `bugs/ISSUE_REPORT_GUIDE.md` routes SDK diagnostics upstream.

### Verification

- Scoped `dart test` over all touched suites: 681 passed (pre-review), 76 passed after review fixes.
- Behavior-level coverage exists for semantic-label, copy-with, change-notifier, undisposed, abstraction-injection, number-format, text-overflow and mobile-tile fixes. The others have fixture-text tests only.
- Extension LSP change: both typechecks and 11/11 mocha pass; not observed in an Extension Development Host.

### Review findings left open

- `extension/src/extension.ts` / `analysisToastProgress.ts` (concurrent, unrelated "Run analysis" work): cancel still reports completion; 20 s fixed wait when no progress; new strings not routed through `l10n()`.
- `--no-pub` has no fallback when `package_config.json` is missing.
- `GestureDetector` + `Stack` is treated as hit-testing its whole area.
- `avoid_undisposed_instances` loop credit does not cover `ForEachPartsWithIdentifier`, spreads or collection-if.
