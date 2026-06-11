// ignore_for_file: unused_local_variable, unused_element, dead_code

/// Fixture for flutter_svg rules.
///
/// BAD examples are annotated with `// LINT` and the rule code.
/// GOOD examples are annotated with `// OK`.
///
/// False-positive guards (`Icon`, `Container`) are annotated `// OK — FP guard`.
library;

// Mock flutter_svg types — no real package dependency in test fixtures.
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Minimal flutter_svg stubs (satisfy the import gate without the real package)
// ---------------------------------------------------------------------------

// ignore: avoid_classes_with_only_static_members
class SvgPicture {
  const SvgPicture._();

  // ignore: prefer_constructors_over_static_methods
  static Widget asset(
    String path, {
    Color? color,
    BlendMode? colorBlendMode,
    ColorFilter? colorFilter,
    String? semanticsLabel,
    bool excludeFromSemantics = false,
    double? width,
    double? height,
    Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
    Widget Function(BuildContext)? placeholderBuilder,
  }) =>
      const SizedBox.shrink();

  // ignore: prefer_constructors_over_static_methods
  static Widget network(
    String url, {
    Color? color,
    BlendMode? colorBlendMode,
    ColorFilter? colorFilter,
    String? semanticsLabel,
    bool excludeFromSemantics = false,
    double? width,
    double? height,
    Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
    Widget Function(BuildContext)? placeholderBuilder,
  }) =>
      const SizedBox.shrink();

  // ignore: prefer_constructors_over_static_methods
  static Widget string(
    String source, {
    ColorFilter? colorFilter,
    String? semanticsLabel,
    bool excludeFromSemantics = false,
    double? width,
    double? height,
    Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
  }) =>
      const SizedBox.shrink();

  // ignore: prefer_constructors_over_static_methods
  static Widget memory(
    List<int> bytes, {
    ColorFilter? colorFilter,
    String? semanticsLabel,
    bool excludeFromSemantics = false,
    double? width,
    double? height,
    Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
  }) =>
      const SizedBox.shrink();
}

// ---------------------------------------------------------------------------
// prefer_svg_color_filter
// ---------------------------------------------------------------------------

void badPreferSvgColorFilter() {
  // LINT: prefer_svg_color_filter — color + colorBlendMode both present
  SvgPicture.asset('icon.svg', color: Colors.red, colorBlendMode: BlendMode.srcIn);

  // LINT: prefer_svg_color_filter — color only (colorBlendMode absent; srcIn default)
  SvgPicture.asset('icon.svg', color: Colors.blue);

  // LINT: prefer_svg_color_filter — network variant
  SvgPicture.network('https://example.com/icon.svg', color: Colors.green);
}

void goodPreferSvgColorFilter() {
  // OK — already using colorFilter
  SvgPicture.asset(
    'icon.svg',
    colorFilter: const ColorFilter.mode(Colors.red, BlendMode.srcIn),
    semanticsLabel: 'Logo',
  );

  // OK — no color at all
  SvgPicture.asset('icon.svg', semanticsLabel: 'Image');

  // OK — FP guard: Icon has a color argument but is not SvgPicture
  // ignore: avoid_redundant_argument_values
  const Icon(Icons.home, color: Colors.red); // OK — FP guard

  // OK — FP guard: Container has a color argument but is not SvgPicture
  Container(color: Colors.blue, child: const SizedBox.shrink()); // OK — FP guard
}

// ---------------------------------------------------------------------------
// svg_network_missing_error_builder
// ---------------------------------------------------------------------------

void badSvgNetworkMissingErrorBuilder() {
  // LINT: svg_network_missing_error_builder — no errorBuilder
  SvgPicture.network('https://example.com/icon.svg');

  // LINT: svg_network_missing_error_builder — placeholderBuilder alone does NOT suppress
  SvgPicture.network(
    'https://example.com/icon.svg',
    placeholderBuilder: (context) => const CircularProgressIndicator(),
  );
}

