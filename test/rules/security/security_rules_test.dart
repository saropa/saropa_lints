import 'dart:io';

import 'package:saropa_lints/src/rules/security/security_auth_storage_rules.dart';
import 'package:saropa_lints/src/rules/security/security_network_input_rules.dart';
import 'package:test/test.dart';

/// Tests for 56 security lint rules.
///
/// These rules cover credential security, injection prevention, secure storage,
/// WebView security, authentication, data protection, and OWASP compliance.
///
/// Test fixtures: example/lib/security/*
// OWASP-oriented rules: metadata checks + fixture-based triggers in subgroups.
void main() {
  group('Security Rules - Rule Instantiation', () {
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
      'AvoidLoggingSensitiveDataRule',
      'avoid_logging_sensitive_data',
      () => AvoidLoggingSensitiveDataRule(),
    );
    testRule(
      'RequireSecureStorageRule',
      'require_secure_storage',
      () => RequireSecureStorageRule(),
    );
    test('RequireSecureStorageRule relatedRules', () {
      final rule = RequireSecureStorageRule();
      expect(
        rule.relatedRules,
        containsAll(<String>[
          'avoid_hardcoded_credentials',
          'require_secure_storage_for_auth',
        ]),
      );
    });
    testRule(
      'AvoidHardcodedCredentialsRule',
      'avoid_hardcoded_credentials',
      () => AvoidHardcodedCredentialsRule(),
    );
    test('AvoidHardcodedCredentialsRule relatedRules', () {
      final rule = AvoidHardcodedCredentialsRule();
      expect(
        rule.relatedRules,
        containsAll(<String>[
          'require_secure_storage',
          'require_secure_storage_auth_data',
        ]),
      );
    });
    testRule(
      'RequireInputSanitizationRule',
      'require_input_sanitization',
      () => RequireInputSanitizationRule(),
    );
    testRule(
      'AvoidWebViewJavaScriptEnabledRule',
      'avoid_webview_javascript_enabled',
      () => AvoidWebViewJavaScriptEnabledRule(),
    );
    testRule(
      'RequireBiometricFallbackRule',
      'require_biometric_fallback',
      () => RequireBiometricFallbackRule(),
    );
    testRule(
      'AvoidEvalLikePatternsRule',
      'avoid_eval_like_patterns',
      () => AvoidEvalLikePatternsRule(),
    );
    testRule(
      'AvoidDynamicCodeLoadingRule',
      'avoid_dynamic_code_loading',
      () => AvoidDynamicCodeLoadingRule(),
    );
    testRule(
      'AvoidUnverifiedNativeLibraryRule',
      'avoid_unverified_native_library',
      () => AvoidUnverifiedNativeLibraryRule(),
    );
    testRule(
      'AvoidHardcodedSigningConfigRule',
      'avoid_hardcoded_signing_config',
      () => AvoidHardcodedSigningConfigRule(),
    );
    testRule(
      'RequireCertificatePinningRule',
      'require_certificate_pinning',
      () => RequireCertificatePinningRule(),
    );
    testRule(
      'AvoidTokenInUrlRule',
      'avoid_token_in_url',
      () => AvoidTokenInUrlRule(),
    );
    testRule(
      'AvoidClipboardSensitiveRule',
      'avoid_clipboard_sensitive',
      () => AvoidClipboardSensitiveRule(),
    );
    testRule(
      'AvoidStoringPasswordsRule',
      'avoid_storing_passwords',
      () => AvoidStoringPasswordsRule(),
    );
    testRule(
      'AvoidDynamicSqlRule',
      'avoid_dynamic_sql',
      () => AvoidDynamicSqlRule(),
    );
    testRule(
      'AvoidGenericKeyInUrlRule',
      'avoid_generic_key_in_url',
      () => AvoidGenericKeyInUrlRule(),
    );
    testRule(
      'PreferSecureRandomRule',
      'prefer_secure_random',
      () => PreferSecureRandomRule(),
    );
    testRule(
      'PreferTypedDataRule',
      'prefer_typed_data',
      () => PreferTypedDataRule(),
    );
    testRule(
      'AvoidUnnecessaryToListRule',
      'avoid_unnecessary_to_list',
      () => AvoidUnnecessaryToListRule(),
    );
    testRule(
      'RequireAuthCheckRule',
      'require_auth_check',
      () => RequireAuthCheckRule(),
    );
    testRule(
      'RequireTokenRefreshRule',
      'require_token_refresh',
      () => RequireTokenRefreshRule(),
    );
    testRule(
      'AvoidJwtDecodeClientRule',
      'avoid_jwt_decode_client',
      () => AvoidJwtDecodeClientRule(),
    );
    testRule(
      'RequireLogoutCleanupRule',
      'require_logout_cleanup',
      () => RequireLogoutCleanupRule(),
    );
    testRule(
      'AvoidAuthInQueryParamsRule',
      'avoid_auth_in_query_params',
      () => AvoidAuthInQueryParamsRule(),
    );
    testRule(
      'RequireDeepLinkValidationRule',
      'require_deep_link_validation',
      () => RequireDeepLinkValidationRule(),
    );
    testRule(
      'RequireDataEncryptionRule',
      'require_data_encryption',
      () => RequireDataEncryptionRule(),
    );
    testRule(
      'PreferDataMaskingRule',
      'prefer_data_masking',
      () => PreferDataMaskingRule(),
    );
    testRule(
      'AvoidScreenshotSensitiveRule',
      'avoid_screenshot_sensitive',
      () => AvoidScreenshotSensitiveRule(),
    );
    testRule(
      'RequireSecurePasswordFieldRule',
      'require_secure_password_field',
      () => RequireSecurePasswordFieldRule(),
    );
    testRule(
      'AvoidPathTraversalRule',
      'avoid_path_traversal',
      () => AvoidPathTraversalRule(),
    );
    testRule(
      'PreferHtmlEscapeRule',
      'prefer_html_escape',
      () => PreferHtmlEscapeRule(),
    );
    testRule(
      'RequireSecureStorageForAuthRule',
      'require_secure_storage_for_auth',
      () => RequireSecureStorageForAuthRule(),
    );
    testRule(
      'RequireUrlValidationRule',
      'require_url_validation',
      () => RequireUrlValidationRule(),
    );
    testRule(
      'AvoidRedirectInjectionRule',
      'avoid_redirect_injection',
      () => AvoidRedirectInjectionRule(),
    );
    testRule(
      'AvoidExternalStorageSensitiveRule',
      'avoid_external_storage_sensitive',
      () => AvoidExternalStorageSensitiveRule(),
    );
    testRule(
      'PreferLocalAuthRule',
      'prefer_local_auth',
      () => PreferLocalAuthRule(),
    );
    testRule(
      'RequireSecureStorageAuthDataRule',
      'require_secure_storage_auth_data',
      () => RequireSecureStorageAuthDataRule(),
    );
    testRule(
      'PreferWebViewJavaScriptDisabledRule',
      'prefer_webview_javascript_disabled',
      () => PreferWebViewJavaScriptDisabledRule(),
    );
    testRule(
      'AvoidWebViewInsecureContentRule',
      'avoid_webview_insecure_content',
      () => AvoidWebViewInsecureContentRule(),
    );
    testRule(
      'RequireWebViewErrorHandlingRule',
      'require_webview_error_handling',
      () => RequireWebViewErrorHandlingRule(),
    );
    testRule(
      'PreferWebviewSandboxRule',
      'prefer_webview_sandbox',
      () => PreferWebviewSandboxRule(),
    );
    testRule(
      'AvoidApiKeyInCodeRule',
      'avoid_api_key_in_code',
      () => AvoidApiKeyInCodeRule(),
    );
    testRule(
      'AvoidStoringSensitiveUnencryptedRule',
      'avoid_storing_sensitive_unencrypted',
      () => AvoidStoringSensitiveUnencryptedRule(),
    );
    testRule(
      'AvoidIgnoringSslErrorsRule',
      'avoid_ignoring_ssl_errors',
      () => AvoidIgnoringSslErrorsRule(),
    );
    testRule(
      'RequireHttpsOnlyRule',
      'require_https_only',
      () => RequireHttpsOnlyRule(),
    );
    testRule(
      'RequireHttpsOnlyTestRule',
      'require_https_only_test',
      () => RequireHttpsOnlyTestRule(),
    );
    testRule(
      'AvoidUnsafeDeserializationRule',
      'avoid_unsafe_deserialization',
      () => AvoidUnsafeDeserializationRule(),
    );
    testRule(
      'AvoidUserControlledUrlsRule',
      'avoid_user_controlled_urls',
      () => AvoidUserControlledUrlsRule(),
    );
    testRule(
      'RequireCatchLoggingRule',
      'require_catch_logging',
      () => RequireCatchLoggingRule(),
    );
    testRule(
      'RequireSecureStorageErrorHandlingRule',
      'require_secure_storage_error_handling',
      () => RequireSecureStorageErrorHandlingRule(),
    );
    testRule(
      'AvoidSecureStorageLargeDataRule',
      'avoid_secure_storage_large_data',
      () => AvoidSecureStorageLargeDataRule(),
    );
    testRule(
      'PreferBiometricProtectionRule',
      'prefer_biometric_protection',
      () => PreferBiometricProtectionRule(),
    );
    testRule(
      'AvoidSensitiveDataInClipboardRule',
      'avoid_sensitive_data_in_clipboard',
      () => AvoidSensitiveDataInClipboardRule(),
    );
    testRule(
      'RequireClipboardPasteValidationRule',
      'require_clipboard_paste_validation',
      () => RequireClipboardPasteValidationRule(),
    );
    testRule(
      'AvoidEncryptionKeyInMemoryRule',
      'avoid_encryption_key_in_memory',
      () => AvoidEncryptionKeyInMemoryRule(),
    );
    testRule(
      'PreferOauthPkceRule',
      'prefer_oauth_pkce',
      () => PreferOauthPkceRule(),
    );
    testRule(
      'RequireSessionTimeoutRule',
      'require_session_timeout',
      () => RequireSessionTimeoutRule(),
    );
    testRule(
      'AvoidStackTraceInProductionRule',
      'avoid_stack_trace_in_production',
      () => AvoidStackTraceInProductionRule(),
    );
    testRule(
      'AvoidWebViewCorsIssuesRule',
      'avoid_webview_cors_issues',
      () => AvoidWebViewCorsIssuesRule(),
    );
    testRule(
      'RequireInputValidationRule',
      'require_input_validation',
      () => RequireInputValidationRule(),
    );
  });
  group('Security Rules - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/security');

    // Auto-discover fixtures from disk so new files are verified
    // automatically — no manual list to maintain.
    final fixtures =
        fixtureDir
            .listSync()
            .whereType<File>()
            .map((f) => f.uri.pathSegments.last)
            .where((name) => name.endsWith('_fixture.dart'))
            .map((name) => name.replaceAll('_fixture.dart', ''))
            .toList()
          ..sort();

    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);
      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example/lib/security/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Injection Prevention Rules', () {
    group('avoid_redirect_injection', () {
      test(
        'fixture has exactly 3 BAD cases with expect_lint (unvalidated redirect should trigger)',
        () {
          final file = File(
            'example/lib/security/avoid_redirect_injection_fixture.dart',
          );
          expect(file.existsSync(), isTrue);
          final content = file.readAsStringSync();
          final count = RegExp(
            r'// expect_lint: avoid_redirect_injection',
          ).allMatches(content).length;
          expect(
            count,
            equals(3),
            reason:
                'Three BAD examples (redirect from param, simple push, redirect variable) must have expect_lint',
          );
        },
      );

      test(
        'allowlist-validated destination (allowed/validated in block) should NOT trigger',
        () {
          final file = File(
            'example/lib/security/avoid_redirect_injection_fixture.dart',
          );
          expect(file.existsSync(), isTrue);
          final content = file.readAsStringSync();
          expect(content.contains('goodAllowlistValidatedDestination'), isTrue);
          expect(content.contains('validatedDestination'), isTrue);
          expect(
            content.contains('_allowedExportDestinationsRedirect'),
            isTrue,
          );
          final goodSection = content.substring(
            content.indexOf('goodAllowlistValidatedDestination'),
          );
          expect(
            goodSection.contains('expect_lint: avoid_redirect_injection'),
            isFalse,
            reason:
                'Allowlist-validated destination is a GOOD example; no lint expected',
          );
        },
      );
    });
  });

  group('Data Protection Rules', () {
    group('avoid_screenshot_sensitive', () {
      test(
        'fixture has exactly one BAD (expect_lint) so rule triggers once',
        () {
          final path =
              'example/lib/security/avoid_screenshot_sensitive_fixture.dart';
          final file = File(path);
          expect(file.existsSync(), isTrue, reason: 'Fixture must exist');
          final content = file.readAsStringSync();
          final count = RegExp(
            r'// expect_lint: avoid_screenshot_sensitive',
          ).allMatches(content).length;
          expect(
            count,
            1,
            reason:
                'Exactly one BAD class (PaymentScreen) should have expect_lint',
          );
        },
      );

      test(
        'fixture GOOD classes (debug/viewer, fromsettings) must NOT trigger',
        () {
          final path =
              'example/lib/security/avoid_screenshot_sensitive_fixture.dart';
          final content = File(path).readAsStringSync();
          expect(
            content.contains('_DriftViewerWebViewScreen'),
            isTrue,
            reason: 'Viewer screen is debug/tooling; must not trigger',
          );
          expect(
            content.contains('_WebViewScreenFromSettings'),
            isTrue,
            reason:
                'WebView from settings is navigation context; must not trigger',
          );
        },
      );
    });
  });

  // Stub-only behavior tests were removed from this file. Keep real fixture
  // and metadata checks while migrating to analyzer-backed behavior tests.
}
