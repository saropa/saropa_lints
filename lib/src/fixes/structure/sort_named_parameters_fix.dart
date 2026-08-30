// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Reorder named parameters so required come first (alphabetical),
/// then optional (alphabetical), matching dart format's
/// `always_put_required_named_parameters_first` convention.
class SortNamedParametersFix extends SaropaFixProducer {
  SortNamedParametersFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.sortNamedParameters',
    50,
    'Sort named parameters (required first, then optional)',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final AstNode? node = coveringNode;
    if (node == null) return;

    // The diagnostic is reported at the function/method name token.
    // Walk up to find the enclosing declaration's parameter list.
    final FormalParameterList? paramList = _findParameterList(node);
    if (paramList == null) return;

    // Build the reordered parameter list text.
    final String replacement = _buildSortedParamList(paramList);

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(paramList.offset, paramList.length),
        replacement,
      );
    });
  }

  /// Rebuilds the parameter list with required named params first
  /// (alphabetical), then optional named (alphabetical), preserving
  /// positional params, annotations, default values via toSource().
  static String _buildSortedParamList(FormalParameterList paramList) {
    final List<_ParamInfo> required = <_ParamInfo>[];
    final List<_ParamInfo> optional = <_ParamInfo>[];
    final List<String> positionalSources = <String>[];

    // Partition params into positional vs named (required/optional).
    for (final FormalParameter param in paramList.parameters) {
      if (!param.isNamed) {
        positionalSources.add(param.toSource());
        continue;
      }
      final String name = param.name?.lexeme ?? '';
      final info = _ParamInfo(name, param.toSource());
      if (param.isRequired) {
        required.add(info);
      } else {
        optional.add(info);
      }
    }

    // Sort each named group alphabetically by parameter name.
    required.sort((a, b) => a.name.compareTo(b.name));
    optional.sort((a, b) => a.name.compareTo(b.name));

    // Assemble: positional first, then {required sorted, optional sorted}.
    final namedSources = [
      ...required.map((p) => p.source),
      ...optional.map((p) => p.source),
    ];

    final buf = StringBuffer('(');
    if (positionalSources.isNotEmpty && namedSources.isNotEmpty) {
      buf.write(positionalSources.join(', '));
      buf.write(', {');
      buf.write(namedSources.join(', '));
      buf.write('}');
    } else if (namedSources.isNotEmpty) {
      buf.write('{');
      buf.write(namedSources.join(', '));
      buf.write('}');
    } else {
      buf.write(positionalSources.join(', '));
    }
    buf.write(')');
    return buf.toString();
  }

  /// Walks up from the diagnostic node to find the parameter list.
  static FormalParameterList? _findParameterList(AstNode node) {
    // Direct hit on the parameter list.
    if (node is FormalParameterList) return node;

    // The diagnostic is on the function/method name — check parent types.
    final AstNode? parent = node.parent;
    if (parent is FunctionDeclaration) {
      return parent.functionExpression.parameters;
    }
    if (parent is MethodDeclaration) {
      return parent.parameters;
    }

    // Fallback: search ancestors.
    return node.thisOrAncestorOfType<FormalParameterList>();
  }
}

/// Holds a parameter's name and full source text for sorting.
class _ParamInfo {
  _ParamInfo(this.name, this.source);

  /// The parameter's identifier name (for alphabetical comparison).
  final String name;

  /// The full source text of the parameter declaration
  /// (includes annotations, type, default value).
  final String source;
}
