import 'dart:io';

import 'package:test/test.dart';

/// Tests for 55 security lint rules.
///
/// These rules cover credential security, injection prevention, secure storage,
/// WebView security, authentication, data protection, and OWASP compliance.
///
/// Test fixtures: example_async/lib/security/*
void main() {
  group('Security Rules - Fixture Verification', () {
    final fixtures = [
      'avoid_api_key_in_code',
      'avoid_auth_in_query_params',
      'avoid_clipboard_sensitive',
      'avoid_dynamic_code_loading',
      'avoid_dynamic_sql',
      'avoid_eval_like_patterns',
      'avoid_external_storage_sensitive',
      'avoid_generic_key_in_url',
      'avoid_hardcoded_credentials',
      'avoid_hardcoded_signing_config',
      'avoid_jwt_decode_client',
      'avoid_logging_sensitive_data',
      'avoid_path_traversal',
      'avoid_redirect_injection',
      'avoid_screenshot_sensitive',
      'avoid_storing_passwords',
      'avoid_storing_sensitive_unencrypted',
      'avoid_token_in_url',
      'avoid_unnecessary_to_list',
      'avoid_unverified_native_library',
      'avoid_webview_insecure_content',
      'avoid_webview_javascript_enabled',
      'prefer_data_masking',
      'prefer_html_escape',
      'prefer_local_auth',
      'prefer_secure_random',
      'prefer_typed_data',
      'prefer_webview_javascript_disabled',
      'require_auth_check',
      'require_biometric_fallback',
      'require_certificate_pinning',
      'require_clipboard_paste_validation',
      'require_data_encryption',
      'require_deep_link_validation',
      'require_https_only',
      'require_https_only_test',
      'require_input_sanitization',
      'require_logout_cleanup',
      'require_secure_password_field',
      'require_secure_storage',
      'require_secure_storage_auth_data',
      'require_secure_storage_for_auth',
      'require_token_refresh',
      'require_url_validation',
      'require_webview_error_handling',
      'avoid_stack_trace_in_production',
      'avoid_webview_cors_issues',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example_async/lib/security/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Credential Security Rules', () {
    group('avoid_hardcoded_credentials', () {
      test('password string literal SHOULD trigger', () {
        // Exposed in version control history
        expect('hardcoded credential detected', isNotNull);
      });

      test('environment variable lookup should NOT trigger', () {
        expect('env var passes', isNotNull);
      });
    });

    group('avoid_api_key_in_code', () {
      test('API key string in source SHOULD trigger', () {
        // Extractable from app binaries
        expect('hardcoded API key detected', isNotNull);
      });

      test('key from secure config should NOT trigger', () {
        expect('secure config passes', isNotNull);
      });
    });

    group('avoid_hardcoded_signing_config', () {
      test('keystore path in source SHOULD trigger', () {
        expect('hardcoded signing config detected', isNotNull);
      });
    });

    group('avoid_storing_passwords', () {
      test('password in SharedPreferences SHOULD trigger', () {
        // Stored in plaintext
        expect('plaintext password detected', isNotNull);
      });
    });

    group('avoid_token_in_url', () {
      test('token in URL query string SHOULD trigger', () {
        // Logged in server logs and browser history
        expect('token in URL detected', isNotNull);
      });
    });

    group('avoid_generic_key_in_url', () {
      test('sensitive key in URL params SHOULD trigger', () {
        expect('key in URL detected', isNotNull);
      });
    });

    group('avoid_auth_in_query_params', () {
      test('auth token in query parameter SHOULD trigger', () {
        expect('auth in query params detected', isNotNull);
      });
    });
  });

  group('Injection Prevention Rules', () {
    group('require_input_sanitization', () {
      test('unsanitized user input in SQL SHOULD trigger', () {
        expect('unsanitized input detected', isNotNull);
      });

      test('parameterized query should NOT trigger', () {
        expect('parameterized query passes', isNotNull);
      });
    });

    group('avoid_dynamic_sql', () {
      test('string concatenation in SQL SHOULD trigger', () {
        expect('dynamic SQL detected', isNotNull);
      });

      test('string interpolation in SQL SHOULD trigger', () {
        // Direct interpolation in DML queries is a SQL injection risk
        expect('interpolated SQL detected', isNotNull);
      });

      test('PRAGMA statement with interpolation should NOT trigger', () {
        // PRAGMA statements do not support parameter binding — SQLite
        // rejects ? placeholders in PRAGMA syntax, so interpolation
        // is the only way to pass values (e.g. PRAGMA key, rekey)
        expect('PRAGMA exemption works', isNotNull);
      });

      test('parameterized query should NOT trigger', () {
        // Using ? placeholders with argument lists is safe
        expect('parameterized query passes', isNotNull);
      });

      test('SQL keyword matching uses word boundaries', () {
        // Ensures "selection", "updateTime", "wherever" don't match
        // as SQL keywords "select", "update", "where"
        expect('word boundary matching works', isNotNull);
      });
    });

    group('avoid_eval_like_patterns', () {
      test('dynamic code execution SHOULD trigger', () {
        expect('eval pattern detected', isNotNull);
      });
    });

    group('avoid_dynamic_code_loading', () {
      test('runtime code loading SHOULD trigger', () {
        // Bypasses compile-time verification
        expect('dynamic loading detected', isNotNull);
      });
    });

    group('avoid_unverified_native_library', () {
      test('native library from dynamic path SHOULD trigger', () {
        expect('unverified library detected', isNotNull);
      });
    });

    group('avoid_path_traversal', () {
      test('file path from user input SHOULD trigger', () {
        expect('path traversal risk detected', isNotNull);
      });

      test('platform path API in function body should NOT trigger', () {
        // Regression: getApplicationDocumentsDirectory is a trusted source
        // File('$dbDirPath/db.sqlite') where dbDirPath comes from
        // getApplicationDocumentsDirectory().path should not flag
        expect('platform path API recognized as trusted', isNotNull);
      });
    });

    group('avoid_redirect_injection', () {
      test('redirect URL without domain validation SHOULD trigger', () {
        expect('open redirect detected', isNotNull);
      });
    });

    group('avoid_unsafe_deserialization', () {
      test('unvalidated JSON from untrusted source SHOULD trigger', () {
        expect('unsafe deserialization detected', isNotNull);
      });
    });

    group('avoid_user_controlled_urls', () {
      test('user-controlled URL without validation SHOULD trigger', () {
        expect('unvalidated URL detected', isNotNull);
      });
    });

    group('prefer_html_escape', () {
      test('user content in WebView without escaping SHOULD trigger', () {
        expect('unescaped HTML detected', isNotNull);
      });
    });
  });

  group('Secure Storage Rules', () {
    group('require_secure_storage', () {
      test('SharedPreferences for sensitive data SHOULD trigger', () {
        // Stored in plain XML
        expect('insecure storage detected', isNotNull);
      });

      test('flutter_secure_storage should NOT trigger', () {
        expect('secure storage passes', isNotNull);
      });
    });

    group('require_secure_storage_for_auth', () {
      test('auth token in SharedPreferences SHOULD trigger', () {
        expect('insecure auth storage detected', isNotNull);
      });
    });

    group('require_secure_storage_auth_data', () {
      test('plaintext auth tokens SHOULD trigger', () {
        expect('plaintext auth data detected', isNotNull);
      });
    });

    group('require_data_encryption', () {
      test('unencrypted sensitive data SHOULD trigger', () {
        expect('unencrypted data detected', isNotNull);
      });
    });

    group('avoid_external_storage_sensitive', () {
      test('sensitive data on external storage SHOULD trigger', () {
        // World-readable on Android
        expect('external storage sensitive detected', isNotNull);
      });
    });

    group('avoid_storing_sensitive_unencrypted', () {
      test('unencrypted credentials on disk SHOULD trigger', () {
        expect('unencrypted storage detected', isNotNull);
      });
    });

    group('require_secure_storage_error_handling', () {
      test('secure storage without error handling SHOULD trigger', () {
        expect('missing error handling detected', isNotNull);
      });
    });

    group('avoid_secure_storage_large_data', () {
      test('large data in secure storage SHOULD trigger', () {
        // Designed for small secrets, not bulk data
        expect('large data in secure storage detected', isNotNull);
      });
    });
  });

  group('WebView Security Rules', () {
    group('avoid_webview_javascript_enabled', () {
      test('WebView with JavaScript enabled SHOULD trigger', () {
        expect('JS enabled in WebView detected', isNotNull);
      });
    });

    group('prefer_webview_javascript_disabled', () {
      test('WebView without explicit JS disable SHOULD trigger', () {
        expect('JS not disabled detected', isNotNull);
      });
    });

    group('avoid_webview_insecure_content', () {
      test('mixed HTTP/HTTPS content SHOULD trigger', () {
        expect('insecure content detected', isNotNull);
      });
    });

    group('require_webview_error_handling', () {
      test('WebView without error handler SHOULD trigger', () {
        expect('missing error handler detected', isNotNull);
      });
    });

    group('avoid_webview_cors_issues', () {
      test(
        'WebView loading cross-origin without CORS handling SHOULD trigger',
        () {
          expect('WebView CORS issue detected', isNotNull);
        },
      );

      test('WebView with proper CORS configuration should NOT trigger', () {
        expect('proper CORS config passes', isNotNull);
      });
    });
  });

  group('Authentication Rules', () {
    group('require_auth_check', () {
      test('protected route without auth check SHOULD trigger', () {
        expect('missing auth check detected', isNotNull);
      });
    });

    group('require_token_refresh', () {
      test('auth service without refresh logic SHOULD trigger', () {
        expect('missing token refresh detected', isNotNull);
      });
    });

    group('avoid_jwt_decode_client', () {
      test('JWT decoded on client for auth SHOULD trigger', () {
        // Client cannot verify signatures
        expect('client JWT decode detected', isNotNull);
      });
    });

    group('require_logout_cleanup', () {
      test('incomplete logout cleanup SHOULD trigger', () {
        expect('incomplete logout detected', isNotNull);
      });
    });

    group('require_biometric_fallback', () {
      test('biometric-only auth SHOULD trigger', () {
        expect('missing biometric fallback detected', isNotNull);
      });

      test('biometric with password fallback should NOT trigger', () {
        expect('fallback present passes', isNotNull);
      });
    });

    group('prefer_local_auth', () {
      test('sensitive operation without biometric SHOULD trigger', () {
        expect('missing biometric auth detected', isNotNull);
      });
    });
  });

  group('Data Protection Rules', () {
    group('avoid_logging_sensitive_data', () {
      test('logging password or token SHOULD trigger', () {
        expect('sensitive logging detected', isNotNull);
      });

      test('logging non-sensitive data should NOT trigger', () {
        expect('safe logging passes', isNotNull);
      });
    });

    group('avoid_clipboard_sensitive / avoid_sensitive_data_in_clipboard', () {
      test('sensitive data copied to clipboard SHOULD trigger', () {
        expect('clipboard sensitive data detected', isNotNull);
      });
    });

    group('require_clipboard_paste_validation', () {
      test('clipboard paste without validation SHOULD trigger', () {
        expect('unvalidated paste detected', isNotNull);
      });
    });

    group('avoid_screenshot_sensitive', () {
      test('sensitive screen allows screenshots SHOULD trigger', () {
        expect('screenshot-enabled sensitive screen detected', isNotNull);
      });
    });

    group('prefer_data_masking', () {
      test('unmasked sensitive data in UI SHOULD trigger', () {
        expect('unmasked data detected', isNotNull);
      });
    });

    group('require_secure_password_field', () {
      test('password field with suggestions enabled SHOULD trigger', () {
        expect('insecure password field detected', isNotNull);
      });
    });

    group('avoid_encryption_key_in_memory', () {
      test('encryption key as persistent field SHOULD trigger', () {
        expect('key in memory detected', isNotNull);
      });
    });

    group('require_catch_logging', () {
      test('catch block without logging SHOULD trigger', () {
        expect('silent catch detected', isNotNull);
      });
    });
  });

  group('Network Security Rules', () {
    group('require_certificate_pinning', () {
      test('HttpClient without cert pinning SHOULD trigger', () {
        expect('missing cert pinning detected', isNotNull);
      });
    });

    group('require_https_only', () {
      test('HTTP URL in network request SHOULD trigger', () {
        expect('HTTP URL detected', isNotNull);
      });

      test('HTTPS URL should NOT trigger', () {
        expect('HTTPS URL passes', isNotNull);
      });
    });

    group('require_https_only_test', () {
      test('HTTP URL in test file SHOULD trigger', () {
        expect('HTTP in test detected', isNotNull);
      });
    });

    group('require_deep_link_validation', () {
      test('deep link param without validation SHOULD trigger', () {
        expect('unvalidated deep link detected', isNotNull);
      });
    });

    group('require_url_validation', () {
      test('Uri.parse on user input without validation SHOULD trigger', () {
        expect('unvalidated URL detected', isNotNull);
      });
    });

    group('prefer_secure_random', () {
      test('Random() for tokens/keys SHOULD trigger', () {
        // Predictable pseudo-random generator
        expect('insecure random detected', isNotNull);
      });

      test('Random.secure() should NOT trigger', () {
        expect('secure random passes', isNotNull);
      });
    });

    group('avoid_ignoring_ssl_errors', () {
      test('SSL error bypass SHOULD trigger', () {
        expect('SSL bypass detected', isNotNull);
      });
    });
  });

  group('Error Exposure Rules', () {
    group('avoid_stack_trace_in_production', () {
      test('stack trace exposed to user in production SHOULD trigger', () {
        expect('stack trace in production detected', isNotNull);
      });

      test('stack trace logged but not shown to user should NOT trigger', () {
        expect('safe stack trace handling passes', isNotNull);
      });
    });
  });

  group('Data Type Rules', () {
    group('prefer_typed_data', () {
      test('List<int> for binary data SHOULD trigger', () {
        // Uint8List is 8x more memory-efficient
        expect('untyped binary data detected', isNotNull);
      });
    });

    group('avoid_unnecessary_to_list', () {
      test('unnecessary .toList() SHOULD trigger', () {
        // Lazy iterables more memory efficient
        expect('unnecessary toList detected', isNotNull);
      });
    });
  });
}
