// ignore_for_file: always_specify_types

import 'dart:developer' as developer;
import 'dart:io';

import 'package:saropa_lints/src/string_slice_utils.dart';

/// Utilities for checking iOS Info.plist permission keys.
///
/// This class provides efficient, cached access to Info.plist files
/// to verify if required permission descriptions are present.
///
/// Usage:
/// ```dart
/// final checker = InfoPlistChecker.forFile('/path/to/lib/my_file.dart');
/// if (!checker.hasKey('NSCameraUsageDescription')) {
///   // Report lint warning
/// }
/// ```
class InfoPlistChecker {
  InfoPlistChecker._(
    this._projectRoot,
    this._infoPlistContent,
    this._plistMtime,
    this._plistSize,
  );

  final String _projectRoot;
  final String? _infoPlistContent;

  /// Last-modified time of `ios/Runner/Info.plist` from the stat used for this
  /// snapshot; `null` when the file was absent or the stat/read failed (so the
  /// next [forFile] call retries).
  final DateTime? _plistMtime;

  /// Byte length from the same [FileStat] as [_plistMtime]. Used with mtime so
  /// cache invalidation still works when the OS reports identical mtimes for
  /// back-to-back writes (common on Windows).
  final int? _plistSize;

  /// Cache of [InfoPlistChecker] instances per project root.
  ///
  /// This prevents re-reading and re-parsing Info.plist for every file
  /// in the same project.
  static final Map<String, InfoPlistChecker> _cache = {};

  /// Creates an [InfoPlistChecker] for a Dart file at [filePath].
  ///
  /// Returns `null` if:
  /// - The project root cannot be found (no pubspec.yaml)
  /// - The Info.plist file doesn't exist
  ///
  /// Results are cached per project root for efficiency.
  static InfoPlistChecker? forFile(String filePath) {
    final fsPath = _toFilesystemPath(filePath);
    if (fsPath == null) return null;
    final projectRoot = _findProjectRoot(fsPath);
    if (projectRoot == null) return null;

    final infoPlistPath = '$projectRoot/ios/Runner/Info.plist';
    final plistFile = File(infoPlistPath);

    DateTime? currentMtime;
    int? currentSize;
    try {
      if (plistFile.existsSync()) {
        final st = plistFile.statSync();
        currentMtime = st.modified;
        currentSize = st.size;
      }
    } catch (e, st) {
      developer.log(
        'Info.plist stat failed',
        name: 'saropa_lints',
        error: e,
        stackTrace: st,
      );
      currentMtime = null;
      currentSize = null;
    }

    final cached = _cache[projectRoot];
    if (cached != null &&
        cached._plistMtime == currentMtime &&
        cached._plistSize == currentSize) {
      return cached;
    }

    String? content;
    DateTime? storedMtime = currentMtime;
    int? storedSize = currentSize;
    if (currentMtime != null) {
      try {
        content = plistFile.readAsStringSync();
      } catch (e, st) {
        developer.log(
          'Info.plist read failed',
          name: 'saropa_lints',
          error: e,
          stackTrace: st,
        );
        content = null;
        // Do not pin mtime/size: a transient failure should retry on next analysis.
        storedMtime = null;
        storedSize = null;
      }
    }

    final checker = InfoPlistChecker._(
      projectRoot,
      content,
      storedMtime,
      storedSize,
    );
    _cache[projectRoot] = checker;
    return checker;
  }

  /// Converts analyzer paths/URIs to a filesystem path.
  ///
  /// Returns `null` for non-filesystem URI schemes (for example `package:` and
  /// `dart:`) so callers can safely skip project-root discovery.
  static String? _toFilesystemPath(String filePath) {
    final trimmed = filePath.trim();
    if (!trimmed.contains(':')) return trimmed;
    if (RegExp(r'^[A-Za-z]:[\\/]').hasMatch(trimmed)) return trimmed;
    try {
      final uri = Uri.parse(trimmed);
      if (uri.isScheme('file')) {
        final path = uri.toFilePath();
        if (path.isNotEmpty) return path;
      }
      if (uri.hasScheme) return null;
    } catch (e, st) {
      developer.log(
        'InfoPlistChecker file URI parse failed',
        name: 'saropa_lints',
        error: e,
        stackTrace: st,
      );
    }
    return trimmed;
  }

