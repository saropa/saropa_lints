// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Wraps a [ListView] or [GridView] in `SliverToBoxAdapter(child: ...)` inside
/// sliver composition.
class WrapListViewInSliverToBoxAdapterFix extends SaropaFixProducer {
  WrapListViewInSliverToBoxAdapterFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.wrapListViewInSliverToBoxAdapterFix',
    50,
    'Wrap in SliverToBoxAdapter',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    final ConstructorName? ctorName = node is ConstructorName
        ? node
        : node?.thisOrAncestorOfType<ConstructorName>();
    if (ctorName == null) return;

    final parent = ctorName.parent;
    if (parent is! InstanceCreationExpression) return;
    final ice = parent;
    final type = ice.constructorName.type.name.lexeme;
    if (type != 'ListView' && type != 'GridView') return;

    final wrapped = 'SliverToBoxAdapter(child: ${ice.toSource()})';

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(ice.offset, ice.length),
        wrapped,
      );
    });
  }
}
