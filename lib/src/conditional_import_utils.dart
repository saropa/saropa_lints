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
/// `prefer_platform_io_conditional` and `require_platform_check` rules to skip
/// reporting in such files.
///
/// **How it works:** On first use per project root we scan `lib/`, parse each
/// Dart file, and collect the URIs from the `configurations` of both `import`
/// and `export` directives whose condition is `dart.library.io` or
/// `dart.library.ffi` (a conditional `export '...' if (dart.library.io) ...`
/// is just as much a native-only branch as a conditional `import`). We also
/// treat any `*_io.dart` file that has a sibling `*_stub.dart` in the same
/// directory as native-only — the convention itself is the guard, even when
/// the wiring directive uses an unusual form we did not resolve.
///
/// To avoid over-suppression we additionally collect every file reached by an
/// UNCONDITIONAL `import`/`export` (the directive's default URI). A file that
/// is reachable unconditionally can load on web, so it is removed from the
/// native-only set even if some other directive references it conditionally.
///
/// URIs are resolved to absolute paths (relative and same-package `package:`
/// URIs) and cached. No recursion; single pass per file. I/O and parse errors
/// are logged and skipped.
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
import 'package:saropa_lints/src/string_slice_utils.dart';

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
/// import/export by scanning lib/ and parsing directives. Files reachable
/// through an unconditional import/export are excluded because they can still
/// load on web (so a kIsWeb guard is genuinely required there).
Set<String> _buildNativeOnlyTargets(String projectRoot) {
  final libDir = Directory(p.join(projectRoot, 'lib'));
  if (!libDir.existsSync()) return <String>{};

  // Native-only candidates (io/ffi-conditional targets + sibling-stub pairs)
  // and the set of files reachable unconditionally. We subtract the latter
  // from the former so a file that is ALSO imported unconditionally is not
  // suppressed (it can run on web).
  final nativeOnly = <String>{};
  final unconditional = <String>{};

  try {
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      _collectTargetsFromFile(entity.path, projectRoot, nativeOnly, unconditional);
      _collectSiblingStubTarget(entity.path, nativeOnly);
    }
  } on OSError catch (e, st) {
    developer.log(
      'listSync failed for native-only targets',
      name: 'saropa_lints',
      error: e,
      stackTrace: st,
    );
  }

  return nativeOnly.difference(unconditional);
}

/// Parse one file's `import`/`export` directives, recording io/ffi-conditional
/// targets into [nativeOnly] and unconditional default-URI targets into
/// [unconditional]. Both `ImportDirective` and `ExportDirective` are
/// `NamespaceDirective`s exposing `.uri` and `.configurations`, so the same
/// pass covers a conditional `export '...' if (dart.library.io) ...` exactly
/// like the import form.
void _collectTargetsFromFile(
  String importingFilePath,
  String projectRoot,
  Set<String> nativeOnly,
  Set<String> unconditional,
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
  if (parseResult.errors.isNotEmpty) return;

  final packageName = ProjectContext.getPackageName(projectRoot);

  for (final directive in unit.directives) {
    if (directive is! NamespaceDirective) continue;

    // The default URI (used when no configuration matches) is reachable
    // unconditionally — it is the stub on web for a conditional directive, or
    // the only target for a plain directive. Record it so a file imported both
    // conditionally and unconditionally stays out of the native-only set.
    final defaultUri = directive.uri.stringValue;
    if (defaultUri != null && defaultUri.isNotEmpty) {
      final resolvedDefault = _resolveUri(
        defaultUri,
        importingFilePath,
        projectRoot,
        packageName,
      );
      if (resolvedDefault != null) {
        unconditional.add(normalizePath(resolvedDefault));
      }
    }

    for (final config in directive.configurations) {
      final conditionName = config.name.toSource();
      if (!_nativeOnlyConditionNames.contains(conditionName)) continue;

      final uri = config.uri.stringValue;
      if (uri == null || uri.isEmpty) continue;

      final resolved = _resolveUri(
        uri,
        importingFilePath,
        projectRoot,
        packageName,
      );
      if (resolved != null) {
        nativeOnly.add(normalizePath(resolved));
      }
    }
  }
}

/// Cheap naming-convention fallback: a `*_io.dart` file with a sibling
/// `*_stub.dart` in the same directory is the native branch of the standard
/// stub/io split, even when the wiring directive uses a form we did not parse.
/// Mirrors the directory-probe style used elsewhere for platform detection.
void _collectSiblingStubTarget(String filePath, Set<String> nativeOnly) {
  if (!filePath.endsWith('_io.dart')) return;

  final stubPath = '${filePath.prefix(filePath.length - '_io.dart'.length)}_stub.dart';
  if (File(stubPath).existsSync()) {
    nativeOnly.add(normalizePath(filePath));
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
    final relative = uri.afterIndex(prefix.length);
    final resolved = p.normalize(p.join(projectRoot, 'lib', relative));
    return resolved.replaceAll('\\', '/');
  }

  final fromDir = File(fromFilePath).parent.path;
  final resolved = p.normalize(p.join(fromDir, uri));
  return resolved.replaceAll('\\', '/');
}