  /// Finds the project root directory by looking for pubspec.yaml.
  ///
  /// Walks up the directory tree from [filePath] until pubspec.yaml is found.
  /// Returns `null` if no pubspec.yaml is found.
  static String? _findProjectRoot(String filePath) {
    // Normalize path separators for cross-platform compatibility
    final normalizedPath = _normalizeFilesystemPath(filePath);
    if (!_isFilesystemPath(normalizedPath)) return null;

    // Start from the file's directory
    var current = normalizedPath;

    // Walk up the directory tree
    while (current.contains('/')) {
      // Move up one directory
      final lastSlash = current.lastIndexOf('/');
      if (lastSlash <= 0) break;
      current = current.prefix(lastSlash);

      // Check if pubspec.yaml exists here
      try {
        final pubspecPath = '$current/pubspec.yaml';
        if (File(pubspecPath).existsSync()) {
          return current;
        }
      } catch (e, st) {
        developer.log(
          'InfoPlistChecker _findProjectRoot file check failed',
          name: 'saropa_lints',
          error: e,
          stackTrace: st,
        );
        // Continue searching
      }
    }

    return null;
  }

  /// Normalizes file paths across platforms.
  ///
  /// Analyzer paths can come through as `/C:/...` for Windows file URIs. Strip
  /// that leading slash so parent traversal handles Windows drive roots.
  static String _normalizeFilesystemPath(String path) {
    var normalized = path.replaceAll('\\', '/');
    if (RegExp(r'^/[A-Za-z]:/').hasMatch(normalized)) {
      normalized = normalized.substring(1);
    }
    return normalized;
  }

  /// Returns true for paths that can be traversed on disk.
  static bool _isFilesystemPath(String path) {
    return path.startsWith('/') ||
        path.startsWith('//') ||
        RegExp(r'^[A-Za-z]:/').hasMatch(path);
  }

  /// Whether an Info.plist file was found and successfully read.
  bool get hasInfoPlist => _infoPlistContent != null;

  /// The project root directory path.
  String get projectRoot => _projectRoot;

  /// Checks if the Info.plist contains the specified [key].
  ///
  /// Matches `<key>keyName</key>` with tolerant whitespace inside the tags,
  /// which covers typical Info.plist XML formatting.
  ///
  /// Returns `true` if:
  /// - The key is found in Info.plist
  /// - Info.plist doesn't exist (can't verify, assume OK)
  ///
  /// Returns `false` only if Info.plist exists but doesn't contain the key.
  bool hasKey(String key) {
    // If Info.plist doesn't exist, we can't verify - assume it's OK
    // (The app won't build for iOS anyway without proper configuration)
    if (_infoPlistContent == null) return true;

    // Plist XML may use incidental whitespace inside tags; match loosely.
    final pattern = RegExp(
      '<\\s*key\\s*>\\s*${RegExp.escape(key)}\\s*<\\s*/\\s*key\\s*>',
    );
    return pattern.hasMatch(_infoPlistContent);
  }

  /// Checks if the Info.plist contains all specified [keys].
  ///
  /// Returns a list of missing keys, or an empty list if all are present.
  List<String> getMissingKeys(List<String> keys) {
    if (_infoPlistContent == null) return [];

    return keys.where((key) => !hasKey(key)).toList();
  }

  /// Clears the cache. Useful for testing.
  static void clearCache() {
    _cache.clear();
  }

  /// True when [UIBackgroundModes](https://developer.apple.com/documentation/bundleresources/information_property_list/uibackgroundmodes) includes `audio`.
  ///
  /// Uses substring checks on the plist XML (same approach as [hasKey]).
  /// Returns `true` when plist is missing so analysis does not block unknown
  /// projects.
  bool get hasIosBackgroundAudioConfigured => _hasIosBackgroundMode('audio');

  /// True when UIBackgroundModes includes `location` (background location).
  bool get hasIosBackgroundLocationConfigured =>
      _hasIosBackgroundMode('location');

