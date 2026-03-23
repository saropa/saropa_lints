// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';
import '../../rules/widget/image_filter_quality_detection.dart';

/// Replaces the `filterQuality` argument value `FilterQuality.low` with
/// `FilterQuality.medium`, preserving a library prefix when present
/// (e.g. `ui.FilterQuality.low` → `ui.FilterQuality.medium`).
///
/// Triggered when the diagnostic is anchored on the `filterQuality:` label;
/// `coveringNode` is resolved to the enclosing [NamedExpression] and only the
/// value expression is rewritten.
class PreferImageFilterQualityMediumFix extends SaropaFixProducer {
  PreferImageFilterQualityMediumFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferImageFilterQualityMedium',
    70,
    'Use FilterQuality.medium',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final AstNode? node = coveringNode;
    if (node == null) return;

    final NamedExpression? named = node.thisOrAncestorOfType<NamedExpression>();
    if (named == null || named.name.label.name != 'filterQuality') return;

    final Expression value = named.expression;
    if (!ImageFilterQualityLowDetection.isFilterQualityLowValue(value)) {
      return;
    }

    final String replacement = ImageFilterQualityLowDetection.replacementSource(
      value,
    );

    await builder.addDartFileEdit(file, (editBuilder) {
      editBuilder.addSimpleReplacement(
        SourceRange(value.offset, value.length),
        replacement,
      );
    });
  }
}
