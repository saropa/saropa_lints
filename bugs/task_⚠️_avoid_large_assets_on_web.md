# Task: `avoid_large_assets_on_web`

## Summary
- **Rule Name**: `avoid_large_assets_on_web`
- **Tier**: Recommended
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §1.11 Platform-Specific Rules — Web-Specific

## Problem Statement

Flutter web apps don't have an app installation step — all assets are downloaded on demand (or bundled in the initial load). A 5MB splash image that a mobile user downloads once at install time is re-downloaded (or loaded from service worker cache) on every web session. Large assets on web:

1. Increase Time-to-Interactive (TTI) for first load
2. Consume more bandwidth on mobile web sessions
3. Cannot be lazy-loaded by default unless explicitly deferred
4. May block the Flutter web engine initialization

JPEG/PNG images should be replaced with WebP (30-50% smaller) on web, and large bundle assets should be loaded via network CDN rather than bundled in `assets/`.

## Description (from ROADMAP)

> Web has no app install; assets download on demand. Lazy-load images and use appropriate formats (WebP) for faster loads.

## Trigger Conditions

### Phase 1 — Large asset files in pubspec.yaml
Detect when `pubspec.yaml` lists asset files that are:
- Larger than a configurable threshold (default: 500KB)
- Of a format that could be optimized (PNG → WebP, JPEG → WebP)
- Inside a path that suggests they're loaded eagerly on startup

**Note**: This requires file system access (reading asset file sizes) which may not be available in the analyzer context. See Notes.

### Phase 2 — Image widget without web check
Detect `Image.asset(path)` where `path` points to a potentially large file, without a `kIsWeb` check or `Image.network(cdnUrl)` alternative for web.

## Implementation Approach

### File Size Check (Phase 1 — potentially deferred)

```dart
// This requires reading file sizes during analysis — check if feasible
// in custom_lint context
final assetPath = 'assets/images/banner.png';
final file = File(assetPath);
if (file.existsSync() && file.lengthSync() > threshold) {
  // Report on the Image.asset call or pubspec entry
}
```

**WARNING**: File I/O in lint rules is generally not recommended — it slows analysis. Use with caution or defer to ROADMAP_DEFERRED.

### Platform-Conditional Check (Phase 2)

```dart
context.registry.addMethodInvocation((node) {
  if (!_isImageAssetCall(node)) return;
  if (_isInsideWebCheck(node)) return;  // inside if (kIsWeb)
  if (!_projectTargetsWeb) return;
  // Check if the asset path suggests a large image
  reporter.atNode(node, code);
});
```

## Code Examples

### Bad (Should trigger)
```dart
// Large PNG used on web without format consideration
Image.asset('assets/hero_banner.png')  // ← trigger if file > 500KB

// Same large image used on all platforms without web branch
child: Image.asset(
  'assets/splash_3mb.jpg',  // ← trigger if web target + large file
)
```

### Good (Should NOT trigger)
```dart
// WebP format ✓
Image.asset('assets/hero_banner.webp')

// Conditional loading for web ✓
Widget buildHero() {
  if (kIsWeb) {
    return Image.network('https://cdn.example.com/hero.webp');
  }
  return Image.asset('assets/hero_banner.png');
}

// Small asset (under threshold) ✓
Image.asset('assets/icon_24px.png')  // small
```

## Edge Cases & False Positives

| Scenario | Expected Behaviour | Notes |
|---|---|---|
| App doesn't target web | **Suppress** | Check build targets / `kIsWeb` usage |
| `Image.asset` with `kIsWeb` guard in parent widget | **Suppress** | Walk parents for `kIsWeb` check |
| Video assets (`.mp4`) | **Trigger but different message** — videos should use streaming | Different recommendation |
| Font assets (`.ttf`, `.otf`) | **Suppress** — fonts are necessary | Different asset type |
| WebP images already | **Suppress** — already using optimal format | Check file extension |
| Asset in a `web/` directory (web-only) | **Note** — web-specific assets are expected to be web-optimized | |
| Test files | **Suppress** | |
| `NetworkImage` on web | **Suppress** — already loading from network | |

## Unit Tests

### Violations
1. `Image.asset('assets/large.png')` in web project where file > 500KB → 1 lint
2. PNG asset without WebP alternative in web project → 1 lint

### Non-Violations
1. `Image.asset('assets/icon.webp')` → no lint (WebP already)
2. `Image.asset` guarded by `if (kIsWeb)` → no lint
3. Non-web project → no lint
4. Small asset (< 500KB) → no lint

## Quick Fix

No automated quick fix — optimizing images requires external tools.

```
correctionMessage: 'Convert images to WebP format for web targets, or use Image.network() with a CDN URL when running on web.'
```

## Notes & Issues

1. **File I/O in lint rules** — reading file sizes during static analysis is unusual and may be slow or unsupported. This rule may need to be deferred to ROADMAP_DEFERRED.md if file system access is not feasible in the `custom_lint` execution context.
2. **Alternative approach**: Instead of checking file sizes, detect PNG/JPEG asset declarations in `pubspec.yaml` and suggest converting to WebP. This avoids file I/O but has high false positive rate for small images.
3. **WebP browser support** is universal (2022+). There's no reason NOT to use WebP for web targets.
4. **SVG assets** are already vector-format and are fine on web. Don't flag SVGs.
5. **Threshold configurability**: The 500KB default should be configurable via `analysis_options.yaml`.
