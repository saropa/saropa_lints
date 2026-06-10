import 'dart:io';

import 'package:saropa_lints/src/rules/core/compound_performance_rules.dart';
import 'package:test/test.dart';

/// Tests for the 6 compound (context-aware) performance lint rules.
///
/// These rules flag an expensive widget ONLY when nested inside a parent that
/// makes the cost recur (per animation frame or per scrolled item). The
/// instantiation pins assert rule metadata; behavior is verified against the
/// fixtures via the scan CLI (see example/lib/performance/*).
void main() {
  group('Compound Performance Rules - Rule Instantiation', () {
    void testRule(String name, String codeName, dynamic Function() create) {
      test(name, () {
        final rule = create();
        expect(rule.code.lowerCaseName, codeName);
        expect(rule.code.problemMessage, contains('[$codeName]'));
        // Project convention: problem messages are descriptive (>200 chars).
        expect(rule.code.problemMessage.length, greaterThan(200));
        expect(rule.code.correctionMessage, isNotNull);
      });
    }

    testRule(
      'AvoidOpacityInAnimatedBuilderRule',
      'avoid_opacity_in_animated_builder',
      () => AvoidOpacityInAnimatedBuilderRule(),
    );
    testRule(
      'AvoidOpacityInScrollableRule',
      'avoid_opacity_in_scrollable',
      () => AvoidOpacityInScrollableRule(),
    );
    testRule(
      'AvoidBackdropFilterInScrollableRule',
      'avoid_backdrop_filter_in_scrollable',
      () => AvoidBackdropFilterInScrollableRule(),
    );
    testRule(
      'AvoidShaderMaskInScrollableRule',
      'avoid_shader_mask_in_scrollable',
      () => AvoidShaderMaskInScrollableRule(),
    );
    testRule(
      'AvoidImageFilterInScrollableRule',
      'avoid_image_filter_in_scrollable',
      () => AvoidImageFilterInScrollableRule(),
    );
    testRule(
      'AvoidClipPathInAnimatedBuilderRule',
      'avoid_clip_path_in_animated_builder',
      () => AvoidClipPathInAnimatedBuilderRule(),
    );
  });

  group('Compound Performance Rules - Fixture Verification', () {
    const fixtures = [
      'avoid_opacity_in_animated_builder',
      'avoid_opacity_in_scrollable',
      'avoid_backdrop_filter_in_scrollable',
      'avoid_shader_mask_in_scrollable',
      'avoid_image_filter_in_scrollable',
      'avoid_clip_path_in_animated_builder',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example/lib/performance/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });
}
