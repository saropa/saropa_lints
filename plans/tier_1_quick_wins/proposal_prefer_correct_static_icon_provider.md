# PROPOSAL: Flag Icons Built From Raw Asset Paths Instead of a Proper Icon Provider

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `require_image_semantics` (adjacent a11y/asset-usage rule for `Image` widgets — this proposal is the `Icon`/`IconData` analog)

---

## Summary

Add a rule that flags `Icon`/`IconButton` widgets constructed with an ad hoc `ImageIcon`/asset-path workaround (e.g. wrapping `AssetImage('assets/icons/foo.png')` in `ImageIcon` for something that should be a vector `IconData`, or passing a raw string where an `IconData` constant is expected) instead of a proper static icon provider such as an `IconData` constant (`Icons.foo`, a generated icon font constant, or a `flutter_svg`/`vector_graphics` typed accessor).

**Closes gap:** DCM `prefer-correct-static-icon-provider` (dcm.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" TRUE GAPS section.

---

## Motivation

Icons in Flutter have two legitimate construction paths: `Icon(IconData)` for vector icon fonts/font-based icon sets, and `ImageIcon(ImageProvider)` for raster or SVG-based icon assets that genuinely need an `ImageProvider`. A common anti-pattern in growing codebases is reaching for `ImageIcon(AssetImage('assets/icons/close.png'))` (or `Image.asset` wrapped in a fixed-size `SizedBox` used as a fake icon) for icons that are actually simple font glyphs available as `IconData` constants — this bloats the asset bundle with rasterized icon PNGs at multiple resolutions, loses free tinting/sizing/semantics behavior that `Icon` gets for free from `IconTheme`, and is slower to render than a font glyph.

DCM (dcm.dev) ships `prefer-correct-static-icon-provider` to catch this specific asset-vs-glyph confusion. `saropa_lints` has no equivalent — `require_image_semantics` (`lib/src/rules/ui/accessibility_rules.dart:1512`) checks that `Image`/`ImageIcon` constructors carry a `semanticLabel`, but does not evaluate whether an `Image`-based icon construction was the right choice in the first place.

---

## Detection / Behavior

Flag `ImageIcon(AssetImage(...))` / `ImageIcon(AssetImage.fromAssetName(...))` calls, and `Image.asset(...)` calls sized/used in an icon-like context (fixed small `width`/`height` under a stylistic threshold, e.g. ≤ 32, inside a widget tree that also imports/uses `Icons.*` elsewhere in the file — signaling the project already has an icon-font convention it bypassed here) where the asset path string ends in a common icon-font-replaceable pattern (`_icon`, `/icons/`) AND the project's `pubspec.yaml` declares no custom font family bound to that asset (i.e. it's a plain raster/SVG asset, not a registered icon font glyph). Pass when the icon is built from `IconData` (`Icons.*`, a generated icon-font class, `CupertinoIcons.*`) or when `ImageIcon`/`Image.asset` is used for an asset that is not shadowing an available icon-font glyph (heuristically: the file has no sibling `Icons.*` usage nearby, suggesting the raster asset is intentional — e.g. a brand logo).

### Should flag (bad code)

```dart
// A close/dismiss icon built from a raster asset instead of the built-in glyph.
IconButton(
  icon: ImageIcon(AssetImage('assets/icons/close_icon.png')), // LINT
  onPressed: () => Navigator.pop(context),
)
```

### Should pass (good code)

```dart
IconButton(
  icon: const Icon(Icons.close), // OK — proper IconData static provider
  onPressed: () => Navigator.pop(context),
)

// A brand logo is legitimately not an icon-font glyph — this is not
// a "static icon provider" case at all, so it is out of scope.
ImageIcon(AssetImage('assets/brand/company_logo.png')) // OK — no font-glyph equivalent exists
```

---

## Proposed Tier

Tier: Comprehensive
Justification: detection depends on heuristic asset-path naming and sibling `Icons.*` usage rather than a hard type-level distinction, so false positives on legitimately raster/SVG-only icon sets are plausible. Comprehensive keeps this available to teams enforcing a consistent icon-font convention without imposing the heuristic on the default Essential/Recommended tiers.

---

## Edge Cases

1. **SVG-based icon packages (`flutter_svg`, `flutter_vector_icons`)** — `SvgPicture.asset` used for icons should not be flagged; the rule targets `ImageIcon`/`Image.asset` specifically, not every asset-based icon rendering mechanism.
2. **Brand/logo assets with no icon-font equivalent** — should pass; the heuristic (no sibling `Icons.*` usage, path outside an `icons/` directory convention) is intentionally conservative to avoid flagging legitimate raster assets.
3. **Dynamic/user-uploaded icon assets** (`ImageIcon(NetworkImage(user.avatarIconUrl))`) — should pass; the rule only targets `AssetImage`/`Image.asset` with a compile-time-constant string literal path, not network or dynamic providers.
4. **Custom icon fonts registered via `pubspec.yaml` `fonts:`** — an asset path pointing at the font file itself is not an icon construction call and is out of scope; only `Icon`/`ImageIcon`/`Image.asset` call sites are visited.

---

## Alternatives Considered

- **Require a project-configured icon-font glyph map** (asset path → `IconData` constant) for precise detection instead of naming heuristics — more accurate but requires config authoring per project before the rule provides any value; proposed as a v1 heuristic-only rule with the mapped-config variant as a possible follow-up if false-positive reports justify it.
- **Flag every `ImageIcon`/small `Image.asset` unconditionally** — rejected as too broad; would flag legitimate raster/SVG icon sets that have no font-glyph equivalent, producing high-noise output.

---

## Decision

---

## Implementation Notes

---

## Commits
