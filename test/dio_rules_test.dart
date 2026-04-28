import 'dart:io';

import 'package:saropa_lints/src/rules/packages/dio_rules.dart';
import 'package:test/test.dart';

/// Tests for 14 Dio lint rules.
///
/// Test fixtures: example_packages/lib/dio/*
void main() {
  group('Dio Rules - Rule Instantiation', () {
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
      'RequireDioTimeoutRule',
      'require_dio_timeout',
      () => RequireDioTimeoutRule(),
    );
    testRule(
      'RequireDioErrorHandlingRule',
      'require_dio_error_handling',
      () => RequireDioErrorHandlingRule(),
    );
    testRule(
      'RequireDioInterceptorErrorHandlerRule',
      'require_dio_interceptor_error_handler',
      () => RequireDioInterceptorErrorHandlerRule(),
    );
    testRule(
      'PreferDioCancelTokenRule',
      'prefer_dio_cancel_token',
      () => PreferDioCancelTokenRule(),
    );
    testRule(
      'RequireDioSslPinningRule',
      'require_dio_ssl_pinning',
      () => RequireDioSslPinningRule(),
    );
    testRule(
      'AvoidDioFormDataLeakRule',
      'avoid_dio_form_data_leak',
      () => AvoidDioFormDataLeakRule(),
    );
    testRule(
      'AvoidDioDebugPrintProductionRule',
      'avoid_dio_debug_print_production',
      () => AvoidDioDebugPrintProductionRule(),
    );
    testRule(
      'RequireDioSingletonRule',
      'require_dio_singleton',
      () => RequireDioSingletonRule(),
    );
    testRule(
      'PreferDioBaseOptionsRule',
      'prefer_dio_base_options',
      () => PreferDioBaseOptionsRule(),
    );
    testRule(
      'AvoidDioWithoutBaseUrlRule',
      'avoid_dio_without_base_url',
      () => AvoidDioWithoutBaseUrlRule(),
    );
    testRule(
      'PreferDioOverHttpRule',
      'prefer_dio_over_http',
      () => PreferDioOverHttpRule(),
    );
    testRule(
      'RequireDioResponseTypeRule',
      'require_dio_response_type',
      () => RequireDioResponseTypeRule(),
    );
    testRule(
      'RequireDioRetryInterceptorRule',
      'require_dio_retry_interceptor',
      () => RequireDioRetryInterceptorRule(),
    );
    testRule(
      'PreferDioTransformerRule',
      'prefer_dio_transformer',
      () => PreferDioTransformerRule(),
    );
  });
  group('Dio Rules - Fixture Verification', () {
    final fixtures = [
      'require_dio_timeout',
      'require_dio_error_handling',
      'require_dio_interceptor_error_handler',
      'prefer_dio_cancel_token',
      'require_dio_ssl_pinning',
      'avoid_dio_form_data_leak',
      'avoid_dio_debug_print_production',
      'require_dio_singleton',
      'prefer_dio_base_options',
      'avoid_dio_without_base_url',
      'prefer_dio_over_http',
      'require_dio_response_type',
      'require_dio_retry_interceptor',
      'prefer_dio_transformer',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example_packages/lib/dio/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata
  // and fixture verification while migrating to analyzer-backed behavior tests.
}
