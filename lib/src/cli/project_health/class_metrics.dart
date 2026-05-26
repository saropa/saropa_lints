/// Per-class cohesion/size metrics over PARSED AST.
///
/// LCOM* (lack of cohesion of methods) flags classes that bundle unrelated
/// responsibilities — methods that touch disjoint field sets — which are split
/// candidates. Field "use" is detected by name match (the standard heuristic;
/// no resolution, so it stays memory-light).
library;

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../analyzer_compat.dart';
import 'metrics_model.dart';

/// Returns one [ClassMetric] per class declaration in [content].
List<ClassMetric> scanClassMetrics(String content) => scanClassMetricsUnit(
  parseString(content: content, throwIfDiagnostics: false).unit,
);

/// Like [scanClassMetrics] but reuses an already-parsed [unit] (single parse).
List<ClassMetric> scanClassMetricsUnit(CompilationUnit unit) {
  final scanner = _ClassScanner();
  unit.visitChildren(scanner);
  return scanner.classes;
}

class _ClassScanner extends RecursiveAstVisitor<void> {
  final List<ClassMetric> classes = [];

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final fields = <String>{};
    final methods = <MethodDeclaration>[];
    var fieldCount = 0;
    var publicMembers = 0;

    for (final member in node.bodyMembers) {
      if (member is FieldDeclaration) {
        for (final v in member.fields.variables) {
          fields.add(v.name.lexeme);
          fieldCount++;
          if (!v.name.lexeme.startsWith('_')) publicMembers++;
        }
      } else if (member is MethodDeclaration) {
        methods.add(member);
        if (!member.name.lexeme.startsWith('_')) publicMembers++;
      }
    }

    classes.add(
      ClassMetric(
        name: node.nameToken.lexeme,
        fieldCount: fieldCount,
        methodCount: methods.length,
        publicMembers: publicMembers,
        lcom: _lcomStar(methods, fields),
      ),
    );
    // No super: Dart has no nested classes, and methods are already tallied.
  }
}

/// LCOM* (Henderson-Sellers): `(meanFieldUse - m) / (1 - m)`, clamped to 0..1.
/// 0 = perfectly cohesive (every method touches every field); near 1 = methods
/// touch disjoint fields. Undefined for <2 methods or 0 fields → 0 (harmless).
double _lcomStar(List<MethodDeclaration> methods, Set<String> fields) {
  final m = methods.length;
  final a = fields.length;
  if (m <= 1 || a == 0) return 0;

  final usageCount = <String, int>{for (final f in fields) f: 0};
  for (final method in methods) {
    for (final used in _fieldsUsedBy(method, fields)) {
      usageCount[used] = usageCount[used]! + 1;
    }
  }
  final totalUse = usageCount.values.fold<int>(0, (sum, c) => sum + c);
  final meanFieldUse = totalUse / a;
  final lcom = (meanFieldUse - m) / (1 - m);
  return lcom.clamp(0.0, 1.0);
}

Set<String> _fieldsUsedBy(MethodDeclaration method, Set<String> fields) {
  final collector = _FieldUseCollector(fields);
  method.body.accept(collector);
  return collector.found;
}

class _FieldUseCollector extends RecursiveAstVisitor<void> {
  _FieldUseCollector(this._fields);

  final Set<String> _fields;
  final Set<String> found = {};

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (_fields.contains(node.name)) found.add(node.name);
  }
}
