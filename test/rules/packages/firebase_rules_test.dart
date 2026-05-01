import 'dart:io';

import 'package:saropa_lints/src/rules/packages/firebase_rules.dart';
import 'package:test/test.dart';

/// Tests for 29 Firebase and database lint rules.
///
/// These rules cover Firestore query safety, Firebase initialization,
/// database patterns, Analytics naming conventions, Cloud Messaging,
/// Maps integration, Crashlytics, App Check, Auth, and error handling.
///
/// Test fixtures: example_packages/lib/firebase/*
void main() {
  group('Firebase Rules - Rule Instantiation', () {
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
      'AvoidFirestoreUnboundedQueryRule',
      'avoid_firestore_unbounded_query',
      () => AvoidFirestoreUnboundedQueryRule(),
    );

    test('AvoidFirestoreUnboundedQueryRule exposes a quick fix', () {
      expect(AvoidFirestoreUnboundedQueryRule().fixGenerators, isNotEmpty);
    });

    testRule(
      'AvoidDatabaseInBuildRule',
      'avoid_database_in_build',
      () => AvoidDatabaseInBuildRule(),
    );
    testRule(
      'AvoidSecureStorageOnWebRule',
      'avoid_secure_storage_on_web',
      () => AvoidSecureStorageOnWebRule(),
    );
    testRule(
      'RequireFirebaseInitBeforeUseRule',
      'require_firebase_init_before_use',
      () => RequireFirebaseInitBeforeUseRule(),
    );
    testRule(
      'RequireDatabaseMigrationRule',
      'require_database_migration',
      () => RequireDatabaseMigrationRule(),
    );
    testRule(
      'RequireDatabaseIndexRule',
      'require_database_index',
      () => RequireDatabaseIndexRule(),
    );
    testRule(
      'PreferTransactionForBatchRule',
      'prefer_transaction_for_batch',
      () => PreferTransactionForBatchRule(),
    );
    testRule(
      'IncorrectFirebaseEventNameRule',
      'incorrect_firebase_event_name',
      () => IncorrectFirebaseEventNameRule(),
    );
    testRule(
      'IncorrectFirebaseParameterNameRule',
      'incorrect_firebase_parameter_name',
      () => IncorrectFirebaseParameterNameRule(),
    );

    test('IncorrectFirebaseParameterNameRule exposes a quick fix', () {
      expect(IncorrectFirebaseParameterNameRule().fixGenerators, isNotEmpty);
    });

    testRule(
      'PreferFirestoreBatchWriteRule',
      'prefer_firestore_batch_write',
      () => PreferFirestoreBatchWriteRule(),
    );
    testRule(
      'AvoidFirestoreInWidgetBuildRule',
      'avoid_firestore_in_widget_build',
      () => AvoidFirestoreInWidgetBuildRule(),
    );
    testRule(
      'PreferFirebaseRemoteConfigDefaultsRule',
      'prefer_firebase_remote_config_defaults',
      () => PreferFirebaseRemoteConfigDefaultsRule(),
    );
    testRule(
      'RequireFcmTokenRefreshHandlerRule',
      'require_fcm_token_refresh_handler',
      () => RequireFcmTokenRefreshHandlerRule(),
    );
    testRule(
      'RequireBackgroundMessageHandlerRule',
      'require_background_message_handler',
      () => RequireBackgroundMessageHandlerRule(),
    );
    testRule(
      'AvoidMapMarkersInBuildRule',
      'avoid_map_markers_in_build',
      () => AvoidMapMarkersInBuildRule(),
    );
    testRule(
      'RequireMapIdleCallbackRule',
      'require_map_idle_callback',
      () => RequireMapIdleCallbackRule(),
    );
    testRule(
      'PreferMarkerClusteringRule',
      'prefer_marker_clustering',
      () => PreferMarkerClusteringRule(),
    );
    testRule(
      'RequireCrashlyticsUserIdRule',
      'require_crashlytics_user_id',
      () => RequireCrashlyticsUserIdRule(),
    );
    testRule(
      'RequireFirebaseAppCheckRule',
      'require_firebase_app_check',
      () => RequireFirebaseAppCheckRule(),
    );
    testRule(
      'AvoidStoringUserDataInAuthRule',
      'avoid_storing_user_data_in_auth',
      () => AvoidStoringUserDataInAuthRule(),
    );
    testRule(
      'PreferFirebaseAuthPersistenceRule',
      'prefer_firebase_auth_persistence',
      () => PreferFirebaseAuthPersistenceRule(),
    );
    testRule(
      'RequireFirebaseErrorHandlingRule',
      'require_firebase_error_handling',
      () => RequireFirebaseErrorHandlingRule(),
    );
    testRule(
      'AvoidFirebaseRealtimeInBuildRule',
      'avoid_firebase_realtime_in_build',
      () => AvoidFirebaseRealtimeInBuildRule(),
    );
    testRule(
      'RequireFirestoreIndexRule',
      'require_firestore_index',
      () => RequireFirestoreIndexRule(),
    );
    testRule(
      'RequireFirestoreSecurityRulesRule',
      'require_firestore_security_rules',
      () => RequireFirestoreSecurityRulesRule(),
    );
    testRule(
      'RequireFirebaseCompositeIndexRule',
      'require_firebase_composite_index',
      () => RequireFirebaseCompositeIndexRule(),
    );
    testRule(
      'AvoidFirebaseUserDataInAuthRule',
      'avoid_firebase_user_data_in_auth',
      () => AvoidFirebaseUserDataInAuthRule(),
    );
    testRule(
      'RequireFirebaseAppCheckProductionRule',
      'require_firebase_app_check_production',
      () => RequireFirebaseAppCheckProductionRule(),
    );
    testRule(
      'RequireFirebaseReauthenticationRule',
      'require_firebase_reauthentication',
      () => RequireFirebaseReauthenticationRule(),
    );
    testRule(
      'RequireFirebaseTokenRefreshRule',
      'require_firebase_token_refresh',
      () => RequireFirebaseTokenRefreshRule(),
    );
    testRule(
      'PreferFirebaseTransactionForCountersRule',
      'prefer_firebase_transaction_for_counters',
      () => PreferFirebaseTransactionForCountersRule(),
    );
    testRule(
      'PreferCorrectTopicsRule',
      'prefer_correct_topics',
      () => PreferCorrectTopicsRule(),
    );
    testRule(
      'PreferDeepLinkAuthRule',
      'prefer_deep_link_auth',
      () => PreferDeepLinkAuthRule(),
    );
  });
  group('Firebase Rules - Fixture Verification', () {
    test('require_firestore_security_rules fixture exists', () {
      final file = File(
        'example_packages/lib/firebase/require_firestore_security_rules_fixture.dart',
      );
      expect(file.existsSync(), isTrue);
    });

    test('avoid_firebase_user_data_in_auth fixture exists', () {
      final file = File(
        'example_packages/lib/firebase/avoid_firebase_user_data_in_auth_fixture.dart',
      );
      expect(file.existsSync(), isTrue);
    });

    test('incorrect_firebase_event_name fixture exists', () {
      final file = File(
        'example_packages/lib/firebase/incorrect_firebase_event_name_fixture.dart',
      );
      expect(file.existsSync(), isTrue);
    });

    test('incorrect_firebase_parameter_name fixture exists', () {
      final file = File(
        'example_packages/lib/firebase/incorrect_firebase_parameter_name_fixture.dart',
      );
      expect(file.existsSync(), isTrue);
    });

    test('prefer_firebase_auth_persistence fixture exists', () {
      final file = File(
        'example_packages/lib/firebase/prefer_firebase_auth_persistence_fixture.dart',
      );
      expect(file.existsSync(), isTrue);
    });

    test('prefer_firebase_remote_config_defaults fixture exists', () {
      final file = File(
        'example_packages/lib/firebase/'
        'prefer_firebase_remote_config_defaults_fixture.dart',
      );
      expect(file.existsSync(), isTrue);
    });

    test('require_firebase_app_check fixture exists', () {
      final file = File(
        'example_packages/lib/firebase/require_firebase_app_check_fixture.dart',
      );
      expect(file.existsSync(), isTrue);
    });

    test('require_firebase_init_before_use fixture exists', () {
      final file = File(
        'example_packages/lib/firebase/require_firebase_init_before_use_fixture.dart',
      );
      expect(file.existsSync(), isTrue);
    });

    test('require_firebase_composite_index fixture exists', () {
      final file = File(
        'example_packages/lib/firebase/require_firebase_composite_index_fixture.dart',
      );
      expect(file.existsSync(), isTrue);
    });

    test('require_firebase_reauthentication fixture exists', () {
      final file = File(
        'example_packages/lib/firebase/require_firebase_reauthentication_fixture.dart',
      );
      expect(file.existsSync(), isTrue);
    });

    test('require_firebase_token_refresh fixture exists', () {
      final file = File(
        'example_packages/lib/firebase/require_firebase_token_refresh_fixture.dart',
      );
      expect(file.existsSync(), isTrue);
    });

    test('require_firebase_app_check_production fixture exists', () {
      final file = File(
        'example_packages/lib/firebase/require_firebase_app_check_production_fixture.dart',
      );
      expect(file.existsSync(), isTrue);
    });

    test('prefer_firebase_transaction_for_counters fixture exists', () {
      final file = File(
        'example_packages/lib/firebase/prefer_firebase_transaction_for_counters_fixture.dart',
      );
      expect(file.existsSync(), isTrue);
    });

    test('prefer_correct_topics fixture exists', () {
      final file = File(
        'example_packages/lib/firebase/prefer_correct_topics_fixture.dart',
      );
      expect(file.existsSync(), isTrue);
    });

    test('prefer_deep_link_auth fixture exists', () {
      final file = File(
        'example_packages/lib/firebase/prefer_deep_link_auth_fixture.dart',
      );
      expect(file.existsSync(), isTrue);
    });
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata,
  // fixture verification, and quick-fix metadata checks.
}
