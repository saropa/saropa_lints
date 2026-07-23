// ignore_for_file: depend_on_referenced_packages

/// Per-node diagnostic tracer for the `--debug-rule` scan flag.
///
/// Wraps a rule's [AstVisitor] and logs type resolution details for each
/// visited node. Designed for diagnosing false positives caused by
/// type-resolution divergence (e.g. staticType vs staticInvokeType for
/// cross-file method invocations in the analyzer plugin context).
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';

/// Callback that receives trace messages for output.
typedef TraceSink = void Function(String message);

/// Wraps a rule's [AstVisitor] to emit type-resolution trace output before
/// each node visit. The trace is written to [sink] and the original visitor's
/// behavior is unchanged.
class TracingVisitorWrapper extends GeneralizingAstVisitor<void> {
  TracingVisitorWrapper(this._delegate, this._sink, this._ruleName);

  final AstVisitor<void> _delegate;
  final TraceSink _sink;
  final String _ruleName;

  @override
  void visitNode(AstNode node) {
    _traceNode(node);
    node.accept(_delegate);
  }

  void _traceNode(AstNode node) {
    if (node is AwaitExpression) {
      _traceAwaitExpression(node);
    } else if (node is MethodInvocation) {
      _traceMethodInvocation(node);
    }
  }

  void _traceAwaitExpression(AwaitExpression node) {
    final expr = node.expression;
    final staticType = expr.staticType;
    final buf = StringBuffer()
      ..writeln(
        '  TRACE [$_ruleName] AwaitExpression '
        'offset=${node.offset} '
        'exprType=${expr.runtimeType}',
      )
      ..writeln('    staticType: ${_describeType(staticType)}');

    if (expr is MethodInvocation) {
      _appendInvocationTrace(buf, expr.staticInvokeType, expr.methodName.name);
    } else if (expr is FunctionExpressionInvocation) {
      _appendInvocationTrace(buf, expr.staticInvokeType, '(function)');
    }

    _sink(buf.toString().trimRight());
  }

  void _traceMethodInvocation(MethodInvocation node) {
    final staticType = node.staticType;
    final invokeType = node.staticInvokeType;
    final targetType = node.realTarget?.staticType;

    _sink(
      '  TRACE [$_ruleName] MethodInvocation '
      '${node.methodName.name} '
      'offset=${node.offset}\n'
      '    staticType: ${_describeType(staticType)}\n'
      '    staticInvokeType: ${_describeType(invokeType)}\n'
      '    target.staticType: ${_describeType(targetType)}',
    );
  }

  void _appendInvocationTrace(
    StringBuffer buf,
    DartType? invokeType,
    String methodName,
  ) {
    buf.writeln('    method: $methodName');
    buf.writeln('    staticInvokeType: ${_describeType(invokeType)}');
    if (invokeType is FunctionType) {
      buf.writeln('    returnType: ${_describeType(invokeType.returnType)}');
    }
  }

  static String _describeType(DartType? type) {
    if (type == null) return 'null';
    final display = type.getDisplayString();
    final runtimeType = type.runtimeType;

    final flags = <String>[];
    if (type is InvalidType) flags.add('INVALID');
    if (type is DynamicType) flags.add('dynamic');
    if (type.isDartAsyncFuture) flags.add('isFuture');
    if (type.isDartAsyncFutureOr) flags.add('isFutureOr');
    if (type.isDartAsyncStream) flags.add('isStream');
    if (type is InterfaceType) flags.add('InterfaceType');
    if (type is FunctionType) flags.add('FunctionType');
    if (type is TypeParameterType) flags.add('TypeParam');

    final flagStr = flags.isEmpty ? '' : ' [${flags.join(', ')}]';
    return '$display ($runtimeType)$flagStr';
  }
}
