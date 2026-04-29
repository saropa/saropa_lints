import 'package:saropa_lints/src/saropa_lint_rule.dart';
import 'package:saropa_lints/src/rules/platforms/ios_capabilities_permissions_rules.dart';
import 'package:saropa_lints/src/rules/platforms/ios_platform_lifecycle_rules.dart';
import 'package:saropa_lints/src/rules/security/security_auth_storage_rules.dart';
import 'package:test/test.dart';

/// Asserts every rule in the iOS lifecycle, iOS capabilities, and security
/// auth-storage rule files exposes at least one [SaropaLintRule.fixGenerators]
/// entry (see [rule_quick_fix_presence_test.dart] for the main catalog).
void _registerQuickFixPresenceTests(
  String groupLabel,
  Map<String, SaropaLintRule Function()> rules,
) {
  group(groupLabel, () {
    rules.forEach((name, create) {
      test('$name has at least one quick fix', () {
        final rule = create();
        expect(rule.fixGenerators, isNotEmpty, reason: name);
      });
    });
  });
}

void main() {
  _registerQuickFixPresenceTests('iOS platform lifecycle rules', {
      'AvoidIos13DeprecationsRule': () => AvoidIos13DeprecationsRule(),
      'AvoidIosSimulatorOnlyCodeRule': () => AvoidIosSimulatorOnlyCodeRule(),
      'RequireIosMinimumVersionCheckRule': () => RequireIosMinimumVersionCheckRule(),
      'AvoidIosDeprecatedUikitRule': () => AvoidIosDeprecatedUikitRule(),
      'AvoidIosInAppBrowserForAuthRule': () => AvoidIosInAppBrowserForAuthRule(),
      'RequireIosAppReviewPromptTimingRule': () => RequireIosAppReviewPromptTimingRule(),
      'AvoidIosHardcodedBundleIdRule': () => AvoidIosHardcodedBundleIdRule(),
      'AvoidIosHardcodedDeviceModelRule': () => AvoidIosHardcodedDeviceModelRule(),
      'RequireIosReceiptValidationRule': () => RequireIosReceiptValidationRule(),
      'RequireIosDatabaseConflictResolutionRule': () => RequireIosDatabaseConflictResolutionRule(),
      'AvoidIosContinuousLocationTrackingRule': () => AvoidIosContinuousLocationTrackingRule(),
      'PreferIosStoreKit2Rule': () => PreferIosStoreKit2Rule(),
      'RequireIosKeychainSyncAwarenessRule': () => RequireIosKeychainSyncAwarenessRule(),
      'RequireIosIcloudKvstoreLimitationsRule': () => RequireIosIcloudKvstoreLimitationsRule(),
      'RequireIosOrientationHandlingRule': () => RequireIosOrientationHandlingRule(),
      'RequireIosSceneDelegateAwarenessRule': () => RequireIosSceneDelegateAwarenessRule(),
      'RequireIosMethodChannelCleanupRule': () => RequireIosMethodChannelCleanupRule(),
      'AvoidIosForceUnwrapInCallbacksRule': () => AvoidIosForceUnwrapInCallbacksRule(),
      'RequireIosReviewPromptFrequencyRule': () => RequireIosReviewPromptFrequencyRule(),
      'RequireIosDeploymentTargetConsistencyRule': () => RequireIosDeploymentTargetConsistencyRule(),
      'RequireIosDynamicIslandSafeZonesRule': () => RequireIosDynamicIslandSafeZonesRule(),
      'PreferIosAppIntentsFrameworkRule': () => PreferIosAppIntentsFrameworkRule(),
      'RequireIosAgeRatingConsiderationRule': () => RequireIosAgeRatingConsiderationRule(),
      'RequireIosKeychainForCredentialsRule': () => RequireIosKeychainForCredentialsRule(),
      'AvoidIosDebugCodeInReleaseRule': () => AvoidIosDebugCodeInReleaseRule(),
      'AvoidIosMisleadingPushNotificationsRule': () => AvoidIosMisleadingPushNotificationsRule(),
      'AvoidLongRunningIsolatesRule': () => AvoidLongRunningIsolatesRule(),
      'RequireNotificationForLongTasksRule': () => RequireNotificationForLongTasksRule(),
      'PreferDelayedPermissionPromptRule': () => PreferDelayedPermissionPromptRule(),
      'AvoidNotificationSpamRule': () => AvoidNotificationSpamRule(),
      'RequirePurchaseVerificationRule': () => RequirePurchaseVerificationRule(),
      'RequirePurchaseRestorationRule': () => RequirePurchaseRestorationRule(),
      'PreferBackgroundSyncRule': () => PreferBackgroundSyncRule(),
      'RequireSyncErrorRecoveryRule': () => RequireSyncErrorRecoveryRule(),
      'AvoidIosWifiOnlyAssumptionRule': () => AvoidIosWifiOnlyAssumptionRule(),
      'RequireIosLowPowerModeHandlingRule': () => RequireIosLowPowerModeHandlingRule(),
      'PreferIosContextMenuRule': () => PreferIosContextMenuRule(),
      'AvoidIosHardcodedKeyboardHeightRule': () => AvoidIosHardcodedKeyboardHeightRule(),
      'RequireIosMultitaskingSupportRule': () => RequireIosMultitaskingSupportRule(),
      'PreferIosSpotlightIndexingRule': () => PreferIosSpotlightIndexingRule(),
      'RequireIosDataProtectionRule': () => RequireIosDataProtectionRule(),
      'AvoidIosBatteryDrainPatternsRule': () => AvoidIosBatteryDrainPatternsRule(),
      'RequireIosEntitlementsRule': () => RequireIosEntitlementsRule(),
      'RequireIosLaunchStoryboardRule': () => RequireIosLaunchStoryboardRule(),
      'RequireIosVersionCheckRule': () => RequireIosVersionCheckRule(),
      'RequireIosFocusModeAwarenessRule': () => RequireIosFocusModeAwarenessRule(),
      'PreferIosHandoffSupportRule': () => PreferIosHandoffSupportRule(),
  });

  _registerQuickFixPresenceTests('iOS capabilities and permissions rules', {
      'RequireIosInfoPlistEntriesRule': () => RequireIosInfoPlistEntriesRule(),
      'RequireIosPermissionDescriptionRule': () => RequireIosPermissionDescriptionRule(),
      'RequireIosPrivacyManifestRule': () => RequireIosPrivacyManifestRule(),
      'RequireIosBackgroundModeRule': () => RequireIosBackgroundModeRule(),
      'RequireIosAppTrackingTransparencyRule': () => RequireIosAppTrackingTransparencyRule(),
      'RequireIosFaceIdUsageDescriptionRule': () => RequireIosFaceIdUsageDescriptionRule(),
      'RequireIosPhotoLibraryAddUsageRule': () => RequireIosPhotoLibraryAddUsageRule(),
      'RequireIosPushNotificationCapabilityRule': () => RequireIosPushNotificationCapabilityRule(),
      'RequireIosLocalNotificationPermissionRule': () => RequireIosLocalNotificationPermissionRule(),
      'RequireIosAppGroupCapabilityRule': () => RequireIosAppGroupCapabilityRule(),
      'RequireIosHealthKitAuthorizationRule': () => RequireIosHealthKitAuthorizationRule(),
      'RequireIosSiriIntentDefinitionRule': () => RequireIosSiriIntentDefinitionRule(),
      'RequireIosWidgetExtensionCapabilityRule': () => RequireIosWidgetExtensionCapabilityRule(),
      'RequireIosBackgroundAudioCapabilityRule': () => RequireIosBackgroundAudioCapabilityRule(),
      'RequireIosAppClipSizeLimitRule': () => RequireIosAppClipSizeLimitRule(),
      'RequireIosShareSheetUtiDeclarationRule': () => RequireIosShareSheetUtiDeclarationRule(),
      'RequireIosAccessibilityLabelsRule': () => RequireIosAccessibilityLabelsRule(),
      'RequireIosNfcCapabilityCheckRule': () => RequireIosNfcCapabilityCheckRule(),
      'RequireIosCallkitIntegrationRule': () => RequireIosCallkitIntegrationRule(),
      'RequireIosCarplaySetupRule': () => RequireIosCarplaySetupRule(),
      'RequireIosLiveActivitiesSetupRule': () => RequireIosLiveActivitiesSetupRule(),
      'RequireIosPromotionDisplaySupportRule': () => RequireIosPromotionDisplaySupportRule(),
      'RequireIosPhotoLibraryLimitedAccessRule': () => RequireIosPhotoLibraryLimitedAccessRule(),
      'RequireIosPasteboardPrivacyHandlingRule': () => RequireIosPasteboardPrivacyHandlingRule(),
      'RequireIosBackgroundRefreshDeclarationRule': () => RequireIosBackgroundRefreshDeclarationRule(),
      'RequireIosBiometricFallbackRule': () => RequireIosBiometricFallbackRule(),
      'RequireIosAccessibilityLargeTextRule': () => RequireIosAccessibilityLargeTextRule(),
      'RequireIosQuickNoteAwarenessRule': () => RequireIosQuickNoteAwarenessRule(),
      'RequireIosVoiceoverGestureCompatibilityRule': () => RequireIosVoiceoverGestureCompatibilityRule(),
  });

  _registerQuickFixPresenceTests('Security auth and storage rules', {
      'RequireSecureStorageRule': () => RequireSecureStorageRule(),
      'AvoidHardcodedCredentialsRule': () => AvoidHardcodedCredentialsRule(),
      'RequireBiometricFallbackRule': () => RequireBiometricFallbackRule(),
      'AvoidStoringPasswordsRule': () => AvoidStoringPasswordsRule(),
      'RequireAuthCheckRule': () => RequireAuthCheckRule(),
      'RequireTokenRefreshRule': () => RequireTokenRefreshRule(),
      'AvoidJwtDecodeClientRule': () => AvoidJwtDecodeClientRule(),
      'RequireLogoutCleanupRule': () => RequireLogoutCleanupRule(),
      'AvoidAuthInQueryParamsRule': () => AvoidAuthInQueryParamsRule(),
      'RequireDataEncryptionRule': () => RequireDataEncryptionRule(),
      'RequireSecurePasswordFieldRule': () => RequireSecurePasswordFieldRule(),
      'RequireSecureStorageForAuthRule': () => RequireSecureStorageForAuthRule(),
      'PreferLocalAuthRule': () => PreferLocalAuthRule(),
      'RequireSecureStorageAuthDataRule': () => RequireSecureStorageAuthDataRule(),
      'AvoidStoringSensitiveUnencryptedRule': () => AvoidStoringSensitiveUnencryptedRule(),
      'RequireSecureStorageErrorHandlingRule': () => RequireSecureStorageErrorHandlingRule(),
      'AvoidSecureStorageLargeDataRule': () => AvoidSecureStorageLargeDataRule(),
      'PreferBiometricProtectionRule': () => PreferBiometricProtectionRule(),
      'AvoidSensitiveDataInClipboardRule': () => AvoidSensitiveDataInClipboardRule(),
      'RequireClipboardPasteValidationRule': () => RequireClipboardPasteValidationRule(),
      'AvoidEncryptionKeyInMemoryRule': () => AvoidEncryptionKeyInMemoryRule(),
      'PreferOauthPkceRule': () => PreferOauthPkceRule(),
      'RequireSessionTimeoutRule': () => RequireSessionTimeoutRule(),
      'PreferRootDetectionRule': () => PreferRootDetectionRule(),
      'PreferWebviewSandboxRule': () => PreferWebviewSandboxRule(),
      'PreferWhitelistValidationRule': () => PreferWhitelistValidationRule(),
      'RequireKeychainAccessRule': () => RequireKeychainAccessRule(),
      'RequireWebviewUserAgentRule': () => RequireWebviewUserAgentRule(),
      'RequireMultiFactorRule': () => RequireMultiFactorRule(),
  });
}
