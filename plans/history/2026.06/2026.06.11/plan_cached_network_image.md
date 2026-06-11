# Plan: new `cached_network_image` lint rules

**Package:** `cached_network_image_ce` ^4.6.2 (Saropa Contacts uses the community fork).
**saropa_lints coverage:** 8 rules already exist in `lib/src/rules/media/image_rules.dart` covering
`CachedNetworkImage` widget usage (dimensions, placeholder, errorWidget, fade, cacheManager, DPR,
unbounded list, web platform). This plan adds rules for gaps not yet covered.

**`_ce` fork compatibility:** The fork ships identical class and parameter names to upstream
(`CachedNetworkImage`, `CachedNetworkImageProvider`, `DefaultCacheManager`).
Its library URI prefix is `package:cached_network_image_ce/` — the existing
`ImportPackages.cachedNetworkImage` set in `import_utils.dart` only contains
`package:cached_network_image/` and must be extended.

---

## Proposed rules

> **VALIDATION (2026-06-11) — VERIFIED:** the "8 existing widget-form rules" claim is accurate (image_rules.dart lines 853, 929, 1000, 1173, 1613, 1766, 1879, 1996, all guard the CachedNetworkImage WIDGET). The 4 proposed rules target the Provider form / inline CacheManager / non-cached Image.network and do NOT overlap.

| rule_name (snake_case) | type | detects | quick-fix? | severity | FP guard |
|---|---|---|---|---|---|
| `fix_import_utils_ce_fork` | infra fix | `import_utils.cachedNetworkImage` missing `_ce` URI | n/a — code fix not rule | — | prerequisite |
| `require_cached_image_provider_dimensions` | best-practice | `CachedNetworkImageProvider(url)` without `maxWidth` or `maxHeight` | no | WARNING | Only when static type resolves from `package:cached_network_image[_ce]/` |
| `require_cached_image_provider_error_listener` | best-practice | `CachedNetworkImageProvider(url)` without `errorListener` | no | INFO | same URI guard |
| `prefer_cached_network_image_over_image_network` | migration | `Image.network(…)` in a file that imports `cached_network_image[_ce]` | yes — replace with `CachedNetworkImage(imageUrl: …)` | INFO | skip test files; skip files where the call is already inside a `kIsWeb` true-branch (to avoid conflict with `avoid_cached_image_web`) |
| `avoid_inline_cache_manager_construction` | perf | `CacheManager(…)` or `DefaultCacheManager()` constructed as the value of the `cacheManager:` named argument | no | WARNING | Only flag construction **inside** the named arg expression, not at declaration sites; skip if the parent is a `static final` or `const` field |
| `require_cached_image_cache_key` | best-practice | `CachedNetworkImage` or `CachedNetworkImageProvider` used without a `cacheKey` when `memCacheWidth`/`memCacheHeight` differ from disk cache dimensions | INFO (speculative — verify) | see detail | High FP risk — INFO only |

---

## Rule detail

### prerequisite: fix_import_utils_ce_fork

> **VALIDATION (2026-06-11) — DO FIRST:** the `_ce` fork URI infra fix in `ImportPackages.cachedNetworkImage` (import_utils.dart:109) is a prerequisite for the provider rules.

Not a lint rule — an infra fix to `lib/src/import_utils.dart`.

- **What/why:** `ImportPackages.cachedNetworkImage` currently only contains `'package:cached_network_image/'`.
  Saropa Contacts (and any project using the community fork) imports `package:cached_network_image_ce/`.
  All six existing rules and both new provider rules guard on the constructor type name only
  (`typeName != 'CachedNetworkImage'`), so they fire regardless of import. However any future rule
  that uses `ImportPackages.cachedNetworkImage` to skip non-users of the package will silently miss
  `_ce` consumers.
- **Fix:** Add `'package:cached_network_image_ce/'` to the set:
  ```dart
  static const Set<String> cachedNetworkImage = {
    'package:cached_network_image/',
    'package:cached_network_image_ce/', // community fork — API-compatible
  };
  ```
- **False positives:** none — it is an additive set extension.

---

### `require_cached_image_provider_dimensions`

- **What/why:** `CachedNetworkImageProvider` is the `ImageProvider` form of the package. It accepts
  `maxWidth` and `maxHeight` (`int?`) to resize the image before storing it in the Flutter image cache.
  Without these parameters the provider decodes the full-resolution source image into memory, which is
  the same OOM footgun as `CachedNetworkImage` without `memCacheWidth`/`memCacheHeight`.
  The existing `require_cached_image_dimensions` rule only checks `CachedNetworkImage`
  (the widget constructor), leaving all `CachedNetworkImageProvider(url)` call sites uncovered.

