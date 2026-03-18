// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace MediaQuery.of(context).property with MediaQuery.propertyOf(context).
///
/// Matches [PreferDedicatedMediaQueryMethodRule].
class PreferDedicatedMediaQueryMethodFix extends SaropaFixProducer {
  PreferDedicatedMediaQueryMethodFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferDedicatedMediaQueryMethod',
    50,
    'Use dedicated MediaQuery method',
  );

  static const Map<String, String> _propertyToMethod = <String, String>{
    'size': 'sizeOf',
    'padding': 'paddingOf',
    'viewInsets': 'viewInsetsOf',
    'viewPadding': 'viewPaddingOf',
    'orientation': 'orientationOf',
    'devicePixelRatio': 'devicePixelRatioOf',
    'textScaleFactor': 'textScaleFactorOf',
    'platformBrightness': 'platformBrightnessOf',
  };

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final PropertyAccess? access = node is PropertyAccess
        ? node
        : node.thisOrAncestorOfType<PropertyAccess>();
    if (access == null) return;

    final String propertyName = access.propertyName.name;
    final String? methodName = _propertyToMethod[propertyName];
    if (methodName == null) return;

    final Expression? target = access.target;
    if (target is! MethodInvocation || target.methodName.name != 'of') return;

    final Expression? receiver = target.target;
    if (receiver == null) return;

    final String contextArg = target.argumentList.arguments
        .map((e) => e.toSource())
        .join(', ');
    final String replacement =
        '${receiver.toSource()}.$methodName($contextArg)';

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(
        SourceRange(access.offset, access.length),
        replacement,
      );
    });
  }
}
