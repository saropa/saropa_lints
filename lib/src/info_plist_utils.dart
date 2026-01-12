// ignore_for_file: always_specify_types

import 'dart:io';

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
  InfoPlistChecker._(this._projectRoot, this._infoPlistContent);

  final String _projectRoot;
  final String? _infoPlistContent;

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
    final projectRoot = _findProjectRoot(filePath);
    if (projectRoot == null) return null;

    // Return cached instance if available
    if (_cache.containsKey(projectRoot)) {
      return _cache[projectRoot];
    }

    // Try to read Info.plist
    final infoPlistPath = '$projectRoot/ios/Runner/Info.plist';
    String? content;

    try {
      final file = File(infoPlistPath);
      if (file.existsSync()) {
        content = file.readAsStringSync();
      }
    } catch (_) {
      // File doesn't exist or can't be read - that's OK
    }

    final checker = InfoPlistChecker._(projectRoot, content);
    _cache[projectRoot] = checker;
    return checker;
  }

  /// Finds the project root directory by looking for pubspec.yaml.
  ///
  /// Walks up the directory tree from [filePath] until pubspec.yaml is found.
  /// Returns `null` if no pubspec.yaml is found.
  static String? _findProjectRoot(String filePath) {
    // Normalize path separators for cross-platform compatibility
    final normalizedPath = filePath.replaceAll('\\', '/');

    // Start from the file's directory
    var current = normalizedPath;

    // Walk up the directory tree
    while (current.contains('/')) {
      // Move up one directory
      final lastSlash = current.lastIndexOf('/');
      if (lastSlash <= 0) break;
      current = current.substring(0, lastSlash);

      // Check if pubspec.yaml exists here
      try {
        final pubspecPath = '$current/pubspec.yaml';
        if (File(pubspecPath).existsSync()) {
          return current;
        }
      } catch (_) {
        // Continue searching
      }
    }

    return null;
  }

  /// Whether an Info.plist file was found and successfully read.
  bool get hasInfoPlist => _infoPlistContent != null;

  /// The project root directory path.
  String get projectRoot => _projectRoot;

  /// Checks if the Info.plist contains the specified [key].
  ///
  /// This performs a simple string search for `<key>keyName</key>` pattern,
  /// which is reliable for standard Info.plist format.
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

    // Check for the key in plist format: <key>NSCameraUsageDescription</key>
    return _infoPlistContent!.contains('<key>$key</key>');
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
}

/// Maps permission-requiring types to their required Info.plist keys.
///
/// Each entry maps a class/type name to one or more required plist keys.
class IosPermissionMapping {
  const IosPermissionMapping._();

  /// Maps class names to required Info.plist keys.
  static const Map<String, List<String>> typeToKeys = {
    // Camera/Photo
    'ImagePicker': [
      'NSPhotoLibraryUsageDescription',
      'NSCameraUsageDescription',
    ],
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
