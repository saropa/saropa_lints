import 'package:saropa_lints/saropa_lints.dart';
import 'package:saropa_lints/src/platform_support_utils.dart';
import 'package:test/test.dart';

/// Tests for the cross-platform dependency-compatibility rule and its backing
/// knowledge base.
///
/// No `example/lib/` fixture exists for this rule: it fires only when the
/// project targets a platform the imported plugin cannot serve, and the example
/// project targets Android only (no `web/`, `windows/`, `macos/`, `linux/`
/// directories), so a fixture there could never trigger. Per the no-stub-
/// fixtures policy, behavior is pinned by the knowledge-base tests below plus
/// the scan CLI (`dart run saropa_lints scan`) against a real web/desktop
/// project.
void main() {
  group('avoid_platform_incompatible_dependency - instantiation', () {
    test('rule metadata', () {
      final rule = AvoidPlatformIncompatibleDependencyRule();
      expect(rule.code.lowerCaseName, 'avoid_platform_incompatible_dependency');
      expect(
        rule.code.problemMessage,
        contains('[avoid_platform_incompatible_dependency]'),
      );
      // Project convention: problem messages exceed 200 chars.
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.impact, LintImpact.warning);
    });

    test('registered in the comprehensive tier', () {
      expect(
        getRulesForTier('comprehensive'),
        contains('avoid_platform_incompatible_dependency'),
      );
    });
  });

  group('PluginPlatformSupport knowledge base', () {
    // These pin the hand-verified pub.dev data (confirmed 2026-06-22). If a
    // plugin later adds support for a platform, the corresponding entry in
    // platform_support_utils.dart must be updated and this test follows.
    test('verified unsupported-platform sets', () {
      expect(PluginPlatformSupport.unsupportedPlatforms('sqflite'), <String>{
        'web',
        'windows',
        'linux',
      });
      expect(PluginPlatformSupport.unsupportedPlatforms('local_auth'), <String>{
        'web',
        'linux',
      });
      expect(
        PluginPlatformSupport.unsupportedPlatforms('path_provider'),
        <String>{'web'},
      );
      expect(
        PluginPlatformSupport.unsupportedPlatforms('firebase_messaging'),
        <String>{'windows', 'linux'},
      );
      expect(PluginPlatformSupport.unsupportedPlatforms('camera'), <String>{
        'windows',
        'macos',
        'linux',
      });
      expect(
        PluginPlatformSupport.unsupportedPlatforms('permission_handler'),
        <String>{'macos', 'linux'},
      );
    });

    test('fully-supported and unknown packages return empty', () {
      // geolocator and flutter_local_notifications support every tracked
      // platform, so they are absent from the map.
      expect(PluginPlatformSupport.unsupportedPlatforms('geolocator'), isEmpty);
      expect(
        PluginPlatformSupport.unsupportedPlatforms(
          'flutter_local_notifications',
        ),
        isEmpty,
      );
      // Conservative default: unknown packages are never reported.
      expect(
        PluginPlatformSupport.unsupportedPlatforms('totally_unknown_pkg'),
        isEmpty,
      );
    });

    test('every listed unsupported platform is a tracked platform', () {
      // A typo'd platform id (e.g. "windowss") would silently never match
      // targetsPlatform, making the entry dead. This guards against that.
      const packages = <String>[
        'sqflite',
        'local_auth',
        'path_provider',
        'firebase_messaging',
        'camera',
        'permission_handler',
      ];
      for (final pkg in packages) {
        for (final platformId in PluginPlatformSupport.unsupportedPlatforms(
          pkg,
        )) {
          expect(
            PluginPlatformSupport.trackedPlatforms,
            contains(platformId),
            reason: '$pkg lists untracked platform "$platformId"',
          );
        }
      }
    });

    group('packageNameFromUri', () {
      test('extracts the package name from a package: import URI', () {
        expect(
          PluginPlatformSupport.packageNameFromUri(
            'package:sqflite/sqflite.dart',
          ),
          'sqflite',
        );
        expect(
          PluginPlatformSupport.packageNameFromUri(
            'package:firebase_messaging/firebase_messaging.dart',
          ),
          'firebase_messaging',
        );
      });

      test('returns null for non-package or malformed URIs', () {
        expect(PluginPlatformSupport.packageNameFromUri('dart:io'), isNull);
        expect(
          PluginPlatformSupport.packageNameFromUri('../relative.dart'),
          isNull,
        );
        // No slash after the package name.
        expect(PluginPlatformSupport.packageNameFromUri('package:'), isNull);
        expect(
          PluginPlatformSupport.packageNameFromUri('package:sqflite'),
          isNull,
        );
      });
    });
  });
}
