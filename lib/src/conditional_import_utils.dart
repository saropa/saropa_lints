// ignore_for_file: depend_on_referenced_packages

/// Conditional import detection for platform (dart:io) rules.
///
/// **Purpose:** Flutter projects often use conditional imports so that on web a
/// stub is used and on native the real implementation (using `dart:io`
/// `Platform`) is used. Files that are only ever imported when
/// `dart.library.io` or `dart.library.ffi` is defined are never loaded on web,
/// so requiring a `kIsWeb` guard inside them is a false positive.
///
/// **Usage:** [isNativeOnlyConditionalImportTarget] is used by the
/// `prefer_platform_io_conditional` rule to skip reporting in such files.
///
/// **How it works:** On first use per project root we scan `lib/`, parse each
/// Dart file, and collect the URIs from `ImportDirective.configurations` whose
/// condition is `dart.library.io` or `dart.library.ffi`. Those URIs are
/// resolved to absolute paths (relative and same-package `package:` URIs) and
/// cached. No recursion; single pass per file. I/O and parse errors are logged
/// and skipped.
///
/// **Performance:** One lazy scan per project (cached in [_nativeOnlyTargetsByProject]).
/// Subsequent calls for the same project are O(1) set lookups.
library;

import 'dart:developer' as developer;
import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:path/path.dart' as p;

import 'project_context.dart';

/// Condition names that mean "native only" (file is not loaded on web).
const Set<String> _nativeOnlyConditionNames = {
  'dart.library.io',
  'dart.library.ffi',
};

/// Cache: project root -> set of normalized file paths that are the native
/// branch of a conditional import. Built lazily per project.
final Map<String, Set<String>> _nativeOnlyTargetsByProject = {};

/// Returns true if [filePath] is the target of a conditional import that
/// uses [dart.library.io] or [dart.library.ffi], so the file is only loaded
/// on native (never on web). Such files do not need kIsWeb guards for
/// Platform usage.
///
/// Used by [PreferPlatformIoConditionalRule] to avoid false positives.
bool isNativeOnlyConditionalImportTarget(String? filePath) {
  if (filePath == null || filePath.isEmpty) return false;
  final projectRoot = ProjectContext.findProjectRoot(filePath);
  if (projectRoot == null || projectRoot.isEmpty) return false;

  final normalizedPath = normalizePath(filePath);
  final targets = _nativeOnlyTargetsByProject.putIfAbsent(
    projectRoot,
    () => _buildNativeOnlyTargets(projectRoot),
  );
  return targets.contains(normalizedPath);
}

/// Build the set of file paths that are the io/ffi branch of a conditional
/// import by scanning lib/ and parsing import directives.
Set<String> _buildNativeOnlyTargets(String projectRoot) {
  final result = <String>{};
  final libDir = Directory(p.join(projectRoot, 'lib'));
  if (!libDir.existsSync()) return result;

  try {
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      _collectNativeOnlyTargetsFromFile(entity.path, projectRoot, result);
    }
  } on OSError catch (e, st) {
    developer.log(
      'listSync failed for native-only targets',
      name: 'saropa_lints',
      error: e,
      stackTrace: st,
    );
  }
  return result;
}

void _collectNativeOnlyTargetsFromFile(
  String importingFilePath,
  String projectRoot,
  Set<String> out,
) {
  final file = File(importingFilePath);
  if (!file.existsSync()) return;

  String content;
  try {
    content = file.readAsStringSync();
  } on IOException catch (e, st) {
    developer.log(
      'read failed for native-only scan',
      name: 'saropa_lints',
      error: e,
      stackTrace: st,
    );
    return;
  }

  final parseResult = parseString(content: content, path: importingFilePath);
  final unit = parseResult.unit;
  if (!parseResult.errors.isEmpty) return;

  final packageName = ProjectContext.getPackageName(projectRoot);

  for (final directive in unit.directives) {
    if (directive is! ImportDirective) continue;
    final configs = directive.configurations;
    if (configs.isEmpty) continue;

    for (final config in configs) {
      final conditionName = config.name.toSource();
      if (!_nativeOnlyConditionNames.contains(conditionName)) continue;

      final uriLiteral = config.uri;
      final uri = uriLiteral.stringValue;
      if (uri == null || uri.isEmpty) continue;

      final resolved = _resolveUri(
        uri,
        importingFilePath,
        projectRoot,
        packageName,
      );
      if (resolved != null) {
        out.add(normalizePath(resolved));
      }
    }
  }
}

/// Resolves an import URI to an absolute file path, or null if not in this project.
String? _resolveUri(
  String uri,
  String fromFilePath,
  String projectRoot,
  String packageName,
) {
  if (uri.startsWith('dart:')) return null;
  if (uri.startsWith('package:')) {
    if (packageName.isEmpty) return null;
    final prefix = 'package:$packageName/';
    if (!uri.startsWith(prefix)) return null;
    final relative = uri.substring(prefix.length);
    final resolved = p.normalize(p.join(projectRoot, 'lib', relative));
    return resolved.replaceAll('\\', '/');
  }
  final fromDir = File(fromFilePath).parent.path;
  final resolved = p.normalize(p.join(fromDir, uri));
  return resolved.replaceAll('\\', '/');
}