void goodSvgNetworkMissingErrorBuilder() {
  // OK — errorBuilder present
  SvgPicture.network(
    'https://example.com/icon.svg',
    errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
    placeholderBuilder: (context) => const CircularProgressIndicator(),
    semanticsLabel: 'Remote icon',
  );
}

// ---------------------------------------------------------------------------
// svg_network_missing_placeholder
// ---------------------------------------------------------------------------

void badSvgNetworkMissingPlaceholder() {
  // LINT: svg_network_missing_placeholder — no placeholderBuilder
  SvgPicture.network(
    'https://example.com/icon.svg',
    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    semanticsLabel: 'Icon',
  );
}

void goodSvgNetworkMissingPlaceholder() {
  // OK — placeholderBuilder present
  SvgPicture.network(
    'https://example.com/icon.svg',
    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    placeholderBuilder: (context) => const CircularProgressIndicator(),
    semanticsLabel: 'Icon',
  );

  // OK — intentionally invisible widget (width: 0, height: 0): suppressed
  SvgPicture.network(
    'https://example.com/icon.svg',
    width: 0,
    height: 0,
    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    excludeFromSemantics: true,
  );
}

// ---------------------------------------------------------------------------
// svg_missing_semantics_label
// ---------------------------------------------------------------------------

void badSvgMissingSemanticsLabel() {
  // LINT: svg_missing_semantics_label — no label and no exclusion
  SvgPicture.asset('icon.svg');

  // LINT: svg_missing_semantics_label — empty string label
  SvgPicture.asset('icon.svg', semanticsLabel: '');

  // LINT: svg_missing_semantics_label — excludeFromSemantics: false is explicit but still no label
  SvgPicture.asset('icon.svg', excludeFromSemantics: false);
}

void goodSvgMissingSemanticsLabel() {
  // OK — non-empty semanticsLabel
  SvgPicture.asset('icon.svg', semanticsLabel: 'Company logo');

  // OK — explicitly excluded (decorative SVG)
  SvgPicture.asset('icon.svg', excludeFromSemantics: true);

  // OK — variable label (trusted, may be dynamic i18n string)
  final label = 'Dynamic label';
  SvgPicture.asset('icon.svg', semanticsLabel: label);

  // OK — colorFilter variant with label
  SvgPicture.asset(
    'icon.svg',
    colorFilter: const ColorFilter.mode(Colors.red, BlendMode.srcIn),
    semanticsLabel: 'Colored logo',
  );

  // OK — FP guard: Icon has a color argument but is not SvgPicture
  // ignore: avoid_redundant_argument_values
  const Icon(Icons.star, color: Colors.yellow); // OK — FP guard

  // OK — FP guard: Container — not SvgPicture
  Container(color: Colors.green, child: const SizedBox.shrink()); // OK — FP guard
}

// ---------------------------------------------------------------------------
// svg_string_missing_error_builder
// ---------------------------------------------------------------------------

void badSvgStringMissingErrorBuilder() {
  final dynamic dynamicSvg = '<svg></svg>';

  // LINT: svg_string_missing_error_builder — dynamic input → WARNING
  SvgPicture.string(dynamicSvg as String);

  // LINT: svg_string_missing_error_builder — string literal → INFO (lower severity)
  SvgPicture.string('<svg><rect width="10" height="10"/></svg>');
}

void goodSvgStringMissingErrorBuilder() {
  final dynamic dynamicSvg = '<svg></svg>';

  // OK — errorBuilder present on dynamic input
  SvgPicture.string(
    dynamicSvg as String,
    errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
    semanticsLabel: 'Dynamic SVG',
  );

  // OK — errorBuilder present on literal
  SvgPicture.string(
    '<svg><rect width="10" height="10"/></svg>',
    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    semanticsLabel: 'Static SVG',
  );
}