  /// Whether the `UIBackgroundModes` array contains [mode].
  ///
  /// The two background-mode strings are checked WITHIN the `UIBackgroundModes`
  /// `<array>` value, not as independent substrings of the whole plist: a plist
  /// declaring background `location` only, that also contains an unrelated
  /// `<string>audio</string>` elsewhere, previously reported audio as
  /// configured. Returns `true` when the plist is missing so analysis does not
  /// block unknown projects (same convention as [hasKey]).
  bool _hasIosBackgroundMode(String mode) {
    final c = _infoPlistContent;
    if (c == null) return true;

    final keyMatch = RegExp(
      r'<\s*key\s*>\s*UIBackgroundModes\s*<\s*/\s*key\s*>',
    ).firstMatch(c);
    if (keyMatch == null) return false;

    // The array is the value immediately following the key in the plist dict.
    final afterKey = c.substring(keyMatch.end);
    final arrayMatch = RegExp(
      r'<\s*array\s*>(.*?)<\s*/\s*array\s*>',
      dotAll: true,
    ).firstMatch(afterKey);
    if (arrayMatch == null) return false;

    final arrayBody = arrayMatch.group(1) ?? '';
    final modePattern = RegExp(
      '<\\s*string\\s*>\\s*${RegExp.escape(mode)}\\s*<\\s*/\\s*string\\s*>',
    );
    return modePattern.hasMatch(arrayBody);
  }
}

/// Maps permission-requiring types to their required Info.plist keys.
///
/// Each entry maps a class/type name to one or more required plist keys.
class IosPermissionMapping {
  const IosPermissionMapping._();

  /// Maps class names to required Info.plist keys.
  ///
  /// Note: ImagePicker is NOT included here because the rule uses
  /// smart method-level detection to check the actual ImageSource
  /// (gallery vs camera) and only require the relevant permission.
  /// See RequireIosPermissionDescription in ios_capabilities_permissions_rules.dart.
  static const Map<String, List<String>> typeToKeys = {
    // Camera/Photo
    // Note: ImagePicker handled separately with smart source detection
    'CameraPlatform': ['NSCameraUsageDescription'],
    'CameraController': ['NSCameraUsageDescription'],

    // Location
    'Geolocator': ['NSLocationWhenInUseUsageDescription'],
    'LocationService': ['NSLocationWhenInUseUsageDescription'],
    'Location': ['NSLocationWhenInUseUsageDescription'],

    // Speech/Audio
    'SpeechToText': [
      'NSSpeechRecognitionUsageDescription',
      'NSMicrophoneUsageDescription',
    ],
    'FlutterSoundRecorder': ['NSMicrophoneUsageDescription'],
    'AudioRecorder': ['NSMicrophoneUsageDescription'],
    'Record': ['NSMicrophoneUsageDescription'],

    // Contacts
    'FlutterContacts': ['NSContactsUsageDescription'],
    'ContactsService': ['NSContactsUsageDescription'],

    // Calendar
    'DeviceCalendar': ['NSCalendarsUsageDescription'],
    'DeviceCalendarPlugin': ['NSCalendarsUsageDescription'],

    // Bluetooth
    'FlutterBluePlus': ['NSBluetoothAlwaysUsageDescription'],
    'FlutterBlue': ['NSBluetoothAlwaysUsageDescription'],

    // Biometrics
    'LocalAuthentication': ['NSFaceIDUsageDescription'],

    // Health
    'Health': [
      'NSHealthShareUsageDescription',
      'NSHealthUpdateUsageDescription',
    ],
    'HealthKitReporter': [
      'NSHealthShareUsageDescription',
      'NSHealthUpdateUsageDescription',
    ],
  };

  /// Gets the required Info.plist keys for a given type name.
  ///
  /// Returns `null` if the type doesn't require any permissions.
  static List<String>? getRequiredKeys(String typeName) {
    return typeToKeys[typeName];
  }

  /// Returns a human-readable description of required keys for a type.
  static String getRequiredKeysDescription(String typeName) {
    final keys = typeToKeys[typeName];
    if (keys == null || keys.isEmpty) return '';
    return keys.join(' + ');
  }
}
