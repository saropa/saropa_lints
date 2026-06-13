import 'dart:io';

import 'package:test/test.dart';

// The former package_specific_rules.dart was split into per-package files. These
// 16 files now hold the 19 rules this suite pins. Importing them directly (rather
// than the rules barrel) keeps the suite compilable and runnable independent of
// unrelated rule files in the package.
import 'package:saropa_lints/src/rules/packages/app_links_rules.dart';
import 'package:saropa_lints/src/rules/packages/device_calendar_rules.dart';
import 'package:saropa_lints/src/rules/packages/envied_rules.dart';
import 'package:saropa_lints/src/rules/packages/firebase_rules.dart';
import 'package:saropa_lints/src/rules/packages/flutter_keyboard_visibility_rules.dart';
import 'package:saropa_lints/src/rules/packages/flutter_svg_rules.dart';
import 'package:saropa_lints/src/rules/packages/geolocator_rules.dart';
import 'package:saropa_lints/src/rules/packages/google_fonts_rules.dart';
import 'package:saropa_lints/src/rules/packages/google_sign_in_rules.dart';
import 'package:saropa_lints/src/rules/packages/image_picker_rules.dart';
import 'package:saropa_lints/src/rules/packages/openai_rules.dart';
import 'package:saropa_lints/src/rules/packages/sign_in_with_apple_rules.dart';
import 'package:saropa_lints/src/rules/packages/speech_to_text_rules.dart';
import 'package:saropa_lints/src/rules/packages/url_launcher_rules.dart';
import 'package:saropa_lints/src/rules/packages/uuid_rules.dart';
import 'package:saropa_lints/src/rules/packages/webview_flutter_rules.dart';

/// Tests for 19 Package Specific lint rules.
///
/// Test fixtures: example_packages/lib/package_specific/*
void main() {
  group('Package Specific Rules - Rule Instantiation', () {
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
      'RequireGoogleSigninErrorHandlingRule',
      'require_google_signin_error_handling',
      () => RequireGoogleSigninErrorHandlingRule(),
    );

    testRule(
      'RequireAppleSigninNonceRule',
      'require_apple_signin_nonce',
      () => RequireAppleSigninNonceRule(),
    );

    testRule(
      'RequireWebviewSslErrorHandlingRule',
      'require_webview_ssl_error_handling',
      () => RequireWebviewSslErrorHandlingRule(),
    );

    testRule(
      'AvoidWebviewFileAccessRule',
      'avoid_webview_file_access',
      () => AvoidWebviewFileAccessRule(),
    );

    testRule(
      'RequireCalendarTimezoneHandlingRule',
      'require_calendar_timezone_handling',
      () => RequireCalendarTimezoneHandlingRule(),
    );

    testRule(
      'RequireKeyboardVisibilityDisposeRule',
      'require_keyboard_visibility_dispose',
      () => RequireKeyboardVisibilityDisposeRule(),
    );

    testRule(
      'RequireSpeechStopOnDisposeRule',
      'require_speech_stop_on_dispose',
      () => RequireSpeechStopOnDisposeRule(),
    );

    testRule(
      'AvoidAppLinksSensitiveParamsRule',
      'avoid_app_links_sensitive_params',
      () => AvoidAppLinksSensitiveParamsRule(),
    );

    testRule(
      'RequireEnviedObfuscationRule',
      'require_envied_obfuscation',
      () => RequireEnviedObfuscationRule(),
    );

    testRule(
      'AvoidOpenaiKeyInCodeRule',
      'avoid_openai_key_in_code',
      () => AvoidOpenaiKeyInCodeRule(),
    );

    testRule(
      'RequireOpenaiErrorHandlingRule',
      'require_openai_error_handling',
      () => RequireOpenaiErrorHandlingRule(),
    );

    testRule(
      'RequireSvgErrorHandlerRule',
      'require_svg_error_handler',
      () => RequireSvgErrorHandlerRule(),
    );

    testRule(
      'RequireGoogleFontsFallbackRule',
      'require_google_fonts_fallback',
      () => RequireGoogleFontsFallbackRule(),
    );

    testRule('PreferUuidV4Rule', 'prefer_uuid_v4', () => PreferUuidV4Rule());

    testRule(
      'PreferImagePickerMaxDimensionsRule',
      'prefer_image_picker_max_dimensions',
      () => PreferImagePickerMaxDimensionsRule(),
    );

    testRule(
      'RequireUrlLauncherModeRule',
      'require_url_launcher_mode',
      () => RequireUrlLauncherModeRule(),
    );

    testRule(
      'PreferGeolocatorDistanceFilterRule',
      'prefer_geolocator_distance_filter',
      () => PreferGeolocatorDistanceFilterRule(),
    );

    testRule(
      'AvoidImagePickerQuickSuccessionRule',
      'avoid_image_picker_quick_succession',
      () => AvoidImagePickerQuickSuccessionRule(),
    );

    testRule(
      'RequireAnalyticsErrorHandlingRule',
      'require_analytics_error_handling',
      () => RequireAnalyticsErrorHandlingRule(),
    );
  });

  group('Package Specific Rules - Fixture Verification', () {
    final fixtures = [
      'require_google_signin_error_handling',
      'require_apple_signin_nonce',
      'require_webview_ssl_error_handling',
      'avoid_webview_file_access',
      'require_calendar_timezone_handling',
      'require_keyboard_visibility_dispose',
      'require_speech_stop_on_dispose',
      'avoid_app_links_sensitive_params',
      'require_envied_obfuscation',
      'avoid_openai_key_in_code',
      'require_openai_error_handling',
      'require_svg_error_handler',
      'require_google_fonts_fallback',
      'prefer_uuid_v4',
      'prefer_image_picker_max_dimensions',
      'require_url_launcher_mode',
      'prefer_geolocator_distance_filter',
      'avoid_image_picker_quick_succession',
      'require_analytics_error_handling',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/package_specific/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata
  // and fixture verification while migrating to analyzer-backed behavior tests.
}
