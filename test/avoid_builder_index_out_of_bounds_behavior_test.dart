import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:test/test.dart';

/// Behavioral checks for [AvoidBuilderIndexOutOfBoundsRule] heuristics.
///
/// Regex and extraction logic must stay aligned with
/// `lib/src/rules/widget/widget_layout_constraints_rules.dart`.
void main() {
  group('AvoidBuilderIndexOutOfBoundsRule heuristics', () {
    test('itemCount + guard + groups[index] does not report', () {
      expect(
        _wouldReport(r'''
Object w(List<String> groups, Object emptyWidget) {
  return ListView.builder(
    shrinkWrap: true,
    itemCount: groups.length,
    itemBuilder: (Object context, int index) {
      if (index < 0 || index >= groups.length) {
        return emptyWidget;
      }
      try {
        final String group = groups[index];
        return group;
      } on Object catch (e) {
        return emptyWidget;
      }
    },
  );
}
'''),
        isFalse,
      );
    });

    test('parallel second list without guard reports', () {
      expect(
        _wouldReport(r'''
Object w(List<String> groups, List<int> ids, Object emptyWidget) {
  return ListView.builder(
    shrinkWrap: true,
    itemCount: groups.length,
    itemBuilder: (Object context, int index) {
      if (index < 0 || index >= groups.length) {
        return emptyWidget;
      }
      final String group = groups[index];
      final int id = ids[index];
      return group;
    },
  );
}
'''),
        isTrue,
      );
    });

    test('Carousel-style realIndex subscript respects length guard', () {
      expect(
        _wouldReport(r'''
Object w(List<String> items, Object empty) {
  return CarouselSlider.builder(
    itemCount: items.length,
    itemBuilder: (Object context, int index, int realIndex) {
      if (realIndex >= items.length) return empty;
      return items[realIndex];
    },
  );
}
'''),
        isFalse,
      );
    });
  });
}

bool _wouldReport(String unitSource) {
  final result = parseString(
    content: unitSource,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );
  NamedExpression? itemBuilder;
  result.unit.accept(
    _PickNamedExpression((n) {
      if (n.name.label.name == 'itemBuilder') itemBuilder = n;
    }),
  );
  expect(itemBuilder, isNotNull, reason: 'fixture must contain itemBuilder');
  final expr = itemBuilder!.expression;
  if (expr is! FunctionExpression) {
    fail('itemBuilder must be a FunctionExpression');
  }
  final bodySource = expr.body.toSource();
  return _simulateWouldReport(bodySource, itemBuilder!);
}

bool _simulateWouldReport(String bodySource, NamedExpression itemBuilderNode) {
  const indexAccessPattern =
      r'(\b[a-zA-Z_][\w.]*)\s*\[\s*(?:index|i|idx|realIndex|itemIndex)\s*\]';
  const comparisonOpPattern = r'>=|>|<|<=';
  const itemCountLengthPattern = r'(\b[a-zA-Z_][\w.]*?)\.length\b';

  final matches = RegExp(indexAccessPattern).allMatches(bodySource);
  final accessedLists = matches
      .map((m) => m.group(1))
      .whereType<String>()
      .map(_extractListName)
      .toSet();
  if (accessedLists.isEmpty) return false;

  final itemCountBound = _itemCountBoundLists(
    itemBuilderNode,
    RegExp(itemCountLengthPattern),
  );

  final listNameAlternation = accessedLists.map(RegExp.escape).join('|');
  final combinedLengthPattern = RegExp(
    r'\b(' + listNameAlternation + r')\.length\b',
  );
  final combinedEmptyPattern = RegExp(
    r'\b(' + listNameAlternation + r')\.(?:isEmpty|isNotEmpty)\b',
  );
  final hasComparisonOp = RegExp(comparisonOpPattern).hasMatch(bodySource);
  final listsWithLengthCheck = combinedLengthPattern
      .allMatches(bodySource)
      .map((m) => m.group(1))
      .whereType<String>()
      .toSet();
  final listsWithEmptyCheck = combinedEmptyPattern
      .allMatches(bodySource)
      .map((m) => m.group(1))
      .whereType<String>()
      .toSet();

  for (final listName in accessedLists) {
    if (itemCountBound.contains(listName)) continue;
    final hasLength =
        hasComparisonOp && listsWithLengthCheck.contains(listName);
    final hasEmpty = listsWithEmptyCheck.contains(listName);
    if (!hasLength && !hasEmpty) return true;
  }
  return false;
}

String _extractListName(String fullName) {
  final lastDot = fullName.lastIndexOf('.');
  return lastDot >= 0 ? fullName.substring(lastDot + 1) : fullName;
}

Set<String> _itemCountBoundLists(
  NamedExpression itemBuilderNode,
  RegExp itemCountLengthPattern,
) {
  final argumentList = itemBuilderNode.parent;
  if (argumentList is! ArgumentList) return {};

  for (final arg in argumentList.arguments) {
    if (arg is NamedExpression && arg.name.label.name == 'itemCount') {
      final countSource = arg.expression.toSource();
      final match = itemCountLengthPattern.firstMatch(countSource);
      final g1 = match?.group(1);
      if (g1 != null) {
        return {_extractListName(g1)};
      }
      break;
    }
  }
  return {};
}

class _PickNamedExpression extends RecursiveAstVisitor<void> {
  _PickNamedExpression(this.onNamed);

  final void Function(NamedExpression n) onNamed;

  @override
  void visitNamedExpression(NamedExpression node) {
    onNamed(node);
    super.visitNamedExpression(node);
  }
}
