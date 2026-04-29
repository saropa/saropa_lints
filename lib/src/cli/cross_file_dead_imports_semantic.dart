import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:path/path.dart' as p;

import 'package:saropa_lints/src/string_slice_utils.dart';

/// Relative dead imports using the analyzer's unused-import diagnostics
/// (semantic; respects resolution). Only `dart:` / `package:` imports are
/// excluded by definition; this maps diagnostics whose
/// [Diagnostic.diagnosticCode] is `unused_import` on relative `import '...';`
/// directives to the same result shape as the regex heuristic.
Future<Map<String, List<String>>> analyzeDeadImportsSemantic({
  required String projectPath,
  required Set<String> includedPaths,
}) async {
  final provider = PhysicalResourceProvider.INSTANCE;
  final pathContext = provider.pathContext;
  String normPath(String path) =>
      pathContext.normalize(File(path).absolute.path);

  final absRoot = normPath(projectPath);
  final rootPosix = absRoot.replaceAll('\\', '/');
  final includedNorm = <String>{
    for (final path in includedPaths) normPath(path),
  };

  final collection = AnalysisContextCollection(
    includedPaths: <String>[absRoot],
    resourceProvider: provider,
  );

  try {
    final result = <String, List<String>>{};
    for (final filePath in includedNorm.where((e) => e.endsWith('.dart'))) {
      if (!File(filePath).existsSync()) continue;
      try {
        final ctx = collection.contextFor(filePath);
        final resolved = await ctx.currentSession.getResolvedUnit(filePath);
        if (resolved is! ResolvedUnitResult) continue;

        final dead = _unusedRelativeImportsFromDiagnostics(
          filePath: filePath,
          unit: resolved.unit,
          diagnostics: resolved.diagnostics,
          includedNorm: includedNorm,
          normPath: normPath,
        );
        if (dead.isNotEmpty) {
          dead.sort();
          result[_relativePath(rootPosix, filePath)] = dead;
        }
      } on Object {
        // Large monorepos / mixed roots: skip files the driver cannot resolve.
        continue;
      }
    }
    return result;
  } finally {
    try {
      await collection.dispose();
    } on Object catch (e) {
      // Best-effort: driver disposal can fail if the context was left inconsistent.
      stderr.writeln('cross_file dead-imports: context dispose failed: $e');
    }
  }
}

List<String> _unusedRelativeImportsFromDiagnostics({
  required String filePath,
  required CompilationUnit unit,
  required Iterable<Object?> diagnostics,
  required Set<String> includedNorm,
  required String Function(String) normPath,
}) {
  final dead = <String>[];
  for (final raw in diagnostics) {
    if (raw is! Diagnostic) continue;
    final diag = raw;
    if (!_isUnusedImportDiagnostic(diag)) continue;
    final offset = _diagOffset(diag);
    if (offset == null) continue;
    ImportDirective? directive;
    for (final d in unit.directives.whereType<ImportDirective>()) {
      final r = d.sourceRange;
      if (offset >= r.offset && offset < r.end) {
        directive = d;
        break;
      }
    }
    if (directive == null) continue;
    if (_isUsedDeferredImport(directive: directive, unit: unit)) continue;
    final uri = directive.uri.stringValue;
    if (uri == null || uri.startsWith('dart:') || uri.startsWith('package:')) {
      continue;
    }
    final importedAbs = normPath(p.join(p.dirname(filePath), uri));
    final importedPosix = importedAbs.replaceAll('\\', '/');
    if (!includedNorm.contains(importedPosix)) continue;
    dead.add(uri);
  }
  return dead;
}

bool _isUnusedImportDiagnostic(Diagnostic diag) {
  final id = diag.diagnosticCode.lowerCaseUniqueName;
  return id == 'unused_import';
}

int? _diagOffset(Diagnostic diag) => diag.offset;

bool _isUsedDeferredImport({
  required ImportDirective directive,
  required CompilationUnit unit,
}) {
  if (directive.deferredKeyword == null) return false;
  final prefix = directive.prefix?.name;
  if (prefix == null || prefix.isEmpty) {
    // `deferred as <prefix>` should always include a prefix, but be defensive.
    return false;
  }
  final visitor = _DeferredPrefixUsageVisitor(
    prefix: prefix,
    importDirectiveOffset: directive.offset,
  );
  unit.visitChildren(visitor);
  return visitor.isUsed;
}

class _DeferredPrefixUsageVisitor extends RecursiveAstVisitor<void> {
  _DeferredPrefixUsageVisitor({
    required this.prefix,
    required this.importDirectiveOffset,
  });

  final String prefix;
  final int importDirectiveOffset;
  var isUsed = false;

  @override
  void visitImportDirective(ImportDirective node) {
    // Import directives are declarations, not usage sites.
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (isUsed) return;
    if (node.offset == importDirectiveOffset) return;
    if (node.prefix.name == prefix) {
      isUsed = true;
      return;
    }
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (isUsed) return;
    final target = node.target;
    if (target is SimpleIdentifier && target.name == prefix) {
      isUsed = true;
      return;
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (isUsed) return;
    final target = node.target;
    if (target is SimpleIdentifier && target.name == prefix) {
      isUsed = true;
      return;
    }
    super.visitPropertyAccess(node);
  }
}

String _relativePath(String rootPosix, String absolutePath) {
  final normalized = p.normalize(absolutePath).replaceAll('\\', '/');
  if (!normalized.startsWith(rootPosix)) return normalized;
  return normalized.afterIndex(rootPosix.length).replaceFirst(RegExp('^/'), '');
}
