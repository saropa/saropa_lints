import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:saropa_lints/src/rules/widget/image_filter_quality_detection.dart';
import 'package:saropa_lints/src/rules/widget/image_filter_quality_migration_rules.dart';
import 'package:saropa_lints/saropa_lints.dart' show LintImpact;
import 'package:test/test.dart';

CompilationUnit _parse(String code) => parseString(content: code).unit;

NamedExpression? _filterQualityViolationFromStatement(Expression expr) {
  if (expr is InstanceCreationExpression) {
    return ImageFilterQualityLowDetection.violatingFilterQualityNamedArg(expr);
  }
  if (expr is MethodInvocation) {
    return ImageFilterQualityLowDetection.violatingFilterQualityNamedArgInvocation(
      expr,
    );
  }
  return null;
}

void main() {
  group('ImageFilterQualityLowDetection', () {
    test(
      'isFilterQualityLowValue matches FilterQuality.low without resolution',
      () {
        final CompilationUnit unit = _parse(
          'void f() { m(filterQuality: FilterQuality.low); }',
        );
        final FunctionDeclaration fun =
            unit.declarations.first as FunctionDeclaration;
        final BlockFunctionBody body =
            fun.functionExpression.body as BlockFunctionBody;
        final ExpressionStatement stmt =
            body.block.statements.first as ExpressionStatement;
        final MethodInvocation inv = stmt.expression as MethodInvocation;
        final NamedExpression arg =
            inv.argumentList.arguments.first as NamedExpression;
        expect(
          ImageFilterQualityLowDetection.isFilterQualityLowValue(
            arg.expression,
          ),
          isTrue,
        );
        expect(
          ImageFilterQualityLowDetection.replacementSource(arg.expression),
          'FilterQuality.medium',
        );
      },
    );

    test('finds Image.network with FilterQuality.low', () {
      final CompilationUnit unit = _parse(
        'void f() { Image.network("", filterQuality: FilterQuality.low); }',
      );
      final FunctionDeclaration fun =
          unit.declarations.first as FunctionDeclaration;
      final BlockFunctionBody body =
          fun.functionExpression.body as BlockFunctionBody;
      final ExpressionStatement stmt =
          body.block.statements.first as ExpressionStatement;
      final NamedExpression? named = _filterQualityViolationFromStatement(
        stmt.expression,
      );
      expect(named, isNotNull);
      expect(named!.name.label.name, 'filterQuality');
    });

    test('skips Image.network with FilterQuality.medium', () {
      final CompilationUnit unit = _parse(
        'void f() { Image.network("", filterQuality: FilterQuality.medium); }',
      );
      final FunctionDeclaration fun =
          unit.declarations.first as FunctionDeclaration;
      final BlockFunctionBody body =
          fun.functionExpression.body as BlockFunctionBody;
      final ExpressionStatement stmt =
          body.block.statements.first as ExpressionStatement;
      expect(_filterQualityViolationFromStatement(stmt.expression), isNull);
    });

    test('skips unknown Image factory', () {
      final CompilationUnit unit = _parse(
        'void f() { Image.foo("", filterQuality: FilterQuality.low); }',
      );
      final FunctionDeclaration fun =
          unit.declarations.first as FunctionDeclaration;
      final BlockFunctionBody body =
          fun.functionExpression.body as BlockFunctionBody;
      final ExpressionStatement stmt =
          body.block.statements.first as ExpressionStatement;
      expect(_filterQualityViolationFromStatement(stmt.expression), isNull);
    });

    test('isFilterQualityLowValue is false for FilterQuality.medium', () {
      final CompilationUnit unit = _parse(
        'void f() { m(filterQuality: FilterQuality.medium); }',
      );
      final FunctionDeclaration fun =
          unit.declarations.first as FunctionDeclaration;
      final BlockFunctionBody body =
          fun.functionExpression.body as BlockFunctionBody;
      final ExpressionStatement stmt =
          body.block.statements.first as ExpressionStatement;
      final MethodInvocation inv = stmt.expression as MethodInvocation;
      final NamedExpression arg =
          inv.argumentList.arguments.first as NamedExpression;
      expect(
        ImageFilterQualityLowDetection.isFilterQualityLowValue(arg.expression),
        isFalse,
      );
    });

    test('isFilterQualityLowValue is false for FilterQuality.none', () {
      final CompilationUnit unit = _parse(
        'void f() { m(filterQuality: FilterQuality.none); }',
      );
      final FunctionDeclaration fun =
          unit.declarations.first as FunctionDeclaration;
      final BlockFunctionBody body =
          fun.functionExpression.body as BlockFunctionBody;
      final ExpressionStatement stmt =
          body.block.statements.first as ExpressionStatement;
      final MethodInvocation inv = stmt.expression as MethodInvocation;
      final NamedExpression arg =
          inv.argumentList.arguments.first as NamedExpression;
      expect(
        ImageFilterQualityLowDetection.isFilterQualityLowValue(arg.expression),
        isFalse,
      );
    });

    test('finds RawImage and DecorationImage with FilterQuality.low', () {
      for (final String snippet in <String>[
        'void f() { RawImage(filterQuality: FilterQuality.low); }',
        'void f() { DecorationImage(image: x, filterQuality: FilterQuality.low); }',
      ]) {
        final CompilationUnit unit = _parse(snippet);
        final FunctionDeclaration fun =
            unit.declarations.first as FunctionDeclaration;
        final BlockFunctionBody body =
            fun.functionExpression.body as BlockFunctionBody;
        final ExpressionStatement stmt =
            body.block.statements.first as ExpressionStatement;
        expect(
          _filterQualityViolationFromStatement(stmt.expression),
          isNotNull,
        );
      }
    });

    test('skips Texture with FilterQuality.low (out of scope)', () {
      final CompilationUnit unit = _parse(
        'void f() { Texture(textureId: 1, filterQuality: FilterQuality.low); }',
      );
      final FunctionDeclaration fun =
          unit.declarations.first as FunctionDeclaration;
      final BlockFunctionBody body =
          fun.functionExpression.body as BlockFunctionBody;
      final ExpressionStatement stmt =
          body.block.statements.first as ExpressionStatement;
      expect(_filterQualityViolationFromStatement(stmt.expression), isNull);
    });

    test('replacementSource preserves ui prefix on FilterQuality', () {
      final CompilationUnit unit = _parse(
        'void f() { m(filterQuality: ui.FilterQuality.low); }',
      );
      final FunctionDeclaration fun =
          unit.declarations.first as FunctionDeclaration;
      final BlockFunctionBody body =
          fun.functionExpression.body as BlockFunctionBody;
      final ExpressionStatement stmt =
          body.block.statements.first as ExpressionStatement;
      final MethodInvocation inv = stmt.expression as MethodInvocation;
      final NamedExpression arg =
          inv.argumentList.arguments.first as NamedExpression;
      expect(
        ImageFilterQualityLowDetection.replacementSource(arg.expression),
        'ui.FilterQuality.medium',
      );
    });
  });

  group('PreferImageFilterQualityMediumRule', () {
    test('instantiates with expected metadata', () {
      final PreferImageFilterQualityMediumRule rule =
          PreferImageFilterQualityMediumRule();
      expect(rule.code.lowerCaseName, 'prefer_image_filter_quality_medium');
      expect(
        rule.code.problemMessage,
        contains('[prefer_image_filter_quality_medium]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(80));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.fixGenerators, isNotEmpty);
      expect(rule.impact, LintImpact.low);
    });
  });
}
