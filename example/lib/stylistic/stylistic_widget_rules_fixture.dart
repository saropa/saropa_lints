// ignore_for_file: unused_local_variable, prefer_const_constructors
// ignore_for_file: avoid_unnecessary_containers, prefer_clip_behavior

import 'package:flutter/material.dart';

/// Fixture file for stylistic widget rules.
/// These demonstrate the patterns each rule detects.

// =============================================================================
// prefer_sizedbox_over_container / prefer_container_over_sizedbox
// =============================================================================

class SizedBoxVsContainerExamples extends StatelessWidget {
  const SizedBoxVsContainerExamples({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // BAD: Container for simple sizing (prefer_sizedbox_over_container)
        // expect_lint: prefer_sizedbox_over_container
        Container(width: 16, height: 16),

        // expect_lint: prefer_sizedbox_over_container
        Container(width: 100),

        // expect_lint: prefer_sizedbox_over_container
        Container(height: 50),

        // expect_lint: prefer_sizedbox_over_container
        Container(
          width: 100,
          height: 100,
          child: Text('Hello'),
        ),

        // GOOD: Container with decoration (not flagged)
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(color: Colors.red),
        ),

        // GOOD: Container with color (not flagged)
        Container(
          width: 100,
          color: Colors.blue,
        ),

        // GOOD: SizedBox for sizing
        SizedBox(width: 16, height: 16),
        SizedBox(width: 100),
        const SizedBox.shrink(),
        const SizedBox.expand(),
      ],
    );
  }
}

// =============================================================================
// prefer_text_rich_over_richtext / prefer_richtext_over_text_rich
// =============================================================================

