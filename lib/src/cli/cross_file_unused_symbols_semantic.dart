import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:path/path.dart' as p;

import 'package:saropa_lints/src/cli/cross_file_reporter.dart';
import 'package:saropa_lints/src/string_slice_utils.dart';

/// Resolves the project with the analyzer and reports top-level declarations
/// that have no references from other compilation units in [includedPaths].
///
/// Normalizes paths for [PhysicalResourceProvider]. The cross-file CLI falls
/// back to regex heuristics on resolution failure or when
/// [UnusedSymbolsOptions.forceHeuristic] is set.
Future<Map<String, List<String>>> analyzeUnusedTopLevelSymbolsSemantic({
  required String projectPath,
  required Set<String> includedPaths,
  required UnusedSymbolsOptions options,
}) async {
  final provider = PhysicalResourceProvider.INSTANCE;
  final pathContext = provider.pathContext;
  String normDriverPath(String path) =>
      pathContext.normalize(File(path).absolute.path);

  final absRoot = normDriverPath(projectPath);
  final rootPosix = absRoot.replaceAll('\\', '/');
  final includedNorm = <String>{
    for (final path in includedPaths) normDriverPath(path),
  };

  final fileContents = <String, String>{};
  final exportedLibFiles = <String>{};
  final libDartFiles = <String>[];

  for (final filePath in includedNorm.where((path) => path.endsWith('.dart'))) {
    final file = File(filePath);
    if (!file.existsSync()) continue;
    final content = file.readAsStringSync();
    fileContents[filePath] = content;

    final rel = _relativePath(rootPosix, filePath);
    if (rel.startsWith('lib/') && !_isGeneratedDart(rel)) {
      libDartFiles.add(filePath);
      if (content.contains(RegExp(r'^\s*export\s+', multiLine: true))) {
        exportedLibFiles.add(filePath);
      }
    }
  }

  final exportsByFile = <String, Set<String>>{};
  for (final filePath in libDartFiles) {
    final content = fileContents[filePath] ?? '';
    final exports = <String>{};
    for (final m in RegExp(
      r'''export\s+['"]([^'"]+)['"]''',
    ).allMatches(content)) {
      final raw = m.group(1);
      if (raw == null) continue;
      if (raw.startsWith('dart:') || raw.startsWith('package:')) continue;
      final joined = p.join(p.dirname(filePath), raw);
      final resolved = normDriverPath(joined);
      if (resolved.endsWith('.dart')) {
        exports.add(resolved);
      }
    }
    exportsByFile[filePath] = exports;
  }

  final publicApiFiles = <String>{...exportedLibFiles};
  for (final file in exportedLibFiles) {
    publicApiFiles.addAll(exportsByFile[file] ?? const <String>{});
  }

  final collection = AnalysisContextCollection(
    includedPaths: <String>[absRoot],
    resourceProvider: provider,
  );

  try {
    final declared = <Element, String>{};
    for (final filePath in libDartFiles) {
      if (options.excludePublicApi && publicApiFiles.contains(filePath)) {
        continue;
      }
      final ctx = collection.contextFor(filePath);
      final result = await ctx.currentSession.getResolvedUnit(filePath);
      if (result is! ResolvedUnitResult) continue;
      _collectTopLevelDeclarations(
        unit: result.unit,
        definingFile: filePath,
        declared: declared,
        options: options,
      );
    }

    final externallyReferenced = <Element>{};
    for (final filePath in includedNorm.where(
      (path) => path.endsWith('.dart'),
    )) {
      final file = File(filePath);
      if (!file.existsSync()) continue;
      final ctx = collection.contextFor(filePath);
      final result = await ctx.currentSession.getResolvedUnit(filePath);
      if (result is! ResolvedUnitResult) continue;
      final visitor = _ExternalReferenceVisitor(
        referencingFile: filePath,
        declared: declared,
        externallyReferenced: externallyReferenced,
      );
      result.unit.accept(visitor);
    }

    final unusedByFile = <String, List<String>>{};
    for (final entry in declared.entries) {
      final element = entry.key;
      final definingFile = entry.value;
      if (externallyReferenced.contains(element)) continue;
      final name = element.name;
      if (name == null || name.isEmpty) continue;
      unusedByFile
          .putIfAbsent(_relativePath(rootPosix, definingFile), () => <String>[])
          .add(name);
    }

    for (final list in unusedByFile.values) {
      list.sort();
    }
    return unusedByFile;
  } finally {
    await collection.dispose();
  }
}

