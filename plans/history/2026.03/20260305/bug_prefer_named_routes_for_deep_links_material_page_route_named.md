# Bug (fixed): prefer_named_routes_for_deep_links with RouteSettings(name: ...)

**Summary:** Rule no longer reports when MaterialPageRoute/CupertinoPageRoute use `settings: RouteSettings(name: pathOrName)` with a non-empty name (literal or variable). Supports path-style names and onGenerateRoute-based deep linking. Fix: `_hasNamedRouteSettings()` and shared `_getSettingsArgument()` in navigation_rules.dart; still reports when no settings, no name, or `name: ''`.

**Rule:** `prefer_named_routes_for_deep_links` · **Status:** Fixed · **Reporter:** saropa_drift_viewer

---

## Original report

The rule reported "Anonymous route construction prevents deep linking" on code that built MaterialPageRoute with `RouteSettings(name: routeName)` and a path-style name. The app used onGenerateRoute and matched on the route name; deep linking worked. The rule treated any MaterialPageRoute with a builder as anonymous.

**Expected:** Do not report when the route has `settings: RouteSettings(name: ...)` with a non-empty name. Do report when the route is truly anonymous (no name or empty name).

**Minimal reproduction:**
```dart
return MaterialPageRoute<void>(
  settings: RouteSettings(name: routeName, arguments: uri.toString()),
  builder: (BuildContext _) => _WebViewScreenFromSettings(uri: uri),
);
```

## Resolution

When analyzing MaterialPageRoute/CupertinoPageRoute, the rule now checks for a `settings` argument. If it is `RouteSettings(name: x)`, the rule does not report when `x` is a non-empty string literal or any other expression (variable). It still reports when `name` is the empty string literal `''`. Shared helper `_getSettingsArgument()` used by PreferRouteSettingsNameRule and PreferNamedRoutesForDeepLinksRule. Fixture: example_widgets/lib/navigation/prefer_named_routes_for_deep_links_fixture.dart.
