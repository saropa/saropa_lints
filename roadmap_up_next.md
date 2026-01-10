# Implementation Plan: Next 9 Rules

Rules in tiers.dart that need implementation.

---

## Recommended Tier (4 rules)

| Rule | Target File | Impact | Detection |
|------|-------------|--------|-----------|
| `require_image_loading_placeholder` | image_rules.dart | medium | `Image.network` without `loadingBuilder` or `frameBuilder` |
| `require_location_timeout` | bluetooth_hardware_rules.dart | high | `Geolocator.getCurrentPosition` without `timeLimit` |
| `avoid_motion_without_reduce` | accessibility_rules.dart | medium | AnimatedX widget without `MediaQuery.disableAnimations` check |
| `require_refresh_indicator_on_lists` | scroll_rules.dart | medium | ListView/GridView without RefreshIndicator ancestor |

## Professional Tier (5 rules)

| Rule | Target File | Impact | Detection |
|------|-------------|--------|-----------|
| `prefer_firestore_batch_write` | firebase_rules.dart | medium | 3+ sequential Firestore writes in same method |
| `require_animation_status_listener` | animation_rules.dart | medium | AnimationController without `addStatusListener` |
| `avoid_touch_only_gestures` | architecture_rules.dart | medium | GestureDetector without `onSecondaryTap`/hover |
| `require_test_cleanup` | test_rules.dart | medium | Test with File.create without tearDown |
| `require_accessibility_tests` | test_rules.dart | high | Widget test file without `meetsGuideline` |

---

## Checklist

### Before Each Rule
- [ ] Verify not already implemented (check all_rules.dart)
- [ ] Confirm tier assignment in tiers.dart

### After Each Rule
- [ ] Add BAD/GOOD examples in doc header
- [ ] Set correct LintImpact
- [ ] Add to all_rules.dart
- [ ] Create fixture in example/lib/
- [ ] Update CHANGELOG.md

### After All Rules
- [ ] Update README rule count
- [ ] Update pubspec.yaml version