void _collectTopLevelDeclarations({
  required CompilationUnit unit,
  required String definingFile,
  required Map<Element, String> declared,
  required UnusedSymbolsOptions options,
}) {
  final batch = <Element, String>{};
  void register(Element? element) {
    if (element == null || !identical(element, element.nonSynthetic)) return;
    if (!options.includePrivate && element.isPrivate) return;
    final name = element.name;
    if (name == null || name.isEmpty) return;
    if (name == 'main') return;
    final md = element.metadata;
    if (md.hasVisibleForTesting || md.hasProtected || md.hasOverride) return;
    batch[element] = definingFile;
  }

  for (final member in unit.declarations) {
    if (member is FunctionDeclaration) {
      register(member.declaredFragment?.element);
    } else if (member is ClassDeclaration) {
      register(member.declaredFragment?.element);
    } else if (member is EnumDeclaration) {
      register(member.declaredFragment?.element);
    } else if (member is MixinDeclaration) {
      register(member.declaredFragment?.element);
    } else if (member is ExtensionDeclaration) {
      register(member.declaredFragment?.element);
    } else if (member is TopLevelVariableDeclaration) {
      for (final variable in member.variables.variables) {
        register(variable.declaredFragment?.element);
      }
    } else if (member is FunctionTypeAlias) {
      register(member.declaredFragment?.element);
    } else if (member is GenericTypeAlias) {
      register(member.declaredFragment?.element);
    } else if (member is ClassTypeAlias) {
      register(member.declaredFragment?.element);
    }
  }
  declared.addAll(batch);
}

class _ExternalReferenceVisitor extends RecursiveAstVisitor<void> {
  _ExternalReferenceVisitor({
    required this.referencingFile,
    required this.declared,
    required this.externallyReferenced,
  });

  final String referencingFile;
  final Map<Element, String> declared;
  final Set<Element> externallyReferenced;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    _handleElement(node.element);
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    _handleElement(node.element);
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitNamedType(NamedType node) {
    // Type names use a Token, not a SimpleIdentifier; use resolved [element].
    _handleElement(node.element);
    super.visitNamedType(node);
  }

  void _handleElement(Element? raw) {
    if (raw == null) return;
    final target = _normalizeReferencedElement(raw.nonSynthetic);
    final definingFile = declared[target];
    if (definingFile == null) return;
    if (_pathsEqual(definingFile, referencingFile)) return;
    externallyReferenced.add(target);
  }
}

Element _normalizeReferencedElement(Element e) {
  if (e is ConstructorElement) {
    return e.enclosingElement;
  }
  if (e is PropertyAccessorElement && e.isOriginVariable) {
    return e.variable.nonSynthetic;
  }
  return e;
}

bool _pathsEqual(String a, String b) =>
    p.normalize(a).replaceAll('\\', '/') ==
    p.normalize(b).replaceAll('\\', '/');

String _relativePath(String rootPosix, String absolutePath) {
  final normalized = p.normalize(absolutePath).replaceAll('\\', '/');
  if (!normalized.startsWith(rootPosix)) return normalized;
  return normalized.afterIndex(rootPosix.length).replaceFirst(RegExp('^/'), '');
}

bool _isGeneratedDart(String relativePath) {
  final lower = relativePath.toLowerCase();
  return lower.endsWith('.g.dart') ||
      lower.endsWith('.freezed.dart') ||
      lower.endsWith('.gr.dart') ||
      lower.contains('/generated/');
}
