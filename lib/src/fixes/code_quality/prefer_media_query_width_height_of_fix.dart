// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Returns the `MediaQuery.sizeOf(x)`, `MediaQuery.maybeSizeOf(x)` or
/// `MediaQuery.of(x)` call that [access] reads a width or height from, or
/// null when [access] is not such a direct chain.
///
/// `of(x).size.width` is `PropertyAccess(PropertyAccess(of(x), size), width)`;
/// the returned call is the inner `of(x)` for that shape.
MethodInvocation? mediaQuerySizeCall(PropertyAccess access) {
  final Expression? target = access.target;
  if (target is MethodInvocation) {
    final String name = target.methodName.name;
    return name == 'sizeOf' || name == 'maybeSizeOf' ? target : null;
  }
  if (target is PropertyAccess && target.propertyName.name == 'size') {
    final Expression? inner = target.target;
    if (inner is MethodInvocation && inner.methodName.name == 'of') {
      return inner;
    }
  }
  return null;
}

/// Quick fix: Replace `MediaQuery.sizeOf(context).width` with
/// `MediaQuery.widthOf(context)` (and the height / maybe forms).
///
/// Matches [PreferMediaQueryWidthHeightOfRule].
class PreferMediaQueryWidthHeightOfFix extends SaropaFixProducer {
  PreferMediaQueryWidthHeightOfFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferMediaQueryWidthHeightOf',
    50,
    'Use MediaQuery.widthOf / heightOf',
  );

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

    final String property = access.propertyName.name;
    if (property != 'width' && property != 'height') return;

    final MethodInvocation? call = mediaQuerySizeCall(access);
    final Expression? receiver = call?.target;
    if (call == null || receiver == null) return;

    final bool isMaybe = call.methodName.name == 'maybeSizeOf';
    final String method = isMaybe
        ? 'maybe${property == 'width' ? 'Width' : 'Height'}Of'
        : '${property}Of';
    final String args = call.argumentList.arguments
        .map((e) => e.toSource())
        .join(', ');

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(
        SourceRange(access.offset, access.length),
        '${receiver.toSource()}.$method($args)',
      );
    });
  }
}
