/// **Element-resolved usage counting** for the project vibrancy scan.
///
/// The default usage signal in [runProjectVibrancy] is *name-based*: it counts
/// how many times an identifier *string* appears and attributes every `foo` to
/// any declaration named `foo`. That over-counts on name collisions (a private
/// `_dispose` in 40 files all read as heavily used) and inflates counts from
/// shadowed locals/parameters — hiding true orphans.
///
/// This collector resolves each reference to the declaration it actually binds
/// to (via the analyzer element model) and counts it against that declaration's
/// stable id, so a function's count reflects its real callers. It also computes
/// the **entry-point set**: declarations that are runtime-invoked rather than
/// statically called (`main`, `@pragma('vm:entry-point')`, framework lifecycle
/// `@override`s) and must therefore never be flagged `unused`.
///
/// **Degrade-safe by design.** Resolution loads the project element model and
/// can fail (broken source mid-edit, SDK mismatch, a path outside the context).
/// On any failure the function returns `null` (caller keeps the name-based
/// count) and on a partial failure it reports [ResolvedUsage.fullyResolved] =
/// false, which the caller uses to refuse a zero-caller `unused` verdict it
/// cannot trust — biasing toward false negatives (a missed orphan) over the far
/// worse false positive (live code flagged dead). See the source plan
/// `plans/PLAN_vibrancy_usage_collector_element_resolution.md` Phases 1-2.
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/source/line_info.dart';

/// Output of one resolved usage pass.
class ResolvedUsage {
  const ResolvedUsage({
    required this.countsById,
    required this.entryPointIds,
    required this.fullyResolved,
  });

  /// `declarationId -> number of static callers outside the declaration's own
  /// body`. Keys use the same `filePath:name:lineStart` shape the parse phase
  /// builds for `_FunctionNode.id`, so the caller looks counts up directly.
  final Map<String, int> countsById;

  /// Ids of declarations that are runtime-invoked entry points. A zero-count
  /// entry point still scores on real refs, but must NOT be flagged `unused`.
  final Set<String> entryPointIds;

  /// True only when EVERY requested file resolved. When false, a `0` count is
  /// untrustworthy (a caller may live in a file that failed to resolve), so the
  /// caller falls back to the name-based count rather than flag `unused`.
  final bool fullyResolved;
}

/// Resolves [targetFiles] under [projectPath] and counts references per
/// declaration. Returns `null` if the whole pass cannot run (no usable
/// analysis context, fatal analyzer error) — the caller then keeps the
/// name-based counts unchanged.
///
/// [targetFiles] must be the SAME absolute path strings the parse phase used to
/// build `_FunctionNode.id` (lib files plus test files); ids are rebuilt from
/// these strings so the caller's `countsById[fn.id]` lookup matches.
///
/// No cooperative pause/cancel gate runs inside this pass: the catch-all that
/// makes it degrade-safe would also swallow a cancel thrown by a gate, turning
/// an abort into a silent name-based fallback. The caller's score loop gates on
/// the very next unit of work, so a cancel during resolution simply takes effect
/// one phase later.
Future<ResolvedUsage?> collectResolvedUsage({
  required String projectPath,
  required List<String> targetFiles,
  void Function(int done, int total)? onProgress,
}) async {
  if (targetFiles.isEmpty) {
    return const ResolvedUsage(
      countsById: <String, int>{},
      entryPointIds: <String>{},
      fullyResolved: true,
    );
  }
  final provider = PhysicalResourceProvider.INSTANCE;
  final pathContext = provider.pathContext;
  final absRoot = pathContext.normalize(Directory(projectPath).absolute.path);

  // Scope to concrete package directories (lib/, test/, bin/) instead of
  // the project root. A root-level includedPaths discovers nested package
  // roots (example/, self_check/, build/test_tmp/…) and splits the
  // collection into multiple analysis contexts — contextFor() then fails
  // for lib/ files, silently degrading every function to name-based
  // counting and reintroducing the false positives this pass exists to fix.
  // Using the actual package dirs means the analyzer finds only the root
  // pubspec.yaml and creates one context that resolves every target file.
  final packageDirs = <String>[
    for (final dir in const <String>['lib', 'test', 'bin'])
      pathContext.join(absRoot, dir),
  ].where((d) => Directory(d).existsSync()).toList();
  // Fallback: if none of the standard dirs exist, use the root (the caller
  // likely has a non-standard layout — degrade-safe catches the rest).
  if (packageDirs.isEmpty) packageDirs.add(absRoot);
  final collection = AnalysisContextCollection(
    includedPaths: packageDirs,
    resourceProvider: provider,
  );
  try {
    final declToId = <Element, String>{};
    final refCounts = <Element, int>{};
    final entryPointIds = <String>{};
    var fullyResolved = true;
    var done = 0;

    for (final idPath in targetFiles) {
      done++;
      onProgress?.call(done, targetFiles.length);
      // `idPath` is the string baked into `_FunctionNode.id`; the analyzer needs
      // its own driver-normalized form, which can differ in separators/casing.
      final driverPath = pathContext.normalize(File(idPath).absolute.path);
      final ResolvedUnitResult unit;
      try {
        final ctx = collection.contextFor(driverPath);
        final result = await ctx.currentSession.getResolvedUnit(driverPath);
        if (result is! ResolvedUnitResult) {
          fullyResolved = false;
          continue;
        }
        unit = result;
      } on Object {
        // A path outside any context, or a session error on one file, must not
        // sink the whole pass — mark partial and keep going.
        fullyResolved = false;
        continue;
      }
      unit.unit.accept(
        _ResolvedUsageVisitor(
          idPath: idPath,
          lineInfo: unit.unit.lineInfo,
          declToId: declToId,
          refCounts: refCounts,
          entryPointIds: entryPointIds,
        ),
      );
    }

    final countsById = <String, int>{};
    declToId.forEach((element, id) {
      countsById[id] = refCounts[element] ?? 0;
    });
    return ResolvedUsage(
      countsById: countsById,
      entryPointIds: entryPointIds,
      fullyResolved: fullyResolved,
    );
  } on Object {
    // Collection construction or an unrecoverable analyzer error: degrade fully.
    return null;
  } finally {
    await collection.dispose();
  }
}

