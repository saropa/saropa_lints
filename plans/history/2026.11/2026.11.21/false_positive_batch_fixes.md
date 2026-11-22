# False-positive batch fixes and scan-test repairs

Eleven lint rules reported false positives (see sibling `*_false_positive.md` files in this folder); each rule was narrowed with a fixture and test. Five pre-existing Windows-related test failures in the scan tooling were also repaired so the full suite passes.

## Finish Report (2026-11-21)

### Changes
- avoid_context_after_navigation: awaited call visited before arming post-await state.
- avoid_gesture_only_interactions: skips detectors under an action-bearing `Semantics` or opaque invisible hit regions.
- avoid_variable_shadowing: wildcard `_` never shadows.
- require_ios_accessibility_large_text: consumer-aware (Text/RichText/TextPainter with textScaler exempt).
- invalid_field_name: only reserved words flagged.
- prefer_static_method: methods called through an instance receiver (invocation, cascade, tear-off, `this.`) exempt.
- avoid_motion_without_reduce: shared reduced-motion pattern incl. `isMotionReduced`; `Duration.zero` exempt.
- avoid_public_members_in_states: all `@override` members exempt.
- prefer_stream_distinct: listeners ignoring the event parameter exempt.
- require_permission_manifest_android: consults AndroidManifest.xml.
- avoid_implicitly_nullable_extension_types: only nullable / bare type-parameter representations.
- ScanRunner: `runResolved` rescues explicitly requested files removed by `analyzer: exclude:` (collections disposed after scan); `_createContextUnit` normalizes paths; git-changed and analyzer-exclude tests made separator-neutral.
- anti-pattern guard: `.contains('noScaling')` replaced by equality/endsWith.

### Verification
`dart test` (full suite): 10729 passed, 1 skipped, 0 failed. Several fixture-based tests only assert fixture text, not rule firing; rule behavior itself is unverified by the scan CLI.

### Deferred review nits
- prefer_static_method re-walks the unit per candidate (O(methods x unit)); cross-library callers unseen.
- `_hasScalingOptOut` misses `TextScaler.linear(1)`; `Text.rich` consumer naming unchecked.
- `_representationMayBeNullable` skips `dynamic` representations.
- `_hasSemanticsActionAncestor` accepts any distant ancestor Semantics.
- reduced-motion pattern is a substring match; `const Duration.zero` not matched.
- `@override` exemption also covers overrides of app-defined public members.
- `shouldRemind` reads the manifest per file; only the main manifest is inspected.
