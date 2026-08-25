// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

/// Shared AST checks for [PreferSuperKeyRule] and [PreferSuperKeyFix].
///
/// Single source of truth so the quick fix cannot drift from lint conditions.
/// Unit tests target this library directly (no plugin context required).
abstract final class PreferSuperKeyDetection {
  PreferSuperKeyDetection._();

  /// Whether [node] extends `StatelessWidget`, `StatefulWidget`, or a type
  /// whose name ends with `Widget` (e.g. `ConsumerWidget`).
  static bool isFlutterWidgetClass(ClassDeclaration node) {
    final ExtendsClause? extendsClause = node.extendsClause;
    if (extendsClause == null) return false;
    final String name = extendsClause.superclass.name.lexeme;
    return name == 'StatelessWidget' ||
        name == 'StatefulWidget' ||
        name.endsWith('Widget');
  }

  /// Optional named `Key? key` / `Key key` parameter (not `super.key`).
  static FormalParameter? findKeyTypedKeyParameter(
    ConstructorDeclaration ctor,
  ) {
    for (final FormalParameter p in ctor.parameters.parameters) {
      if (p is SuperFormalParameter) continue;
      final FormalParameter inner = p is DefaultFormalParameter
          ? p.parameter
          : p;
      if (inner is! SimpleFormalParameter) continue;
      if (inner.name?.lexeme != 'key') continue;
      final TypeAnnotation? ta = inner.type;
      if (ta is! NamedType || ta.name.lexeme != 'Key') continue;
      return p;
    }
    return null;
  }

  static bool hasSuperKeyParameter(ConstructorDeclaration ctor) {
    for (final FormalParameter p in ctor.parameters.parameters) {
      if (p is SuperFormalParameter && p.name.lexeme == 'key') {
        return true;
      }
    }
    return false;
  }

  /// `super(key: key)` as the only super-constructor initializer argument.
  static SuperConstructorInvocation? soleSuperKeyForwarding(
    ConstructorDeclaration ctor,
  ) {
    for (final ConstructorInitializer init in ctor.initializers) {
      if (init is! SuperConstructorInvocation) continue;
      final NodeList<Expression> args = init.argumentList.arguments;
      if (args.length != 1) continue;
      final Expression a = args.single;
      if (a is! NamedExpression) continue;
      if (a.name.label.name != 'key') continue;
      if (a.expression is! SimpleIdentifier) continue;
      if ((a.expression as SimpleIdentifier).name != 'key') continue;
      return init;
    }
    return null;
  }

  /// Full condition used by the lint (parent must be the enclosing class).
  static bool shouldReportPreferSuperKey({
    required ConstructorDeclaration ctor,
    required ClassDeclaration parent,
  }) {
    if (ctor.factoryKeyword != null) return false;
    if (!isFlutterWidgetClass(parent)) return false;
    if (hasSuperKeyParameter(ctor)) return false;
    if (findKeyTypedKeyParameter(ctor) == null) return false;
    return soleSuperKeyForwarding(ctor) != null;
  }
}

/// Shared detection for [AvoidChipDeleteInkWellCircleBorderRule].
abstract final class ChipDeleteInkWellCircleBorderDetection {
  ChipDeleteInkWellCircleBorderDetection._();

  static const Set<String> chipTypes = <String>{
    'Chip',
    'RawChip',
    'InputChip',
    'ChoiceChip',
    'FilterChip',
    'ActionChip',
  };

  /// Chip widget call from an [InstanceCreationExpression] (`const InputChip(`).
  static NamedExpression? violationForChipConstructor(
    InstanceCreationExpression node,
  ) {
    return violationForChipNamedCall(
      typeName: node.constructorName.type.name.lexeme,
      argumentList: node.argumentList,
    );
  }

  /// Chip call from an unqualified [MethodInvocation] (`InputChip(` without a
  /// receiver). The parser often represents these as method calls until
  /// resolution; both shapes appear in analyzed sources, so the lint handles
  /// both.
  static NamedExpression? violationForChipMethodInvocation(
    MethodInvocation node,
  ) {
    if (node.target != null) return null;
    return violationForChipNamedCall(
      typeName: node.methodName.name,
      argumentList: node.argumentList,
    );
  }

  /// Shared: [typeName] must be a Material chip class; inspect `deleteIcon:`.
  static NamedExpression? violationForChipNamedCall({
    required String typeName,
    required ArgumentList argumentList,
  }) {
    if (!chipTypes.contains(typeName)) return null;

    NamedExpression? deleteIconArg;
    for (final Expression arg in argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'deleteIcon') {
        deleteIconArg = arg;
        break;
      }
    }
    if (deleteIconArg == null) return null;
    return findInkWellCircleBorderCustomBorder(deleteIconArg.expression);
  }

  /// Depth-first search for `InkWell(..., customBorder: CircleBorder(...), ...)`.
  ///
  /// Handles both [InstanceCreationExpression] and unqualified
  /// [MethodInvocation] for `InkWell`, matching typical parser output.
  static NamedExpression? findInkWellCircleBorderCustomBorder(Expression root) {
    NamedExpression? found;

    bool isCircleBorderShape(Expression ex) {
      if (ex is InstanceCreationExpression &&
          ex.constructorName.type.name.lexeme == 'CircleBorder') {
        return true;
      }
      if (ex is MethodInvocation &&
          ex.target == null &&
          ex.methodName.name == 'CircleBorder') {
        return true;
      }
      return false;
    }

    NamedExpression? inkWellCustomBorderCircle(InstanceCreationExpression e) {
      if (e.constructorName.type.name.lexeme != 'InkWell') return null;
      for (final Expression arg in e.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'customBorder') {
          if (isCircleBorderShape(arg.expression)) return arg;
        }
      }
      return null;
    }

    NamedExpression? inkWellMiCustomBorderCircle(MethodInvocation e) {
      if (e.target != null || e.methodName.name != 'InkWell') return null;
      for (final Expression arg in e.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'customBorder') {
          if (isCircleBorderShape(arg.expression)) return arg;
        }
      }
      return null;
    }

    void visit(Expression? e) {
      if (e == null || found != null) return;
      if (e is InstanceCreationExpression) {
        found = inkWellCustomBorderCircle(e);
        if (found != null) return;
        for (final Expression arg in e.argumentList.arguments) {
          if (arg is NamedExpression) {
            visit(arg.expression);
          } else {
            visit(arg);
          }
        }
      } else if (e is MethodInvocation) {
        found = inkWellMiCustomBorderCircle(e);
        if (found != null) return;
        for (final Expression arg in e.argumentList.arguments) {
          if (arg is NamedExpression) {
            visit(arg.expression);
          } else {
            visit(arg);
          }
        }
      }
    }

    visit(root);
    return found;
  }
}
