# Bug: prefer_safe_area_consumer fires when Scaffold has no appBar

**History summary:** Filed from saropa_drift_viewer. Rule fires on Scaffold with neither appBar nor bottomNavigationBar where SafeArea is correct. Status: Open.

**Rule:** `prefer_safe_area_consumer`  
**Status:** Open  
**Reporter:** saropa_drift_viewer package

---

## Summary

The rule reports "SafeArea placed directly inside a Scaffold body is often redundant because Scaffold already insets its body below the **AppBar** and above the **BottomNavigationBar**." The rule text explicitly says to remove SafeArea only when the Scaffold **has** appBar or bottomNavigationBar. Despite that, the rule fires on a Scaffold that has **neither** appBar nor bottomNavigationBar, where SafeArea is correct and not redundant.

## Expected behavior

- **Do not** report when the Scaffold has no `appBar` and no `bottomNavigationBar`. In that case, the body extends under the status bar and SafeArea is appropriate.
- **Do** report only when the Scaffold has `appBar: ...` or `bottomNavigationBar: ...` and the body is wrapped in SafeArea (redundant top/bottom insets).

## Actual behavior

The rule reports on any `Scaffold( body: SafeArea( ... ) )` regardless of whether the Scaffold has an appBar or bottomNavigationBar.

## Minimal reproduction

**File:** `lib/src/drift_viewer_floating_button.dart` (or any Dart file)

```dart
// Error screen: full-screen body, NO appBar, NO bottomNavigationBar.
// SafeArea is required so content is not hidden by status bar / notch.
class _WebViewErrorScreen extends StatelessWidget {
  const _WebViewErrorScreen({required this.urlSample});
  final String urlSample;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Text('Invalid URL: $urlSample'),
        ),
      ),
    );
  }
}
```

- This Scaffold has **no** `appBar` and **no** `bottomNavigationBar`.
- The rule reports: `[prefer_safe_area_consumer] SafeArea placed directly inside a Scaffold body is often redundant... Remove SafeArea if the Scaffold has appBar or bottomNavigationBar that already consume safe area insets.`

So the code **follows** the rule’s own condition (no appBar/bottomBar), yet the rule still fires.

## Suggested fix

In the rule’s implementation:

1. Resolve the enclosing `Scaffold` (e.g. by walking up the parent from the `SafeArea` or by analyzing the `Scaffold` that contains the `body` argument).
2. Check whether that Scaffold has a non-null `appBar` or `bottomNavigationBar` (e.g. via the widget’s constructor arguments or the corresponding `Scaffold` element).
3. **Only** report when `appBar != null` or `bottomNavigationBar != null`. Do **not** report when the Scaffold has neither.

## Environment

- Package: saropa_drift_viewer (Flutter)
- saropa_lints: 6.2.2
- Dart SDK: >=3.3.0 <4.0.0

## References

- Rule message: "Remove SafeArea if the Scaffold has appBar or bottomNavigationBar that already consume safe area insets."
- Flutter: `Scaffold` only applies safe area insets to the body when the body is not already inset by appBar/bottomNavigationBar. A Scaffold with no appBar has no automatic top inset.