- **Detection (AST, type-safe):**
  ```dart
  context.addInstanceCreationExpression((InstanceCreationExpression node) {
    final typeName = node.constructorName.type.name.lexeme;
    if (typeName != 'CachedNetworkImageProvider') return;

    // Library URI guard — handles both upstream and _ce fork
    final element = node.constructorName.staticElement?.enclosingElement;
    final uri = element?.library?.identifier ?? '';
    if (!uri.startsWith('package:cached_network_image/') &&
        !uri.startsWith('package:cached_network_image_ce/')) return;

    bool hasMaxWidth = false;
    bool hasMaxHeight = false;
    for (final arg in node.argumentList.arguments) {
      if (arg is NamedExpression) {
        if (arg.name.label.name == 'maxWidth') hasMaxWidth = true;
        if (arg.name.label.name == 'maxHeight') hasMaxHeight = true;
      }
    }
    if (!hasMaxWidth && !hasMaxHeight) reporter.atNode(node);
  });
  ```

- **Fix:** Add `maxWidth:` and/or `maxHeight:` matching the rendered display size.

- **False positives:**
  - SVG or vector images (no raster resize benefit): low risk — the class name is unique to this package.
  - `CachedNetworkImageProvider` used to pre-populate the image cache with full-res thumbnails for a
    later hero expansion: acceptable INFO trade-off; developer can suppress with a comment.

---

### `require_cached_image_provider_error_listener`

- **What/why:** `CachedNetworkImageProvider` has no `errorWidget` or `errorBuilder` — errors surface
  only through the `errorListener` callback (`void Function(Object)?`). When `errorListener` is absent,
  load failures are silently swallowed; there is no fallback widget and no logging path. Teams that
  switch from `CachedNetworkImage` (widget) to the provider form often lose error visibility entirely.

- **Detection (AST, type-safe):**
  Same constructor check as above, plus:
  ```dart
  bool hasErrorListener = false;
  for (final arg in node.argumentList.arguments) {
    if (arg is NamedExpression &&
        arg.name.label.name == 'errorListener') {
      hasErrorListener = true;
      break;
    }
  }
  if (!hasErrorListener) reporter.atNode(node);
  ```

- **Fix:** Add `errorListener: (e) => logger.warning('Image load failed', e)` or equivalent.

- **False positives:** Low. `CachedNetworkImageProvider` is a unique name to this package.
  In golden/widget tests the error listener is typically unneeded — those test files are already
  excluded by `ProjectContext.isTestFile`.

---

### `prefer_cached_network_image_over_image_network`

> **VALIDATION (2026-06-11) — NOTE:** watch co-firing with the list-builder Image.network rules on the same node.
>
> **VALIDATION (2026-06-11) — NOTE:** if the sample code uses `node.constructorName.staticElement?.enclosingElement`, verify against the current analyzer/analyzer_compat element API at build time (may need the element3 shim).

- **What/why:** When a file already imports `cached_network_image[_ce]`, using `Image.network` is a
  missed-cache call: the image is downloaded afresh on every widget rebuild, is not stored on disk,
  and provides no placeholder or error widget. This footgun is common when a developer adds the package
  for one widget but leaves old `Image.network` calls untouched elsewhere in the same file.
  The existing `avoid_image_rebuild_on_scroll` rule only catches `Image.network` *inside list builders*;
  this rule catches all `Image.network` in files that have opted in to caching.

- **Detection (AST, type-safe):**
  Requires an import guard — only fire when the file already imports the package.
  ```dart
  // In runWithReporter, after confirming import:
  context.addInstanceCreationExpression((InstanceCreationExpression node) {
    if (node.constructorName.toSource() != 'Image.network') return;
    reporter.atNode(node.constructorName, code);
  });
  ```
  Use `ImportPackages.cachedNetworkImage` (after adding the `_ce` URI) to skip files that do not
  import either variant.

- **Quick fix:** Replace `Image.network(url)` → `CachedNetworkImage(imageUrl: url)`.
  Note: the fix cannot mechanically transfer named parameters (`cacheWidth`, `loadingBuilder`,
  `errorBuilder`) because the param names differ between the two widgets; the fix replaces the
  constructor only and leaves the developer to add placeholders.

- **False positives:**
  - A file that intentionally uses `Image.network` for a web-only branch alongside
    `CachedNetworkImage` for the native branch — the `kIsWeb` exclusion in the import guard
    handles the web case. If the `Image.network` call is inside a `kIsWeb` true-branch, skip it
    (consistent with `avoid_cached_image_web`).
  - Test files: skip via `ProjectContext.isTestFile`.

---

### `avoid_inline_cache_manager_construction`

- **What/why:** `CacheManager(Config(…))` or `DefaultCacheManager()` constructed as the direct
  expression value of a `cacheManager:` named argument is created on every widget build (every
  frame rebuild). Each construction initializes a new cache database connection, spawns an
  isolate-adjacent background process, and registers independent file-system listeners.
  On a `ListView.builder` with 50 items this creates 50 independent cache databases on every scroll.
  The correct pattern is to declare the manager as a `static final` or top-level `final` variable
  and pass the reference.

  Confirmed by GitHub issue #429 and the package README recommendation to "use CacheManager as a
  global variable."

