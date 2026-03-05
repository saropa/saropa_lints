# Bug (fixed): prefer_safe_area_consumer with SafeArea(top: false)

**Summary:** Rule no longer reports when SafeArea has explicit `top: false` in a Scaffold body, since only bottom/left/right insets are applied and there is no redundant top inset. Fix: `_safeAreaHasTopFalse()` in PreferSafeAreaConsumerRule; fixture `_goodSafeAreaTopFalse()` in prefer_safe_area_consumer_fixture.dart.

**Rule:** `prefer_safe_area_consumer` · **Status:** Fixed · **Reporter:** saropa_drift_viewer

---

## Original report

The rule reported that SafeArea is redundant when the Scaffold has an appBar. When the developer uses `SafeArea(top: false, ...)` they are only adding bottom (and optionally left/right) insets—no top. So there is no "doubling up" on the top; the rule should not report.

**Expected:** Do not report when SafeArea has `top: false`. Do report when SafeArea uses default top.

**Minimal reproduction:**
```dart
Scaffold(
  appBar: AppBar(title: Text('Title')),
  body: SafeArea(
    top: false,
    child: Center(child: Text('Content')),
  ),
)
```

## Resolution

When the SafeArea instance has an explicit `top: false` named argument, the rule skips reporting. Implemented by `_safeAreaHasTopFalse()` in `PreferSafeAreaConsumerRule` (widget_patterns_avoid_prefer_rules.dart). Fixture `_goodSafeAreaTopFalse()` added in prefer_safe_area_consumer_fixture.dart.