/// Canonical, generic-instantiation-free, non-synthetic form of [element], so a
/// reference and its declaration key to the SAME map entry. `baseElement`
/// unwraps a `Member` produced by generic instantiation; `nonSynthetic` maps a
/// synthetic accessor back to its variable. Both sides apply this identically.
Element? _canonical(Element? element) {
  if (element == null) return null;
  return element.baseElement.nonSynthetic;
}

/// Walks a resolved unit, recording each function/method declaration's id and
/// counting references to it. Mirrors `_FunctionCollector`'s node selection
/// (FunctionDeclaration + MethodDeclaration, including nested locals) so the
/// ids it emits line up with the parse phase's `_FunctionNode.id`.
class _ResolvedUsageVisitor extends RecursiveAstVisitor<void> {
  _ResolvedUsageVisitor({
    required this.idPath,
    required this.lineInfo,
    required this.declToId,
    required this.refCounts,
    required this.entryPointIds,
  });

  final String idPath;
  final LineInfo lineInfo;
  final Map<Element, String> declToId;
  final Map<Element, int> refCounts;
  final Set<String> entryPointIds;

  /// Elements of the declarations we are lexically inside. A reference whose
  /// canonical element is on this stack is a self/recursive reference from
  /// within the declaration's own body and is NOT counted (the source plan
  /// counts only references *outside* the declaration).
  final List<Element> _enclosing = <Element>[];

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _registerDeclaration(
      node: node,
      name: node.name.lexeme,
      element: _canonical(node.declaredFragment?.element),
      // Only a TOP-LEVEL `main` is an entry point; a nested local `main` is an
      // ordinary closure (parent is a FunctionDeclarationStatement, not a unit).
      isTopLevel: node.parent is CompilationUnit,
      body: () => super.visitFunctionDeclaration(node),
    );
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _registerDeclaration(
      node: node,
      name: node.name.lexeme,
      element: _canonical(node.declaredFragment?.element),
      isTopLevel: false,
      body: () => super.visitMethodDeclaration(node),
    );
  }

  void _registerDeclaration({
    required Declaration node,
    required String name,
    required Element? element,
    required bool isTopLevel,
    required void Function() body,
  }) {
    // Same id construction as `_FunctionCollector._addFunction`: the node offset
    // (which includes any doc comment / annotations) mapped to a 1-based line.
    final line = lineInfo.getLocation(node.offset).lineNumber;
    final id = '$idPath:$name:$line';
    if (element != null) {
      declToId[element] = id;
      _enclosing.add(element);
    }
    if (_isEntryPoint(
      node: node,
      name: name,
      element: element,
      isTopLevel: isTopLevel,
    )) {
      entryPointIds.add(id);
    }
    body();
    if (element != null) _enclosing.removeLast();
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    // Skip the declaration's own name token (it is not a reference to itself).
    if (!node.inDeclarationContext()) {
      final element = _canonical(node.element);
      // Count every resolved reference except a self/recursive one; only the
      // entries that are tracked declarations survive the final id mapping.
      if (element != null && !_enclosing.contains(element)) {
        refCounts.update(element, (c) => c + 1, ifAbsent: () => 1);
      }
    }
    super.visitSimpleIdentifier(node);
  }
}

/// True when [node] is runtime-invoked and so must never be flagged `unused`.
///
/// - Any `@override` member: framework lifecycle hooks (`build`, `initState`,
///   `dispose`, …) and polymorphic overrides are reached via the supertype, not
///   by a static reference to this declaration — using the resolved metadata,
///   never the method name, avoids the very false-attribution this collector
///   exists to fix.
/// - `@pragma('vm:entry-point')`: explicitly kept alive for native/AOT entry.
/// - A top-level `main`.
bool _isEntryPoint({
  required Declaration node,
  required String name,
  required Element? element,
  required bool isTopLevel,
}) {
  if (element != null && element.metadata.hasOverride) return true;
  if (_hasVmEntryPointPragma(node.metadata)) return true;
  return isTopLevel && name == 'main';
}

bool _hasVmEntryPointPragma(NodeList<Annotation> metadata) {
  for (final annotation in metadata) {
    if (annotation.name.name != 'pragma') continue;
    final args = annotation.arguments?.arguments;
    if (args == null || args.isEmpty) continue;
    final first = args.first;
    if (first is StringLiteral && first.stringValue == 'vm:entry-point') {
      return true;
    }
  }
  return false;
}
