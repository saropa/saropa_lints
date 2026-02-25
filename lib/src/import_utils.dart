// ignore_for_file: depend_on_referenced_packages

/// Utilities for checking package imports in Dart files.
///
/// These utilities help rules scope themselves to files that actually use
/// specific packages, preventing false positives in unrelated code.
library;

import 'package:analyzer/dart/ast/ast.dart';

/// Check if the file containing [node] imports any of the specified packages.
///
/// This prevents false positives by ensuring package-specific rules only run
/// on files that actually use those packages.
///
/// Example:
/// ```dart
/// // Only apply Dio rules to files importing Dio
/// if (!fileImportsPackage(node, {'package:dio/'})) return;
/// ```
///
/// The [packagePrefixes] should be package URI prefixes like 'package:dio/'.
bool fileImportsPackage(AstNode node, Set<String> packagePrefixes) {
  // Walk up to find the CompilationUnit
  AstNode? current = node;
  while (current != null && current is! CompilationUnit) {
    current = current.parent;
  }

  if (current is! CompilationUnit) return false;

  // Check if any import directive matches the package prefixes
  for (final directive in current.directives) {
    if (directive is ImportDirective) {
      final uri = directive.uri.stringValue ?? '';
      if (packagePrefixes.any((pkg) => uri.startsWith(pkg))) {
        return true;
      }
    }
  }

  return false;
}

/// Common package import sets for reuse across rules.
///
/// These constants define which package imports trigger specific rules.
class PackageImports {
  PackageImports._();

  /// Dio HTTP client package imports.
  static const Set<String> dio = {'package:dio/'};

  /// Geolocator package imports.
  static const Set<String> geolocator = {'package:geolocator/'};

  /// Connectivity packages (both legacy and current).
  static const Set<String> connectivity = {
    'package:connectivity_plus/',
    'package:connectivity/', // Legacy package
  };

  /// Firebase Messaging package imports.
  static const Set<String> firebaseMessaging = {'package:firebase_messaging/'};

  /// Permission Handler package imports.
  static const Set<String> permissionHandler = {'package:permission_handler/'};

  /// GoRouter package imports.
  static const Set<String> goRouter = {'package:go_router/'};

  /// Riverpod packages (all variants).
  static const Set<String> riverpod = {
    'package:riverpod/',
    'package:flutter_riverpod/',
    'package:hooks_riverpod/',
    'package:riverpod_annotation/',
  };

  /// Hive database package imports.
  static const Set<String> hive = {'package:hive/', 'package:hive_flutter/'};

  /// GetIt service locator package imports.
  static const Set<String> getIt = {'package:get_it/'};

  /// Provider package imports.
  static const Set<String> provider = {'package:provider/'};

  /// Bloc packages.
  static const Set<String> bloc = {'package:bloc/', 'package:flutter_bloc/'};

  /// Firebase Auth package imports.
  static const Set<String> firebaseAuth = {'package:firebase_auth/'};

  /// Isar database package imports.
  static const Set<String> isar = {'package:isar/'};

  /// Drift database package imports.
  static const Set<String> drift = {'package:drift/', 'package:drift_flutter/'};

  /// SQFlite database package imports.
  static const Set<String> sqflite = {'package:sqflite/'};

  /// Image Picker package imports.
  static const Set<String> imagePicker = {'package:image_picker/'};

  /// Cached Network Image package imports.
  static const Set<String> cachedNetworkImage = {
    'package:cached_network_image/',
  };

  /// URL Launcher package imports.
  static const Set<String> urlLauncher = {'package:url_launcher/'};
}

// =============================================================================
// Import Group Classification
// =============================================================================

/// Group IDs for import classification.
///
/// Group 0 = dart: SDK imports, Group 1 = package: imports, Group 2 = relative.
abstract final class ImportGroup {
  static const int dart = 0;
  static const int package = 1;
  static const int relative = 2;

  /// Doc-comment section headers for each import group.
  static const Map<int, String> headers = <int, String>{
    dart: '/// Dart imports',
    package: '/// Package imports',
    relative: '/// Relative imports',
  };

  /// Classify an [ImportDirective] into a group ID.
  static int classify(ImportDirective directive) {
    final uri = directive.uri.stringValue ?? '';
    if (uri.startsWith('dart:')) return dart;
    if (uri.startsWith('package:')) return package;
    return relative;
  }

  /// Returns true if the file content between [start] and [end] contains
  /// any comment lines (// or ///), excluding blank lines and whitespace.
  static bool hasCommentsBetween(String content, int start, int end) {
    if (start >= end || start < 0 || end > content.length) return false;
    final segment = content.substring(start, end);
    for (final line in segment.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('//')) return true;
      if (trimmed.startsWith('/*')) return true;
    }
    return false;
  }
}
