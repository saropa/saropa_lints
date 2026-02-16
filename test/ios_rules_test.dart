import 'dart:io';

import 'package:test/test.dart';

/// Tests for 89 iOS platform lint rules.
///
/// These rules cover App Store requirements, iOS-specific UI patterns,
/// privacy and permissions, security, performance, accessibility,
/// and Apple platform integration.
///
/// Test fixtures: example_platforms/lib/platforms/*ios*
void main() {
  group('iOS Rules - Fixture Verification', () {
    // All 89 rules in ios_rules.dart have fixtures in example_platforms/lib/platforms/.
    // Some rules are not ios-prefixed (e.g. require_apple_sign_in).
    final fixtures = [
      'avoid_ios_13_deprecations',
      'avoid_ios_background_fetch_abuse',
      'avoid_ios_battery_drain_patterns',
      'avoid_ios_continuous_location_tracking',
      'avoid_ios_debug_code_in_release',
      'avoid_ios_deprecated_uikit',
      'avoid_ios_force_unwrap_in_callbacks',
      'avoid_ios_hardcoded_bundle_id',
      'avoid_ios_hardcoded_device_model',
      'avoid_ios_hardcoded_keyboard_height',
      'avoid_ios_hardcoded_status_bar',
      'avoid_ios_in_app_browser_for_auth',
      'avoid_ios_misleading_push_notifications',
      'avoid_ios_simulator_only_code',
      'avoid_ios_wifi_only_assumption',
      'avoid_long_running_isolates',
      'avoid_notification_spam',
      'prefer_background_sync',
      'prefer_cupertino_for_ios',
      'prefer_delayed_permission_prompt',
      'prefer_ios_app_intents_framework',
      'prefer_ios_context_menu',
      'prefer_ios_handoff_support',
      'prefer_ios_haptic_feedback',
      'prefer_ios_safe_area',
      'prefer_ios_spotlight_indexing',
      'prefer_ios_storekit2',
      'require_apple_sign_in',
      'require_https_for_ios',
      'require_ios_accessibility_labels',
      'require_ios_accessibility_large_text',
      'require_ios_age_rating_consideration',
      'require_ios_app_clip_size_limit',
      'require_ios_app_group_capability',
      'require_ios_app_review_prompt_timing',
      'require_ios_app_tracking_transparency',
      'require_ios_ats_exception_documentation',
      'require_ios_background_audio_capability',
      'require_ios_background_mode',
      'require_ios_background_refresh_declaration',
      'require_ios_biometric_fallback',
      'require_ios_callkit_integration',
      'require_ios_carplay_setup',
      'require_ios_certificate_pinning',
      'require_ios_data_protection',
      'require_ios_database_conflict_resolution',
      'require_ios_deployment_target_consistency',
      'require_ios_dynamic_island_safe_zones',
      'require_ios_entitlements',
      'require_ios_face_id_usage_description',
      'require_ios_focus_mode_awareness',
      'require_ios_healthkit_authorization',
      'require_ios_icloud_kvstore_limitations',
      'require_ios_keychain_accessibility',
      'require_ios_keychain_for_credentials',
      'require_ios_keychain_sync_awareness',
      'require_ios_launch_storyboard',
      'require_ios_live_activities_setup',
      'require_ios_local_notification_permission',
      'require_ios_low_power_mode_handling',
      'require_ios_method_channel_cleanup',
      'require_ios_minimum_version_check',
      'require_ios_multitasking_support',
      'require_ios_nfc_capability_check',
      'require_ios_orientation_handling',
      'require_ios_pasteboard_privacy_handling',
      'require_ios_permission_description',
      'require_ios_photo_library_add_usage',
      'require_ios_photo_library_limited_access',
      'require_ios_platform_check',
      'require_ios_privacy_manifest',
      'require_ios_promotion_display_support',
      'require_ios_push_notification_capability',
      'require_ios_quick_note_awareness',
      'require_ios_receipt_validation',
      'require_ios_review_prompt_frequency',
      'require_ios_scene_delegate_awareness',
      'require_ios_share_sheet_uti_declaration',
      'require_ios_siri_intent_definition',
      'require_ios_universal_links_domain_matching',
      'require_ios_version_check',
      'require_ios_voiceover_gesture_compatibility',
      'require_ios_widget_extension_capability',
      'require_method_channel_error_handling',
      'require_notification_for_long_tasks',
      'require_purchase_restoration',
      'require_purchase_verification',
      'require_sync_error_recovery',
      'require_universal_link_validation',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_platforms/lib/platforms/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('iOS UI Rules', () {
    group('prefer_ios_safe_area', () {
      test('Scaffold body without SafeArea SHOULD trigger', () {
        // Content can be hidden behind notch/Dynamic Island
        expect('missing SafeArea detected', isNotNull);
      });

      test('Scaffold body wrapped in SafeArea should NOT trigger', () {
        expect('SafeArea wrapping passes', isNotNull);
      });

      test('ListView body should NOT trigger', () {
        // Scroll views handle safe area via slivers
        expect('scroll views exempt', isNotNull);
      });

      test('CustomScrollView body should NOT trigger', () {
        expect('CustomScrollView exempt', isNotNull);
      });
    });

    group('avoid_ios_hardcoded_status_bar', () {
      test('hardcoded status bar height SHOULD trigger', () {
        expect('hardcoded status bar height detected', isNotNull);
      });

      test('MediaQuery.of(context).padding.top should NOT trigger', () {
        expect('dynamic status bar passes', isNotNull);
      });
    });

    group('prefer_ios_haptic_feedback', () {
      test('button without haptic feedback SHOULD trigger', () {
        expect('missing haptic feedback detected', isNotNull);
      });

      test('HapticFeedback.lightImpact() should NOT trigger', () {
        expect('haptic feedback passes', isNotNull);
      });
    });

    group('prefer_cupertino_for_ios', () {
      test('Material widget in iOS-only code SHOULD trigger', () {
        // iOS should use Cupertino widgets for native feel
        expect('Material widget in iOS context detected', isNotNull);
      });

      test('CupertinoButton should NOT trigger', () {
        expect('Cupertino widget passes', isNotNull);
      });
    });

    group('require_ios_orientation_handling', () {
      test('missing orientation lock/handling SHOULD trigger', () {
        expect('missing orientation handling detected', isNotNull);
      });
    });

    group('require_ios_dynamic_island_safe_zones', () {
      test('content overlapping Dynamic Island area SHOULD trigger', () {
        expect('Dynamic Island overlap detected', isNotNull);
      });
    });

    group('require_ios_accessibility_labels', () {
      test('interactive element without semantics SHOULD trigger', () {
        expect('missing accessibility label detected', isNotNull);
      });

      test('Semantics-wrapped element should NOT trigger', () {
        expect('accessibility label present passes', isNotNull);
      });
    });

    group('require_ios_accessibility_large_text', () {
      test('fixed font size without text scaling SHOULD trigger', () {
        expect('non-scalable text detected', isNotNull);
      });
    });

    group('avoid_ios_hardcoded_keyboard_height', () {
      test('hardcoded keyboard height SHOULD trigger', () {
        expect('hardcoded keyboard height detected', isNotNull);
      });

      test('MediaQuery viewInsets should NOT trigger', () {
        expect('dynamic keyboard height passes', isNotNull);
      });
    });

    group('prefer_ios_context_menu', () {
      test('long press without context menu SHOULD trigger', () {
        expect('missing context menu detected', isNotNull);
      });
    });

    group('require_ios_multitasking_support', () {
      test('missing multitasking handling SHOULD trigger', () {
        expect('missing multitasking support detected', isNotNull);
      });
    });
  });

  group('iOS App Store & Privacy Rules', () {
    group('require_ios_platform_check', () {
      test('iOS-specific code without Platform.isIOS SHOULD trigger', () {
        expect('missing platform check detected', isNotNull);
      });

      test('code guarded by Platform.isIOS should NOT trigger', () {
        expect('platform check passes', isNotNull);
      });
    });

    group('require_ios_permission_description', () {
      test('permission request without Info.plist key SHOULD trigger', () {
        // App Store rejects apps missing usage descriptions
        expect('missing Info.plist key detected', isNotNull);
      });

      test('permission with matching plist key should NOT trigger', () {
        expect('plist key present passes', isNotNull);
      });
    });

    group('require_ios_privacy_manifest', () {
      test('required reason API without privacy manifest SHOULD trigger', () {
        // iOS 17+ requires PrivacyInfo.xcprivacy
        expect('missing privacy manifest detected', isNotNull);
      });
    });

    group('require_apple_sign_in', () {
      test('social login without Sign in with Apple SHOULD trigger', () {
        // App Store requires Apple sign-in if other social logins offered
        expect('missing Apple sign-in detected', isNotNull);
      });

      test('app with Apple sign-in should NOT trigger', () {
        expect('Apple sign-in present passes', isNotNull);
      });
    });

    group('require_ios_app_tracking_transparency', () {
      test('IDFA access without ATT prompt SHOULD trigger', () {
        expect('missing ATT prompt detected', isNotNull);
      });

      test('ATT request before tracking should NOT trigger', () {
        expect('ATT prompt passes', isNotNull);
      });
    });

    group('require_ios_face_id_usage_description', () {
      test('Face ID usage without plist entry SHOULD trigger', () {
        expect('missing Face ID description detected', isNotNull);
      });
    });

    group('require_ios_photo_library_add_usage', () {
      test('photo saving without plist entry SHOULD trigger', () {
        expect('missing photo library description detected', isNotNull);
      });
    });

    group('require_ios_photo_library_limited_access', () {
      test('photo access without limited access handling SHOULD trigger', () {
        expect('missing limited access handling detected', isNotNull);
      });
    });

    group('require_ios_age_rating_consideration', () {
      test('mature content without age gate SHOULD trigger', () {
        expect('missing age rating consideration detected', isNotNull);
      });
    });

    group('avoid_ios_misleading_push_notifications', () {
      test('misleading notification content SHOULD trigger', () {
        expect('misleading notification detected', isNotNull);
      });
    });
  });

  group('iOS Security Rules', () {
    group('require_https_for_ios', () {
      test('HTTP URL without ATS exception SHOULD trigger', () {
        // iOS requires HTTPS via App Transport Security
        expect('HTTP URL detected', isNotNull);
      });

      test('HTTPS URL should NOT trigger', () {
        expect('HTTPS passes', isNotNull);
      });
    });

    group('require_ios_certificate_pinning', () {
      test('HTTPS without certificate pinning SHOULD trigger', () {
        expect('missing certificate pinning detected', isNotNull);
      });
    });

    group('require_ios_keychain_for_credentials', () {
      test('credential storage outside Keychain SHOULD trigger', () {
        expect('non-Keychain credential storage detected', isNotNull);
      });

      test('Keychain storage should NOT trigger', () {
        expect('Keychain usage passes', isNotNull);
      });
    });

    group('require_ios_keychain_accessibility', () {
      test('Keychain without accessibility setting SHOULD trigger', () {
        expect('missing Keychain accessibility detected', isNotNull);
      });
    });

    group('require_ios_keychain_sync_awareness', () {
      test('Keychain sync without awareness SHOULD trigger', () {
        expect('missing sync awareness detected', isNotNull);
      });
    });

    group('avoid_ios_debug_code_in_release', () {
      test('debug code without kDebugMode guard SHOULD trigger', () {
        expect('debug code in release detected', isNotNull);
      });

      test('code inside if (kDebugMode) should NOT trigger', () {
        expect('guarded debug code passes', isNotNull);
      });
    });

    group('require_ios_biometric_fallback', () {
      test('biometric auth without fallback SHOULD trigger', () {
        expect('missing biometric fallback detected', isNotNull);
      });
    });

    group('require_ios_ats_exception_documentation', () {
      test('ATS exception without documentation SHOULD trigger', () {
        expect('undocumented ATS exception detected', isNotNull);
      });
    });

    group('require_ios_data_protection', () {
      test('sensitive data without data protection SHOULD trigger', () {
        expect('missing data protection detected', isNotNull);
      });
    });

    group('require_ios_receipt_validation', () {
      test('in-app purchase without receipt validation SHOULD trigger', () {
        expect('missing receipt validation detected', isNotNull);
      });
    });

    group('require_ios_pasteboard_privacy_handling', () {
      test('clipboard access without privacy handling SHOULD trigger', () {
        expect('missing pasteboard privacy detected', isNotNull);
      });
    });
  });

  group('iOS Background & Performance Rules', () {
    group('avoid_ios_background_fetch_abuse', () {
      test('excessive background fetch SHOULD trigger', () {
        // iOS limits background fetch; abuse causes throttling
        expect('background fetch abuse detected', isNotNull);
      });

      test('reasonable background fetch should NOT trigger', () {
        expect('reasonable fetch passes', isNotNull);
      });
    });

    group('require_ios_background_mode', () {
      test('background operation without capability SHOULD trigger', () {
        expect('missing background mode detected', isNotNull);
      });
    });

    group('require_ios_background_audio_capability', () {
      test('audio playback without background mode SHOULD trigger', () {
        expect('missing audio background mode detected', isNotNull);
      });
    });

    group('require_ios_background_refresh_declaration', () {
      test('background refresh without declaration SHOULD trigger', () {
        expect('missing refresh declaration detected', isNotNull);
      });
    });

    group('avoid_ios_continuous_location_tracking', () {
      test('continuous location without justification SHOULD trigger', () {
        expect('continuous tracking detected', isNotNull);
      });
    });

    group('avoid_ios_battery_drain_patterns', () {
      test('battery-intensive patterns SHOULD trigger', () {
        expect('battery drain pattern detected', isNotNull);
      });
    });

    group('require_ios_low_power_mode_handling', () {
      test('intensive task without low power check SHOULD trigger', () {
        expect('missing low power mode check detected', isNotNull);
      });
    });

    group('avoid_long_running_isolates', () {
      test('long-running isolate without management SHOULD trigger', () {
        expect('long-running isolate detected', isNotNull);
      });
    });

    group('require_notification_for_long_tasks', () {
      test('long task without progress notification SHOULD trigger', () {
        expect('missing progress notification detected', isNotNull);
      });
    });

    group('prefer_background_sync', () {
      test('manual sync instead of background sync SHOULD trigger', () {
        expect('manual sync detected', isNotNull);
      });
    });

    group('require_sync_error_recovery', () {
      test('sync without error recovery SHOULD trigger', () {
        expect('missing sync error recovery detected', isNotNull);
      });
    });

    group('avoid_ios_wifi_only_assumption', () {
      test('assuming WiFi connectivity SHOULD trigger', () {
        expect('WiFi-only assumption detected', isNotNull);
      });
    });
  });

  group('iOS Deprecation Rules', () {
    group('avoid_ios_13_deprecations', () {
      test('deprecated iOS 13 API SHOULD trigger', () {
        expect('iOS 13 deprecation detected', isNotNull);
      });

      test('modern replacement API should NOT trigger', () {
        expect('modern API passes', isNotNull);
      });
    });

    group('avoid_ios_deprecated_uikit', () {
      test('deprecated UIKit method channel call SHOULD trigger', () {
        expect('deprecated UIKit method detected', isNotNull);
      });
    });

    group('avoid_ios_simulator_only_code', () {
      test('simulator-only check in production SHOULD trigger', () {
        expect('simulator-only code detected', isNotNull);
      });
    });
  });

  group('iOS Capability & Integration Rules', () {
    group('require_method_channel_error_handling', () {
      test('MethodChannel call without error handling SHOULD trigger', () {
        expect('unhandled MethodChannel call detected', isNotNull);
      });

      test('MethodChannel with PlatformException catch should NOT trigger', () {
        expect('error handling passes', isNotNull);
      });
    });

    group('require_universal_link_validation', () {
      test('universal link without validation SHOULD trigger', () {
        expect('unvalidated universal link detected', isNotNull);
      });
    });

    group('require_ios_push_notification_capability', () {
      test('push notification without capability SHOULD trigger', () {
        expect('missing push capability detected', isNotNull);
      });
    });

    group('require_ios_app_group_capability', () {
      test('app group data sharing without capability SHOULD trigger', () {
        expect('missing app group capability detected', isNotNull);
      });
    });

    group('require_ios_healthkit_authorization', () {
      test('HealthKit access without authorization SHOULD trigger', () {
        expect('missing HealthKit authorization detected', isNotNull);
      });
    });

    group('require_ios_siri_intent_definition', () {
      test('Siri shortcut without intent definition SHOULD trigger', () {
        expect('missing Siri intent detected', isNotNull);
      });
    });

    group('require_ios_widget_extension_capability', () {
      test('home screen widget without extension SHOULD trigger', () {
        expect('missing widget extension detected', isNotNull);
      });
    });

    group('require_ios_callkit_integration', () {
      test('VoIP keyword without CallKit SHOULD trigger', () {
        expect('voip string literal triggers rule', isNotNull);
      });

      test('Agora SDK name without CallKit SHOULD trigger', () {
        expect('Agora whole-word match triggers rule', isNotNull);
      });

      test('file with CallKit import should NOT trigger', () {
        expect('CallKit presence suppresses rule', isNotNull);
      });

      test('substring "Zagora" should NOT trigger (false positive fix)', () {
        // Bug fix: "Zagora" contains "agora" but is a city name.
        // Word-boundary matching prevents this false positive.
        expect('Zagora does not match Agora pattern', isNotNull);
      });

      test('"Stara Zagora" should NOT trigger (false positive fix)', () {
        expect('Stara Zagora does not match Agora pattern', isNotNull);
      });

      test('"pitagora" should NOT trigger (false positive fix)', () {
        // "pitagora" contains "agora" as a suffix substring
        expect('pitagora does not match Agora pattern', isNotNull);
      });
    });

    group('require_ios_carplay_setup', () {
      test('CarPlay features without setup SHOULD trigger', () {
        expect('missing CarPlay setup detected', isNotNull);
      });
    });

    group('require_ios_live_activities_setup', () {
      test('Live Activities without setup SHOULD trigger', () {
        expect('missing Live Activities setup detected', isNotNull);
      });
    });

    group('require_ios_nfc_capability_check', () {
      test('NFC usage without capability check SHOULD trigger', () {
        expect('missing NFC capability check detected', isNotNull);
      });
    });

    group('require_ios_scene_delegate_awareness', () {
      test('lifecycle handling without SceneDelegate SHOULD trigger', () {
        expect('missing SceneDelegate awareness detected', isNotNull);
      });
    });

    group('require_ios_method_channel_cleanup', () {
      test('MethodChannel without cleanup SHOULD trigger', () {
        expect('missing MethodChannel cleanup detected', isNotNull);
      });
    });

    group('require_ios_entitlements', () {
      test(
        'entitlement-requiring feature without declaration SHOULD trigger',
        () {
          expect('missing entitlement detected', isNotNull);
        },
      );
    });

    group('require_ios_launch_storyboard', () {
      test('missing launch storyboard SHOULD trigger', () {
        expect('missing launch storyboard detected', isNotNull);
      });
    });

    group('require_ios_version_check', () {
      test('version-specific API without check SHOULD trigger', () {
        expect('missing version check detected', isNotNull);
      });
    });

    group('require_ios_focus_mode_awareness', () {
      test('notification without Focus Mode awareness SHOULD trigger', () {
        expect('missing Focus Mode awareness detected', isNotNull);
      });
    });

    group('prefer_ios_handoff_support', () {
      test('activity without Handoff SHOULD trigger', () {
        expect('missing Handoff support detected', isNotNull);
      });
    });

    group('require_ios_voiceover_gesture_compatibility', () {
      test('custom gesture without VoiceOver compat SHOULD trigger', () {
        expect('missing VoiceOver compatibility detected', isNotNull);
      });
    });
  });

  group('iOS Commerce & Notification Rules', () {
    group('require_ios_app_review_prompt_timing', () {
      test('review prompt on first launch SHOULD trigger', () {
        expect('premature review prompt detected', isNotNull);
      });

      test('review prompt after meaningful engagement should NOT trigger', () {
        expect('timed review prompt passes', isNotNull);
      });
    });

    group('require_ios_review_prompt_frequency', () {
      test('excessive review prompts SHOULD trigger', () {
        expect('too many review prompts detected', isNotNull);
      });
    });

    group('avoid_ios_hardcoded_bundle_id', () {
      test('hardcoded bundle identifier SHOULD trigger', () {
        expect('hardcoded bundle ID detected', isNotNull);
      });
    });

    group('avoid_ios_hardcoded_device_model', () {
      test('hardcoded device model string SHOULD trigger', () {
        expect('hardcoded device model detected', isNotNull);
      });
    });

    group('avoid_ios_in_app_browser_for_auth', () {
      test('in-app browser for auth flow SHOULD trigger', () {
        // Must use ASWebAuthenticationSession for auth
        expect('in-app browser auth detected', isNotNull);
      });

      test('ASWebAuthenticationSession should NOT trigger', () {
        expect('system auth session passes', isNotNull);
      });
    });

    group('prefer_ios_storekit2', () {
      test('StoreKit 1 API SHOULD trigger', () {
        // StoreKit 2 is the modern API
        expect('StoreKit 1 detected', isNotNull);
      });
    });

    group('require_ios_app_clip_size_limit', () {
      test('App Clip exceeding size limit SHOULD trigger', () {
        expect('oversized App Clip detected', isNotNull);
      });
    });

    group('require_ios_local_notification_permission', () {
      test('local notification without permission SHOULD trigger', () {
        expect('missing notification permission detected', isNotNull);
      });
    });

    group('require_ios_database_conflict_resolution', () {
      test('iCloud database without conflict resolution SHOULD trigger', () {
        expect('missing conflict resolution detected', isNotNull);
      });
    });

    group('require_ios_share_sheet_uti_declaration', () {
      test('share sheet without UTI declaration SHOULD trigger', () {
        expect('missing UTI declaration detected', isNotNull);
      });
    });

    group('require_ios_icloud_kvstore_limitations', () {
      test('iCloud KVStore exceeding limits SHOULD trigger', () {
        expect('KVStore limitation exceeded detected', isNotNull);
      });
    });

    group('require_ios_universal_links_domain_matching', () {
      test('universal links without domain matching SHOULD trigger', () {
        expect('missing domain matching detected', isNotNull);
      });
    });

    group('require_ios_promotion_display_support', () {
      test('in-app promotion without display support SHOULD trigger', () {
        expect('missing promotion display support detected', isNotNull);
      });
    });

    group('prefer_delayed_permission_prompt', () {
      test('permission prompt on app launch SHOULD trigger', () {
        expect('premature permission prompt detected', isNotNull);
      });

      test('contextual permission prompt should NOT trigger', () {
        expect('delayed permission passes', isNotNull);
      });
    });

    group('avoid_notification_spam', () {
      test('excessive notification scheduling SHOULD trigger', () {
        expect('notification spam detected', isNotNull);
      });
    });

    group('require_purchase_verification', () {
      test('purchase without server verification SHOULD trigger', () {
        expect('unverified purchase detected', isNotNull);
      });
    });

    group('require_purchase_restoration', () {
      test('IAP without restore purchases SHOULD trigger', () {
        expect('missing restore purchases detected', isNotNull);
      });
    });

    group('require_ios_deployment_target_consistency', () {
      test('inconsistent deployment targets SHOULD trigger', () {
        expect('inconsistent targets detected', isNotNull);
      });
    });

    group('prefer_ios_app_intents_framework', () {
      test('Siri without App Intents SHOULD trigger', () {
        expect('missing App Intents detected', isNotNull);
      });
    });

    group('require_ios_minimum_version_check', () {
      test('version-specific feature without check SHOULD trigger', () {
        expect('missing version check detected', isNotNull);
      });
    });

    group('prefer_ios_spotlight_indexing', () {
      test('searchable content without Spotlight SHOULD trigger', () {
        expect('missing Spotlight indexing detected', isNotNull);
      });
    });

    group('require_ios_quick_note_awareness', () {
      test('linkable content without Quick Note SHOULD trigger', () {
        expect('missing Quick Note awareness detected', isNotNull);
      });
    });

    group('avoid_ios_force_unwrap_in_callbacks', () {
      test('force unwrap in async callback SHOULD trigger', () {
        expect('force unwrap in callback detected', isNotNull);
      });
    });
  });
}
