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
  static const Set<String> hive = {
    'package:hive/',
    'package:hive_flutter/',
  };

  /// GetIt service locator package imports.
  static const Set<String> getIt = {'package:get_it/'};

  /// Provider package imports.
  static const Set<String> provider = {'package:provider/'};

  /// Bloc packages.
  static const Set<String> bloc = {
    'package:bloc/',
    'package:flutter_bloc/',
  };

  /// Firebase Auth package imports.
  static const Set<String> firebaseAuth = {'package:firebase_auth/'};

  /// Isar database package imports.
  static const Set<String> isar = {'package:isar/'};

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
