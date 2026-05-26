/// Finds "dead islands": private top-level declarations unreachable from any
/// live root within a file. This is the case Dart's `unused_element` MISSES —
/// private `_a` and `_b` that reference each other but nothing live reaches,
/// so each looks "used" by the other.
///
/// Scope: top-level functions and classes in a single library (part files not
/// followed). References are name-based (parsed AST, no resolution), so a local
/// shadowing a top-level name can mask a dead island — report-only, verify
/// before removing.
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as p;

import '../../analyzer_compat.dart';

/// Annotations that mark a declaration as a live root even when private
/// (reflection / test-only entry points the static graph cannot see).
const Set<String> _rootAnnotations = {'pragma', 'visibleForTesting'};

/// Scans every `.dart` file under `lib/` and returns path → dead-island names
/// (only files with findings). One file in memory at a time.
Map<String, List<String>> scanProjectDeadIslands(String projectPath) {
  final lib = Directory(p.join(projectPath, 'lib'));
  if (!lib.existsSync()) return const {};
  final result = <String, List<String>>{};
  for (final entity in lib.listSync(recursive: true, followLinks: false)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final names = scanDeadIslands(entity.readAsStringSync());
    if (names.isNotEmpty) {
      final rel = p
          .relative(entity.path, from: projectPath)
          .replaceAll('\\', '/');
      result[rel] = names;
    }
  }
  return result;
}

/// Returns the names of private top-level declarations unreachable from any
/// live root in [content].
List<String> scanDeadIslands(String content) {
  final unit = parseString(content: content, throwIfDiagnostics: false).unit;
  final decls = <String, _Decl>{};
  // Declarations not modeled as nodes (top-level vars, enums, mixins,
  // extensions, typedefs). Anything THEY reference is live — e.g. a public
  // `final rules = _build();` keeps `_build` alive. Seeding these references as
  // roots avoids the classic dead-code false positive.
  final otherDecls = <CompilationUnitMember>[];
  for (final member in unit.declarations) {
    if (member is FunctionDeclaration) {
      _add(decls, member.name.lexeme, member);
    } else if (member is ClassDeclaration) {
      _add(decls, member.nameToken.lexeme, member);
    } else {
      otherDecls.add(member);
    }
  }
  if (decls.isEmpty) return const [];

  final names = decls.keys.toSet();
  for (final decl in decls.values) {
    decl.refs = _identifiersIn(decl.node, names)..remove(decl.name);
  }

  final reachable = <String>{};
  final queue = [
    for (final d in decls.values)
      if (d.isRoot) d.name,
  ];
  for (final other in otherDecls) {
    queue.addAll(_identifiersIn(other, names));
  }
  while (queue.isNotEmpty) {
    final name = queue.removeLast();
    if (!reachable.add(name)) continue;
    queue.addAll(decls[name]?.refs ?? const {});
  }

  return [
    for (final d in decls.values)
      if (d.isPrivate && !reachable.contains(d.name)) d.name,
  ]..sort();
}

void _add(Map<String, _Decl> decls, String name, AnnotatedNode member) {
  final private = name.startsWith('_');
  final isRoot = !private || name == 'main' || _hasRootAnnotation(member);
  decls[name] = _Decl(name, member, private, isRoot);
}

bool _hasRootAnnotation(AnnotatedNode node) =>
    node.metadata.any((a) => _rootAnnotations.contains(a.name.name));

Set<String> _identifiersIn(AstNode node, Set<String> universe) {
  final collector = _RefCollector(universe);
  node.accept(collector);
  return collector.found;
}

class _Decl {
  _Decl(this.name, this.node, this.isPrivate, this.isRoot);
  final String name;
  final AstNode node;
  final bool isPrivate;
  final bool isRoot;
  Set<String> refs = {};
}

class _RefCollector extends RecursiveAstVisitor<void> {
  _RefCollector(this._universe);
  final Set<String> _universe;
  final Set<String> found = {};

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (_universe.contains(node.name)) found.add(node.name);
  }
}
