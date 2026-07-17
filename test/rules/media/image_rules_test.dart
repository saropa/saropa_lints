import 'dart:io';

import 'package:saropa_lints/src/rules/media/image_rules.dart';
import 'package:test/test.dart';
import '../../helpers/fixture_discovery.dart';

/// Tests for 21 Image lint rules.
///
/// Test fixtures: example/lib/image/*
void main() {
  group('Image Rules - Rule Instantiation', () {
    void testRule(String name, String codeName, dynamic Function() create) {
      test(name, () {
        final rule = create();
        expect(rule.code.lowerCaseName, codeName);
        expect(rule.code.problemMessage, contains('[$codeName]'));
        expect(rule.code.problemMessage.length, greaterThan(50));
        expect(rule.code.correctionMessage, isNotNull);
      });
    }

    testRule(
      'AvoidImageRebuildOnScrollRule',
      'avoid_image_rebuild_on_scroll',
      () => AvoidImageRebuildOnScrollRule(),
    );
    testRule(
      'RequireAvatarFallbackRule',
      'require_avatar_fallback',
      () => RequireAvatarFallbackRule(),
    );
    testRule(
      'PreferVideoLoadingPlaceholderRule',
      'prefer_video_loading_placeholder',
      () => PreferVideoLoadingPlaceholderRule(),
    );
    testRule(
      'PreferImageSizeConstraintsRule',
      'prefer_image_size_constraints',
      () => PreferImageSizeConstraintsRule(),
    );
    testRule(
      'RequireImageErrorFallbackRule',
      'require_image_error_fallback',
      () => RequireImageErrorFallbackRule(),
    );
    testRule(
      'RequireImageLoadingPlaceholderRule',
      'require_image_loading_placeholder',
      () => RequireImageLoadingPlaceholderRule(),
    );
    testRule(
      'RequireMediaLoadingStateRule',
      'require_media_loading_state',
      () => RequireMediaLoadingStateRule(),
    );
    testRule(
      'RequirePdfLoadingIndicatorRule',
      'require_pdf_loading_indicator',
      () => RequirePdfLoadingIndicatorRule(),
    );
    testRule(
      'PreferClipboardFeedbackRule',
      'prefer_clipboard_feedback',
      () => PreferClipboardFeedbackRule(),
    );
    testRule(
      'RequireCachedImageDimensionsRule',
      'require_cached_image_dimensions',
      () => RequireCachedImageDimensionsRule(),
    );
    testRule(
      'RequireCachedImagePlaceholderRule',
      'require_cached_image_placeholder',
      () => RequireCachedImagePlaceholderRule(),
    );
    testRule(
      'RequireCachedImageErrorWidgetRule',
      'require_cached_image_error_widget',
      () => RequireCachedImageErrorWidgetRule(),
    );
    testRule(
      'RequireExifHandlingRule',
      'require_exif_handling',
      () => RequireExifHandlingRule(),
    );
    testRule(
      'PreferCachedImageFadeAnimationRule',
      'prefer_cached_image_fade_animation',
      () => PreferCachedImageFadeAnimationRule(),
    );
    testRule(
      'RequireImageStreamDisposeRule',
      'require_image_stream_dispose',
      () => RequireImageStreamDisposeRule(),
    );
    testRule(
      'PreferImagePickerRequestFullMetadataRule',
      'prefer_image_picker_request_full_metadata',
      () => PreferImagePickerRequestFullMetadataRule(),
    );
    testRule(
      'AvoidImagePickerLargeFilesRule',
      'avoid_image_picker_large_files',
      () => AvoidImagePickerLargeFilesRule(),
    );
    testRule(
      'PreferCachedImageCacheManagerRule',
      'prefer_cached_image_cache_manager',
      () => PreferCachedImageCacheManagerRule(),
    );
    testRule(
      'RequireImageCacheDimensionsRule',
      'require_image_cache_dimensions',
      () => RequireImageCacheDimensionsRule(),
    );
    testRule(
      'RequireCachedImageDevicePixelRatioRule',
      'require_cached_image_device_pixel_ratio',
      () => RequireCachedImageDevicePixelRatioRule(),
    );
    testRule(
      'AvoidCachedImageUnboundedListRule',
      'avoid_cached_image_unbounded_list',
      () => AvoidCachedImageUnboundedListRule(),
    );
    testRule(
      'AvoidCachedImageWebRule',
      'avoid_cached_image_web',
      () => AvoidCachedImageWebRule(),
    );
  });
  group('Image Rules - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/image');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);
      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example/lib/image/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata
  // and fixture verification while migrating to analyzer-backed behavior tests.
}
