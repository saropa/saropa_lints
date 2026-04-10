# Bug: prefer_safe_area_consumer fires when Scaffold has no appBar

**Resolution (fixed):** prefer_safe_area_consumer now reports only when the Scaffold has a non-null appBar or bottomNavigationBar. _scaffoldHasAppBarOrBottomNav(scaffold) checks named arguments; when neither is present (or both are null literals), the rule does not report. Fixture updated: BAD case includes appBar; GOOD case added for full-screen body with no app bar.

**Status:** Fixed

**Rule:** `prefer_safe_area_consumer`  
**Reporter:** saropa_drift_viewer package

---

## Summary

The rule reported on any `Scaffold( body: SafeArea(...) )` regardless of whether the Scaffold had an appBar or bottomNavigationBar. When the Scaffold has neither, the body extends under the status bar and SafeArea is appropriate; the rule's own message said to remove SafeArea only when the Scaffold has appBar or bottomNavigationBar.

## Fix applied

Before reporting, the rule calls _scaffoldHasAppBarOrBottomNav(node) on the Scaffold node. Only when that returns true (at least one of appBar or bottomNavigationBar is a non-null argument) does the rule report on the SafeArea in body. Doc header updated with exception.

## Environment (at report)

- Package: saropa_drift_viewer (Flutter)
- saropa_lints: 6.2.2
- Dart SDK: >=3.3.0 <4.0.0
