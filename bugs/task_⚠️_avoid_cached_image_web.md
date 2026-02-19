# Task: `avoid_cached_image_web`

## Summary
- **Rule Name**: `avoid_cached_image_web`
- **Tier**: Recommended
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.10 cached_network_image Rules

## Problem Statement

`CachedNetworkImage` from `package:cached_network_image` works by storing downloaded images in a local file-system cache. On the web platform, there is **no file system** — the package falls back to simply using the regular `Image.network` widget, meaning:

1. **No caching benefit**: Images are re-downloaded on every page visit
2. **No placeholder/error handling coordination**: The caching layer is bypassed
3. **Misleading code**: The widget name implies caching, but it doesn't cache on web
4. **Extra package overhead**: You're carrying a dependency that provides no value on web

For Flutter web, the browser's native HTTP cache handles image caching automatically. Using `Image.network` directly is equivalent (and clearer) on web.

## Description (from ROADMAP)

> CachedNetworkImage lacks web caching. Detect web usage; suggest alternatives.

## Trigger Conditions

1. `CachedNetworkImage(...)` is used in a file that will run on web (detected via platform or kIsWeb context)
2. OR: project targets web (detected in `pubspec.yaml` or `web/` directory exists) AND `CachedNetworkImage` is used anywhere

### Phase 1 (Conservative)
Only fire if the usage is inside a `kIsWeb` guard:
```dart
if (kIsWeb) {
  return CachedNetworkImage(...);  // ← trigger: explicitly in web code
}
```

### Phase 2 (Broader)
Fire if project has a `web/` directory AND uses `CachedNetworkImage`.

## Implementation Approach

```dart
context.registry.addInstanceCreationExpression((node) {
  if (!_isCachedNetworkImage(node)) return;
  if (!_isInsideWebGuard(node)) return; // Phase 1
  reporter.atNode(node, code);
});
```

`_isCachedNetworkImage`: check if the constructor name is `CachedNetworkImage` from `package:cached_network_image`.
`_isInsideWebGuard`: walk parent tree for an `if` statement with condition containing `kIsWeb`.

## Code Examples

### Bad (Should trigger — Phase 1)
```dart
Widget buildImage(String url) {
  if (kIsWeb) {
    // ← trigger: CachedNetworkImage in a kIsWeb-true branch
    return CachedNetworkImage(
      imageUrl: url,
      placeholder: (_, __) => const CircularProgressIndicator(),
    );
  }
  return CachedNetworkImage(imageUrl: url);
}
```

### Good (Should NOT trigger)
```dart
Widget buildImage(String url) {
  if (kIsWeb) {
    return Image.network(url); // ← use native Image.network on web (browser caches)
  }
  return CachedNetworkImage(
    imageUrl: url,
    placeholder: (_, __) => const CircularProgressIndicator(),
  );
}
```

## Edge Cases & False Positives

| Scenario | Expected Behaviour | Notes |
|---|---|---|
| Mobile-only app (no web/ dir) | **Suppress** | No web target |
| `CachedNetworkImage` outside `kIsWeb` block | **Suppress** in Phase 1 | May run on mobile too |
| `ExtendedNetworkImageProvider` or other alternatives | **Suppress** | Different packages |
| Test files | **Suppress** | |
| Generated code | **Suppress** | |

## Unit Tests

### Violations
1. `CachedNetworkImage` inside `if (kIsWeb)` branch → 1 lint

### Non-Violations
1. `CachedNetworkImage` in mobile-only context → no lint
2. `Image.network` on web → no lint
3. `CachedNetworkImage` with platform guard that excludes web → no lint

## Quick Fix

Offer "Replace with `Image.network`" when inside `kIsWeb` block:
```dart
// Before
if (kIsWeb) {
  return CachedNetworkImage(imageUrl: url);
}

// After
if (kIsWeb) {
  return Image.network(url);
}
```

Note: preserving `placeholder`, `errorWidget`, etc. would require mapping to `Image.network`'s `loadingBuilder` and `errorBuilder` — this is non-trivial for an automated fix.

## Notes & Issues

1. **cached_network_image-only**: Only fire if `ProjectContext.usesPackage('cached_network_image')`.
2. **Platform detection**: Detecting "this project targets web" at lint time is non-trivial. The presence of a `web/` directory is a reasonable proxy, but `ProjectContext` may not expose this. Check what file-system access is available.
3. **Phase 1 is very conservative**: Only files with explicit `kIsWeb` guards will trigger. This catches the most egregious cases (developer knows they're on web and still uses CachedNetworkImage) without false positives on cross-platform code.
4. **Workaround in Phase 2**: For projects targeting both web and mobile, a platform-adaptive wrapper (e.g., `PlatformImage` that uses `Image.network` on web and `CachedNetworkImage` on mobile) is the idiomatic solution.
5. **Browser cache is not zero**: Modern browsers cache images via HTTP headers (`Cache-Control`, `ETag`). This is functionally equivalent to CachedNetworkImage for web, as long as the server sends proper cache headers.
