// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../analyzer_compat.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: converts a `StatelessWidget` whose `build()` passes an inline
/// method call as `StreamBuilder`'s `stream:` argument into a
/// `StatefulWidget`, caching the stream in a `late final` field assigned in
/// `initState()`.
///
/// Matches Pattern 2 of [AvoidStreamInBuildRule] (`stream: method()`), not
/// Pattern 1 (`StreamController()` instantiation) — the applicability checks
/// below reject anything that isn't the direct value of a `StreamBuilder`'s
/// `stream:` argument.
///
/// Deliberately conservative: only offered when the widget class has zero
/// fields and no methods besides `build()`. A field would need every
/// reference inside `build()` rewritten to `widget.field`, and any other
/// method might reference such a field too — attempting that without a full
/// rewrite engine risks emitting code that references undefined
/// identifiers. Bailing (no fix offered) is safer than a partial rewrite.
class ConvertStatelessToStatefulForStreamFix extends SaropaFixProducer {
  ConvertStatelessToStatefulForStreamFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.convertStatelessToStatefulForStream',
    50,
    'Convert to StatefulWidget and cache stream in initState()',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // The rule reports directly on the stream-creating expression for
    // Pattern 2. Anything else (e.g. Pattern 1's StreamController() node)
    // isn't the shape this fix handles.
    if (node is! MethodInvocation && node is! FunctionExpressionInvocation) {
      return;
    }
    final streamExpr = node as Expression;

    // Must be the direct value of a `stream:` argument — reject the
    // assignment-wrapped forms (`stream: x = method()`), which would also
    // require relocating a local variable declaration.
    final namedArg = streamExpr.parent;
    if (namedArg is! NamedExpression || namedArg.name.label.name != 'stream') {
      return;
    }

    // Must be StreamBuilder's constructor call.
    final argList = namedArg.parent;
    if (argList is! ArgumentList) return;
    final creation = argList.parent;
    if (creation is! InstanceCreationExpression) return;
    if (creation.constructorName.type.name.lexeme != 'StreamBuilder') return;

    final buildMethod = streamExpr.thisOrAncestorOfType<MethodDeclaration>();
    if (buildMethod == null || buildMethod.name.lexeme != 'build') return;
    if (buildMethod.body is! BlockFunctionBody) return;

    final classDecl = buildMethod.thisOrAncestorOfType<ClassDeclaration>();
    if (classDecl == null) return;

    // Only handle exact `extends StatelessWidget` — third-party bases
    // (HookWidget, ConsumerWidget) have their own createState()/mixin
    // requirements this fix doesn't model.
    final extendsClause = classDecl.extendsClause;
    if (extendsClause == null) return;
    if (extendsClause.superclass.name.lexeme != 'StatelessWidget') return;

    // Bail on any class shape beyond the simplest case — see class doc.
    for (final member in classDecl.bodyMembers) {
      if (member is FieldDeclaration) return;
      if (member is MethodDeclaration && member.name.lexeme != 'build') {
        return;
      }
    }

    final streamType = streamExpr.staticType;
    if (streamType == null) return;
    final typeStr = streamType.getDisplayString();

    final content = unitResult.content;
    final buildSource = content.substring(buildMethod.offset, buildMethod.end);
    final streamExprSource = content.substring(
      streamExpr.offset,
      streamExpr.end,
    );

    final fieldName = _pickFieldName(buildSource);
    if (fieldName == null) return;

    // Splice the field reference into the copied build() source, using
    // offsets relative to the method's own start.
    final relOffset = streamExpr.offset - buildMethod.offset;
    final newBuildSource = buildSource.replaceRange(
      relOffset,
      relOffset + streamExprSource.length,
      fieldName,
    );

    final className = classDecl.nameToken.lexeme;
    final stateName = '_${className}State';
    final classIndent = getLineIndent(classDecl);
    final memberIndent = '$classIndent  ';

    final stateClass =
        '\n\n${classIndent}class $stateName extends State<$className> {\n'
        '$memberIndent'
        'late final $typeStr $fieldName;\n'
        '\n'
        '$memberIndent@override\n'
        '${memberIndent}void initState() {\n'
        '$memberIndent  super.initState();\n'
        '$memberIndent  $fieldName = $streamExprSource;\n'
        '$memberIndent}\n'
        '\n'
        '$memberIndent$newBuildSource\n'
        '$classIndent}\n';

    final createStateOverride =
        '@override\n'
        '${getLineIndent(buildMethod)}State<$className> createState() => '
        '$stateName();';

    await builder.addDartFileEdit(file, (b) {
      // extends StatelessWidget -> extends StatefulWidget
      b.addSimpleReplacement(
        SourceRange(
          extendsClause.superclass.offset,
          extendsClause.superclass.length,
        ),
        'StatefulWidget',
      );
      // build() -> createState() override
      b.addSimpleReplacement(
        SourceRange(buildMethod.offset, buildMethod.length),
        createStateOverride,
      );
      // Append the new State class after the widget class.
      b.addSimpleInsertion(classDecl.end, stateClass);
    });
  }

  /// Picks an unused field name for the cached stream, trying `_stream`
  /// then two fallbacks. Returns null if all three already appear in the
  /// build() method's source (as a defensive collision guard — extremely
  /// unlikely given the zero-field applicability gate, but a name clash
  /// would produce invalid code).
  String? _pickFieldName(String buildSource) {
    for (final candidate in const [
      '_stream',
      '_streamValue',
      '_cachedStream',
    ]) {
      if (!RegExp('\\b$candidate\\b').hasMatch(buildSource)) return candidate;
    }
    return null;
  }
}
