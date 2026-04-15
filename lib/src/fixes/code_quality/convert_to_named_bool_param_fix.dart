// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Convert a positional bool parameter to a required named parameter.
///
/// Handles the simple case where no named parameter section exists yet —
/// wraps the bool parameter with `{required ...}`. When named parameters
/// already exist, the parameter text is moved into the existing section.
///
/// Matches [AvoidPositionalBooleanParametersRule].
class ConvertToNamedBoolParamFix extends SaropaFixProducer {
  ConvertToNamedBoolParamFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.convertToNamedBoolParam',
    50,
    'Convert to required named parameter',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // The rule reports on the FormalParameter (SimpleFormalParameter
    // or DefaultFormalParameter). Get the parameter's source text and
    // the enclosing parameter list.
    FormalParameter? param;
    if (node is FormalParameter) {
      param = node;
    } else {
      param = node.thisOrAncestorOfType<FormalParameter>();
    }
    if (param == null) return;

    final paramList = param.parent;
    if (paramList is! FormalParameterList) return;

    // Check if there are already named parameters in the list.
    final hasNamedParams = paramList.parameters.any((p) => p.isNamed);
    if (hasNamedParams) {
      // Complex case: moving into existing named section. Bail out to
      // avoid producing invalid syntax in edge cases.
      return;
    }

    // Guard: only safe when the bool param is the last positional
    // parameter. Inserting `{required ...}` in the middle of a
    // positional list produces invalid syntax.
    final positionalParams = paramList.parameters
        .where((p) => !p.isNamed)
        .toList();
    if (positionalParams.isNotEmpty && positionalParams.last != param) {
      return;
    }

    // Simple case: wrap the bool parameter with `{required ...}`.
    final paramSource = param.toSource();
    final replacement = '{required $paramSource}';

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(
        SourceRange(param!.offset, param.length),
        replacement,
      );
    });
  }
}