- **Detection (AST, type-safe):**
  ```dart
  context.addNamedExpression((NamedExpression node) {
    if (node.name.label.name != 'cacheManager') return;

    final expr = node.expression;
    if (expr is! InstanceCreationExpression) return;

    final typeName = expr.constructorName.type.name.lexeme;
    if (typeName != 'CacheManager' && typeName != 'DefaultCacheManager') return;

    // Confirm the type comes from flutter_cache_manager
    final uri = expr.constructorName.staticElement
        ?.enclosingElement?.library?.identifier ?? '';
    if (!uri.startsWith('package:flutter_cache_manager/') &&
        !uri.startsWith('package:cached_network_image/') &&
        !uri.startsWith('package:cached_network_image_ce/')) return;

    reporter.atNode(expr);
  });
  ```

- **Fix:** Extract to a `static final` or module-level `final` variable and reference it.

- **False positives:**
  - `const` expressions (impossible for `CacheManager` — its constructor is not `const`, so the
    analyzer would already reject them).
  - Inline construction in a `static final` field initializer: the parent `FieldDeclaration` is
    `static`; check ancestor chain and skip.

---

### `require_cached_image_cache_key` (speculative — verify before implementing)

- **What/why:** When the same remote image URL is displayed at two different sizes (thumbnail and
  hero), Flutter's image cache stores two separate decoded bitmaps under the same URL key. Adding a
  size-specific `cacheKey` allows each size to be stored independently without evicting the other.
  Without it, the second load may re-decode from disk or network.

- **Detection:** Cannot be lint-detected reliably. To flag the *absence* of `cacheKey`, a rule
  would have to know whether the same URL is used at multiple sizes elsewhere in the file — a
  cross-call-site analysis not feasible in a single-node AST visitor without cross-file state.

- **Verdict: NOT lint-able as stated.** This is a documentation/code-review concern, not a
  mechanical AST check. Do not implement. Document as a code-review checklist item instead.

---

## Implementation note

1. **Infra fix first:** Extend `ImportPackages.cachedNetworkImage` in
   `lib/src/import_utils.dart` to include the `_ce` URI.

2. **New file:** `lib/src/rules/packages/cached_network_image_rules.dart`
   — implement `RequireCachedImageProviderDimensionsRule`,
   `RequireCachedImageProviderErrorListenerRule`,
   `PreferCachedNetworkImageOverImageNetworkRule`,
   `AvoidInlineCacheManagerConstructionRule`.

3. **Register** each in `lib/saropa_lints.dart` inside `_allRuleFactories`:
   ```dart
   RequireCachedImageProviderDimensionsRule.new,
   RequireCachedImageProviderErrorListenerRule.new,
   PreferCachedNetworkImageOverImageNetworkRule.new,
   AvoidInlineCacheManagerConstructionRule.new,
   ```

4. **Tier assignment** in `lib/src/tiers.dart`:
   - `require_cached_image_provider_dimensions` → `recommendedOnlyRules` (same tier as `require_cached_image_dimensions`)
   - `require_cached_image_provider_error_listener` → `professionalOnlyRules`
   - `prefer_cached_network_image_over_image_network` → `recommendedOnlyRules`
   - `avoid_inline_cache_manager_construction` → `recommendedOnlyRules`

5. **ROADMAP.md** entry per rule.

6. **No new `example_*` directory** is needed until rules are implemented — per CONTRIBUTING.md,
   fixtures are created only when the rule fires on the BAD example.

---

## Sources

- [CachedNetworkImage class — pub.dev](https://pub.dev/documentation/cached_network_image/latest/cached_network_image/CachedNetworkImage-class.html)
- [CachedNetworkImageProvider class — pub.dev](https://pub.dev/documentation/cached_network_image/latest/cached_network_image/CachedNetworkImageProvider-class.html)
- [cached_network_image_ce library — pub.dev](https://pub.dev/documentation/cached_network_image_ce/latest/cached_network_image/)
- [cached_network_image_ce GitHub (community fork)](https://github.com/Erengun/flutter_cached_network_image_ce)
- [GitHub issue #429 — Memory Overflow due to CachedNetworkImage](https://github.com/Baseflow/flutter_cached_network_image/issues/429)
- [GitHub issue #675 — maxWidthDiskCache on CachedNetworkImageProvider](https://github.com/Baseflow/flutter_cached_network_image/issues/675)
- [GitHub issue #980 — errorWidget not called on retry with disk cache params](https://github.com/Baseflow/flutter_cached_network_image/issues/980)
- [Flutter docs — cached-images cookbook](https://docs.flutter.dev/cookbook/images/cached-images)
