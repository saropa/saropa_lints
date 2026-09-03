# PROPOSAL: Avoid Large Assets On Web

**Status: Open**

Created: 2026-09-02

## Summary

Flags a large asset (image, font, video) declared in `pubspec.yaml` or loaded via `rootBundle`/`Image.asset` without any web-specific size guard, since the whole asset ships in the initial web bundle download.

## Existing Coverage

No existing rule covers this. Grep of `lib/src/rules/` for asset-and-web-size logic found:

- `lib/src/rules/widget/widget_patterns_avoid_prefer_rules.dart` — `PreferAssetImageForLocalRule` and `AvoidHardcodedAssetPathsRule` deal with asset *path* hygiene (hardcoded strings, choosing `Image.asset` for local files), not asset *size* or *platform target*.
- `lib/src/rules/resources/file_handling_rules.dart` — flags large-file loading patterns (`PDFDocument.fromAsset`, `rootBundle.load`) for memory/blocking concerns, and has an explicit false-positive carve-out for `_sendWebAsset('assets/web/style.css')`-style calls (line ~1919), but nothing that inspects declared asset sizes or gates on web target.
- `lib/src/rules/packages/flutter_map_rules.dart` — matched the search only incidentally (map tile/asset URLs), not general asset-size guidance.
- `lib/src/rules/media/image_rules.dart` — image-specific rules (`AvoidLargeImagesInMemoryRule`, `RequireImageDisposalRule`, etc.) target runtime memory/decoding cost, not the web-bundle download-size problem, and are not conditioned on `kIsWeb`/web build target.

This is a genuine gap: nothing in the current rule set inspects `pubspec.yaml` asset declarations for file size, or checks that web-served large media goes through a network-loaded/lazy path instead of being bundled.

## Motivation

Flutter web bundles every declared asset into the initial deployment; there is no on-demand asset fetch by default the way native platform asset packs allow. A multi-megabyte hero image, an unsubset custom font, or a bundled video file directly inflates the first-load payload, which is the dominant driver of web Time-to-Interactive and Lighthouse performance scores. Unlike a mobile app install (downloaded once, off the critical path), every web asset byte is paid by the user on every fresh visit unless caching is warmed — making bundle bloat a recurring UX and SEO cost, not a one-time install cost.

## Detection / Behavior

Triggers on an `Image.asset(...)`, `AssetImage(...)`, or `rootBundle.load(...)` call referencing a path under `assets/` when the referenced file (resolved from `pubspec.yaml`'s `flutter: assets:` section) exceeds a size threshold (e.g. 500 KB for images, 200 KB for fonts, any bundled video), and the project has a web target (`ProjectContext` reports a `web/` directory or `flutter_web_plugins` dependency), with no companion guard such as `kIsWeb` branching to a network-loaded/`CachedNetworkImage` alternative.

```dart
// BAD — 3.2 MB PNG bundled directly, shipped to every web visitor
Image.asset('assets/images/hero_banner.png')

// GOOD — web build streams from CDN instead of bundling
Widget hero() {
  if (kIsWeb) {
    return CachedNetworkImage(imageUrl: 'https://cdn.example.com/hero_banner.webp');
  }
  return Image.asset('assets/images/hero_banner.png');
}
```

## Quick Fix

None — manual refactor required. Reducing asset size (recompression, format conversion, subsetting a font) or moving the asset to a network-loaded path is a content/architecture decision the tool cannot make automatically.

## Alternatives Considered

Scoping this narrower — flag only images above a size threshold, deferring fonts and video to follow-up rules — was considered, to keep the first version's file-size heuristics simple (image dimensions/bytes are easier to reason about than font subsetting or video bitrate). Also considered: making this a `project_health` scan-CLI check instead of a per-file lint rule, since it depends on resolving `pubspec.yaml` asset declarations against actual file sizes on disk (a cross-file, filesystem-touching check unlike most single-AST lint rules). Both are open questions for implementation, not blockers to the proposal.
