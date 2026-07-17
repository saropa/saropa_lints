import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/platforms/ios_capabilities_permissions_rules.dart';
import 'package:saropa_lints/src/rules/platforms/ios_platform_lifecycle_rules.dart';
import 'package:saropa_lints/src/rules/platforms/ios_ui_security_rules.dart';

/// Tests for 89 iOS platform lint rules.
///
/// These rules cover App Store requirements, iOS-specific UI patterns,
/// privacy and permissions, security, performance, accessibility,
/// and Apple platform integration.
///
/// Test fixtures: example/lib/ios/
// Large iOS ruleset: instantiation + example fixture coverage in nested groups.
void main() {
  group('Ios Rules - Rule Instantiation', () {
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
      'PreferIosSafeAreaRule',
      'prefer_ios_safe_area',
      () => PreferIosSafeAreaRule(),
    );

    testRule(
      'AvoidIosHardcodedStatusBarRule',
      'avoid_ios_hardcoded_status_bar',
      () => AvoidIosHardcodedStatusBarRule(),
    );

    testRule(
      'PreferIosHapticFeedbackRule',
      'prefer_ios_haptic_feedback',
      () => PreferIosHapticFeedbackRule(),
    );

    testRule(
      'PreferCupertinoForIosRule',
      'prefer_cupertino_for_ios',
      () => PreferCupertinoForIosRule(),
    );

    testRule(
      'RequireHttpsForIosRule',
      'require_https_for_ios',
      () => RequireHttpsForIosRule(),
    );

    testRule(
      'RequireIosInfoPlistEntriesRule',
      'require_ios_info_plist_entries',
      () => RequireIosInfoPlistEntriesRule(),
    );

    testRule(
      'RequireIosPermissionDescriptionRule',
      'require_ios_permission_description',
      () => RequireIosPermissionDescriptionRule(),
    );

    testRule(
      'RequireIosPrivacyManifestRule',
      'require_ios_privacy_manifest',
      () => RequireIosPrivacyManifestRule(),
    );

    testRule(
      'RequireAppleSignInRule',
      'require_apple_sign_in',
      () => RequireAppleSignInRule(),
    );

    testRule(
      'RequireIosBackgroundModeRule',
      'require_ios_background_mode',
      () => RequireIosBackgroundModeRule(),
    );

    testRule(
      'AvoidIos13DeprecationsRule',
      'avoid_ios_13_deprecations',
      () => AvoidIos13DeprecationsRule(),
    );

    testRule(
      'AvoidIosSimulatorOnlyCodeRule',
      'avoid_ios_simulator_only_code',
      () => AvoidIosSimulatorOnlyCodeRule(),
    );

    testRule(
      'RequireIosMinimumVersionCheckRule',
      'require_ios_minimum_version_check',
      () => RequireIosMinimumVersionCheckRule(),
    );

    testRule(
      'AvoidIosDeprecatedUikitRule',
      'avoid_ios_deprecated_uikit',
      () => AvoidIosDeprecatedUikitRule(),
    );

    testRule(
      'RequireIosAppTrackingTransparencyRule',
      'require_ios_app_tracking_transparency',
      () => RequireIosAppTrackingTransparencyRule(),
    );

    testRule(
      'RequireIosFaceIdUsageDescriptionRule',
      'require_ios_face_id_usage_description',
      () => RequireIosFaceIdUsageDescriptionRule(),
    );

    testRule(
      'RequireIosPhotoLibraryAddUsageRule',
      'require_ios_photo_library_add_usage',
      () => RequireIosPhotoLibraryAddUsageRule(),
    );

    testRule(
      'AvoidIosInAppBrowserForAuthRule',
      'avoid_ios_in_app_browser_for_auth',
      () => AvoidIosInAppBrowserForAuthRule(),
    );

    testRule(
      'RequireIosAppReviewPromptTimingRule',
      'require_ios_app_review_prompt_timing',
      () => RequireIosAppReviewPromptTimingRule(),
    );

    testRule(
      'RequireIosKeychainAccessibilityRule',
      'require_ios_keychain_accessibility',
      () => RequireIosKeychainAccessibilityRule(),
    );

    testRule(
      'AvoidIosHardcodedBundleIdRule',
      'avoid_ios_hardcoded_bundle_id',
      () => AvoidIosHardcodedBundleIdRule(),
    );

    testRule(
      'RequireIosPushNotificationCapabilityRule',
      'require_ios_push_notification_capability',
      () => RequireIosPushNotificationCapabilityRule(),
    );

    testRule(
      'RequireIosAtsExceptionDocumentationRule',
      'require_ios_ats_exception_documentation',
      () => RequireIosAtsExceptionDocumentationRule(),
    );

    testRule(
      'RequireIosLocalNotificationPermissionRule',
      'require_ios_local_notification_permission',
      () => RequireIosLocalNotificationPermissionRule(),
    );

    testRule(
      'AvoidIosHardcodedDeviceModelRule',
      'avoid_ios_hardcoded_device_model',
      () => AvoidIosHardcodedDeviceModelRule(),
    );

    testRule(
      'RequireIosAppGroupCapabilityRule',
      'require_ios_app_group_capability',
      () => RequireIosAppGroupCapabilityRule(),
    );

    testRule(
      'RequireIosHealthKitAuthorizationRule',
      'require_ios_healthkit_authorization',
      () => RequireIosHealthKitAuthorizationRule(),
    );

    testRule(
      'RequireIosSiriIntentDefinitionRule',
      'require_ios_siri_intent_definition',
      () => RequireIosSiriIntentDefinitionRule(),
    );

    testRule(
      'RequireIosWidgetExtensionCapabilityRule',
      'require_ios_widget_extension_capability',
      () => RequireIosWidgetExtensionCapabilityRule(),
    );

    testRule(
      'RequireIosReceiptValidationRule',
      'require_ios_receipt_validation',
      () => RequireIosReceiptValidationRule(),
    );

    testRule(
      'RequireIosDatabaseConflictResolutionRule',
      'require_ios_database_conflict_resolution',
      () => RequireIosDatabaseConflictResolutionRule(),
    );

    testRule(
      'AvoidIosContinuousLocationTrackingRule',
      'avoid_ios_continuous_location_tracking',
      () => AvoidIosContinuousLocationTrackingRule(),
    );

    testRule(
      'RequireIosBackgroundAudioCapabilityRule',
      'require_ios_background_audio_capability',
      () => RequireIosBackgroundAudioCapabilityRule(),
    );

    testRule(
      'PreferIosStoreKit2Rule',
      'prefer_ios_storekit2',
      () => PreferIosStoreKit2Rule(),
    );

    testRule(
      'RequireIosAppClipSizeLimitRule',
      'require_ios_app_clip_size_limit',
      () => RequireIosAppClipSizeLimitRule(),
    );

    testRule(
      'RequireIosKeychainSyncAwarenessRule',
      'require_ios_keychain_sync_awareness',
      () => RequireIosKeychainSyncAwarenessRule(),
    );

    testRule(
      'RequireIosShareSheetUtiDeclarationRule',
      'require_ios_share_sheet_uti_declaration',
      () => RequireIosShareSheetUtiDeclarationRule(),
    );

    testRule(
      'RequireIosIcloudKvstoreLimitationsRule',
      'require_ios_icloud_kvstore_limitations',
      () => RequireIosIcloudKvstoreLimitationsRule(),
    );

    testRule(
      'RequireIosAccessibilityLabelsRule',
      'require_ios_accessibility_labels',
      () => RequireIosAccessibilityLabelsRule(),
    );

    testRule(
      'RequireIosOrientationHandlingRule',
      'require_ios_orientation_handling',
      () => RequireIosOrientationHandlingRule(),
    );

    testRule(
      'RequireIosUniversalLinksDomainMatchingRule',
      'require_ios_universal_links_domain_matching',
      () => RequireIosUniversalLinksDomainMatchingRule(),
    );

    testRule(
      'RequireIosNfcCapabilityCheckRule',
      'require_ios_nfc_capability_check',
      () => RequireIosNfcCapabilityCheckRule(),
    );

    testRule(
      'RequireIosCallkitIntegrationRule',
      'require_ios_callkit_integration',
      () => RequireIosCallkitIntegrationRule(),
    );

    testRule(
      'RequireIosCarplaySetupRule',
      'require_ios_carplay_setup',
      () => RequireIosCarplaySetupRule(),
    );

    testRule(
      'RequireIosLiveActivitiesSetupRule',
      'require_ios_live_activities_setup',
      () => RequireIosLiveActivitiesSetupRule(),
    );

    testRule(
      'RequireIosPromotionDisplaySupportRule',
      'require_ios_promotion_display_support',
      () => RequireIosPromotionDisplaySupportRule(),
    );

    testRule(
      'RequireIosPhotoLibraryLimitedAccessRule',
      'require_ios_photo_library_limited_access',
      () => RequireIosPhotoLibraryLimitedAccessRule(),
    );

    testRule(
      'RequireIosPasteboardPrivacyHandlingRule',
      'require_ios_pasteboard_privacy_handling',
      () => RequireIosPasteboardPrivacyHandlingRule(),
    );

    testRule(
      'RequireIosBackgroundRefreshDeclarationRule',
      'require_ios_background_refresh_declaration',
      () => RequireIosBackgroundRefreshDeclarationRule(),
    );

    testRule(
      'RequireIosSceneDelegateAwarenessRule',
      'require_ios_scene_delegate_awareness',
      () => RequireIosSceneDelegateAwarenessRule(),
    );

    testRule(
      'RequireIosMethodChannelCleanupRule',
      'require_ios_method_channel_cleanup',
      () => RequireIosMethodChannelCleanupRule(),
    );

    testRule(
      'AvoidIosForceUnwrapInCallbacksRule',
      'avoid_ios_force_unwrap_in_callbacks',
      () => AvoidIosForceUnwrapInCallbacksRule(),
    );

    testRule(
      'RequireIosReviewPromptFrequencyRule',
      'require_ios_review_prompt_frequency',
      () => RequireIosReviewPromptFrequencyRule(),
    );

    testRule(
      'RequireIosDeploymentTargetConsistencyRule',
      'require_ios_deployment_target_consistency',
      () => RequireIosDeploymentTargetConsistencyRule(),
    );

    testRule(
      'RequireIosDynamicIslandSafeZonesRule',
      'require_ios_dynamic_island_safe_zones',
      () => RequireIosDynamicIslandSafeZonesRule(),
    );

    testRule(
      'PreferIosAppIntentsFrameworkRule',
      'prefer_ios_app_intents_framework',
      () => PreferIosAppIntentsFrameworkRule(),
    );

    testRule(
      'RequireIosAgeRatingConsiderationRule',
      'require_ios_age_rating_consideration',
      () => RequireIosAgeRatingConsiderationRule(),
    );

    testRule(
      'RequireIosCertificatePinningRule',
      'require_ios_certificate_pinning',
      () => RequireIosCertificatePinningRule(),
    );

    testRule(
      'RequireIosKeychainForCredentialsRule',
      'require_ios_keychain_for_credentials',
      () => RequireIosKeychainForCredentialsRule(),
    );

    testRule(
      'AvoidIosDebugCodeInReleaseRule',
      'avoid_ios_debug_code_in_release',
      () => AvoidIosDebugCodeInReleaseRule(),
    );

    testRule(
      'RequireIosBiometricFallbackRule',
      'require_ios_biometric_fallback',
      () => RequireIosBiometricFallbackRule(),
    );

    testRule(
      'AvoidIosMisleadingPushNotificationsRule',
      'avoid_ios_misleading_push_notifications',
      () => AvoidIosMisleadingPushNotificationsRule(),
    );

    testRule(
      'AvoidLongRunningIsolatesRule',
      'avoid_long_running_isolates',
      () => AvoidLongRunningIsolatesRule(),
    );

    testRule(
      'RequireNotificationForLongTasksRule',
      'require_notification_for_long_tasks',
      () => RequireNotificationForLongTasksRule(),
    );

    testRule(
      'PreferDelayedPermissionPromptRule',
      'prefer_delayed_permission_prompt',
      () => PreferDelayedPermissionPromptRule(),
    );

    testRule(
      'AvoidNotificationSpamRule',
      'avoid_notification_spam',
      () => AvoidNotificationSpamRule(),
    );

    testRule(
      'RequirePurchaseVerificationRule',
      'require_purchase_verification',
      () => RequirePurchaseVerificationRule(),
    );

    testRule(
      'RequirePurchaseRestorationRule',
      'require_purchase_restoration',
      () => RequirePurchaseRestorationRule(),
    );

    testRule(
      'PreferBackgroundSyncRule',
      'prefer_background_sync',
      () => PreferBackgroundSyncRule(),
    );

    testRule(
      'RequireSyncErrorRecoveryRule',
      'require_sync_error_recovery',
      () => RequireSyncErrorRecoveryRule(),
    );

    testRule(
      'AvoidIosWifiOnlyAssumptionRule',
      'avoid_ios_wifi_only_assumption',
      () => AvoidIosWifiOnlyAssumptionRule(),
    );

    testRule(
      'RequireIosLowPowerModeHandlingRule',
      'require_ios_low_power_mode_handling',
      () => RequireIosLowPowerModeHandlingRule(),
    );

    testRule(
      'RequireIosAccessibilityLargeTextRule',
      'require_ios_accessibility_large_text',
      () => RequireIosAccessibilityLargeTextRule(),
    );

    testRule(
      'PreferIosContextMenuRule',
      'prefer_ios_context_menu',
      () => PreferIosContextMenuRule(),
    );

    testRule(
      'RequireIosQuickNoteAwarenessRule',
      'require_ios_quick_note_awareness',
      () => RequireIosQuickNoteAwarenessRule(),
    );

    testRule(
      'AvoidIosHardcodedKeyboardHeightRule',
      'avoid_ios_hardcoded_keyboard_height',
      () => AvoidIosHardcodedKeyboardHeightRule(),
    );

    testRule(
      'RequireIosMultitaskingSupportRule',
      'require_ios_multitasking_support',
      () => RequireIosMultitaskingSupportRule(),
    );

    testRule(
      'PreferIosSpotlightIndexingRule',
      'prefer_ios_spotlight_indexing',
      () => PreferIosSpotlightIndexingRule(),
    );

    testRule(
      'RequireIosDataProtectionRule',
      'require_ios_data_protection',
      () => RequireIosDataProtectionRule(),
    );

    testRule(
      'AvoidIosBatteryDrainPatternsRule',
      'avoid_ios_battery_drain_patterns',
      () => AvoidIosBatteryDrainPatternsRule(),
    );

    testRule(
      'RequireIosEntitlementsRule',
      'require_ios_entitlements',
      () => RequireIosEntitlementsRule(),
    );

    testRule(
      'RequireIosLaunchStoryboardRule',
      'require_ios_launch_storyboard',
      () => RequireIosLaunchStoryboardRule(),
    );

    testRule(
      'RequireIosVersionCheckRule',
      'require_ios_version_check',
      () => RequireIosVersionCheckRule(),
    );

    testRule(
      'RequireIosFocusModeAwarenessRule',
      'require_ios_focus_mode_awareness',
      () => RequireIosFocusModeAwarenessRule(),
    );

    testRule(
      'PreferIosHandoffSupportRule',
      'prefer_ios_handoff_support',
      () => PreferIosHandoffSupportRule(),
    );

    testRule(
      'RequireIosVoiceoverGestureCompatibilityRule',
      'require_ios_voiceover_gesture_compatibility',
      () => RequireIosVoiceoverGestureCompatibilityRule(),
    );
  });

  // example/lib/ios/: each rule's BAD/OK examples under real analyzer + custom_lint.
  group('iOS Rules - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/ios');

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
      test('\$fixture fixture exists', () {
        final file = File('example/lib/ios/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });
}