class TextRichVsRichTextExamples extends StatelessWidget {
  const TextRichVsRichTextExamples({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // BAD: RichText widget (prefer_text_rich_over_richtext)
        // expect_lint: prefer_text_rich_over_richtext
        RichText(
          text: TextSpan(
            text: 'Hello ',
            children: [
              TextSpan(
                  text: 'World', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),

        // GOOD: Text.rich()
        Text.rich(
          TextSpan(
            text: 'Hello ',
            children: [
              TextSpan(
                  text: 'World', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// prefer_edgeinsets_symmetric / prefer_edgeinsets_only
// =============================================================================

class EdgeInsetsExamples extends StatelessWidget {
  const EdgeInsetsExamples({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // BAD: EdgeInsets.only when symmetric would work (prefer_edgeinsets_symmetric)
        // expect_lint: prefer_edgeinsets_symmetric
        Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 8),
          child: Text('Hello'),
        ),

        // expect_lint: prefer_edgeinsets_symmetric
        Padding(
          padding: EdgeInsets.only(left: 16, right: 16),
          child: Text('Horizontal only'),
        ),

        // expect_lint: prefer_edgeinsets_symmetric
        Padding(
          padding: EdgeInsets.only(top: 8, bottom: 8),
          child: Text('Vertical only'),
        ),

        // GOOD: EdgeInsets.only when values differ
        Padding(
          padding: EdgeInsets.only(left: 16, right: 8),
          child: Text('Different horizontal'),
        ),

        // GOOD: symmetric pair with unpaired side — no clean replacement
        Padding(
          padding: EdgeInsets.only(right: 8, top: 16, bottom: 16),
          child: Text('Unpaired right with symmetric vertical'),
        ),
        Padding(
          padding: EdgeInsets.only(left: 8, top: 16, bottom: 16),
          child: Text('Unpaired left with symmetric vertical'),
        ),
        Padding(
          padding: EdgeInsets.only(top: 8, left: 16, right: 16),
          child: Text('Unpaired top with symmetric horizontal'),
        ),
        Padding(
          padding: EdgeInsets.only(bottom: 8, left: 16, right: 16),
          child: Text('Unpaired bottom with symmetric horizontal'),
        ),

        // GOOD: one axis symmetric, other axis has mismatched values
        Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 4),
          child: Text('Symmetric horizontal, different vertical'),
        ),

        // GOOD: EdgeInsets.symmetric
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Symmetric'),
        ),
      ],
    );
  }
}

// =============================================================================
// prefer_borderradius_circular
// =============================================================================

class BorderRadiusExamples extends StatelessWidget {
  const BorderRadiusExamples({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // BAD: BorderRadius.all(Radius.circular()) (prefer_borderradius_circular)
        // expect_lint: prefer_borderradius_circular
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),

        // GOOD: BorderRadius.circular()
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
        ),

        // GOOD: BorderRadius.all with elliptical (different use case)
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.elliptical(8, 4)),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// prefer_expanded_over_flexible / prefer_flexible_over_expanded
// =============================================================================

class ExpandedVsFlexibleExamples extends StatelessWidget {
  const ExpandedVsFlexibleExamples({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // BAD: Flexible with FlexFit.tight (prefer_expanded_over_flexible)
        // expect_lint: prefer_expanded_over_flexible
        Flexible(
          fit: FlexFit.tight,
          child: Text('Should be Expanded'),
        ),

        // GOOD: Expanded
        Expanded(
          child: Text('Already Expanded'),
        ),

        // GOOD: Flexible with FlexFit.loose (different behavior)
        Flexible(
          fit: FlexFit.loose,
          child: Text('Flexible loose'),
        ),

        // GOOD: Flexible without explicit fit (defaults to loose)
        Flexible(
          child: Text('Flexible default'),
        ),
      ],
    );
  }
}

// =============================================================================
// prefer_material_theme_colors / prefer_explicit_colors
// =============================================================================

class ThemeColorsExamples extends StatelessWidget {
  const ThemeColorsExamples({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // BAD: Hardcoded colors (prefer_material_theme_colors)
        // expect_lint: prefer_material_theme_colors
        Container(color: Colors.blue),

        // expect_lint: prefer_material_theme_colors
        Container(backgroundColor: Colors.red),

        // expect_lint: prefer_material_theme_colors
        Icon(Icons.home, color: Colors.green),

        // GOOD: Theme colors
        Container(color: Theme.of(context).colorScheme.primary),
        Container(color: Theme.of(context).colorScheme.error),
        Icon(Icons.home, color: Theme.of(context).colorScheme.onSurface),
      ],
    );
  }
}

// =============================================================================
// prefer_clip_r_superellipse / prefer_clip_r_superellipse_clipper
// =============================================================================

class ClipRSuperellipseExamples extends StatelessWidget {
  const ClipRSuperellipseExamples({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // BAD: ClipRRect without clipper (prefer_clip_r_superellipse)
        // expect_lint: prefer_clip_r_superellipse
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network('https://example.com/image.png'),
        ),

        // BAD: ClipRRect with only child (prefer_clip_r_superellipse)
        // expect_lint: prefer_clip_r_superellipse
        ClipRRect(
          child: Image.network('https://example.com/image.png'),
        ),

        // BAD: ClipRRect with clipBehavior (prefer_clip_r_superellipse)
        // expect_lint: prefer_clip_r_superellipse
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: Image.network('https://example.com/image.png'),
        ),

        // GOOD: ClipRSuperellipse (already using preferred widget)
        ClipRSuperellipse(
          borderRadius: BorderRadius.circular(10),
          child: Image.network('https://example.com/image.png'),
        ),

        // GOOD: ClipRRect with custom clipper (handled by _clipper rule)
        // expect_lint: prefer_clip_r_superellipse_clipper
        ClipRRect(
          clipper: _MyCustomClipper(),
          child: Image.network('https://example.com/image.png'),
        ),
      ],
    );
  }
}

class _MyCustomClipper extends CustomClipper<RRect> {
  @override
  RRect getClip(Size size) => RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(10),
      );

  @override
  bool shouldReclip(covariant CustomClipper<RRect> oldClipper) => false;
}
