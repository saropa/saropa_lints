// ignore_for_file: depend_on_referenced_packages

/// Base class for saropa_lints quick fixes in the native plugin system.
/// Fixes are registered per-rule in [SaropaLintRule.fixGenerators]; the
/// analysis server invokes them when the user applies a quick fix from the IDE.
///
/// Extends [ResolvedCorrectionProducer] with saropa-specific defaults.
/// Subclasses must override [fixKind] and [compute].
///
/// Example:
/// ```dart
/// class MyFix extends SaropaFixProducer {
///   MyFix({required super.context});
///
///   @override
///   FixKind get fixKind => FixKind(
///     'saropa.fix.myFix',
///     50,
///     'Description of the fix',
///   );
///
///   @override
///   CorrectionApplicability get applicability =>
///       CorrectionApplicability.singleLocation;
///
///   @override
///   Future<void> compute(ChangeBuilder builder) async {
///     var node = coveringNode;
///     if (node == null) return;
///     await builder.addDartFileEdit(file, (builder) {
///       builder.addSimpleReplacement(
///         SourceRange(node.offset, node.length),
///         'replacement',
///       );
///     });
///   }
/// }
/// ```
library;

import 'dart:developer' as developer;

import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/src/correction/fix_generators.dart';
import 'package:analyzer/dart/ast/ast.dart';

export 'package:analysis_server_plugin/edit/dart/correction_producer.dart'
    show CorrectionApplicability, CorrectionProducerContext;
export 'package:analysis_server_plugin/src/correction/fix_generators.dart'
    show ProducerGenerator;
export 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart'
    show ChangeBuilder;
export 'package:analyzer_plugin/utilities/fixes/fixes.dart' show FixKind;

/// Base class for all saropa_lints quick fixes.
///
/// Provides a default [applicability] of [CorrectionApplicability.singleLocation].
/// Subclasses must override [fixKind] and [compute].
abstract class SaropaFixProducer extends ResolvedCorrectionProducer {
  SaropaFixProducer({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  /// Returns the leading whitespace of the line containing [node].
  ///
  /// Useful for inserting or wrapping code at the same indentation level.
  /// Only returns spaces and tabs — stops at the first non-whitespace char.
  /// Returns empty string if [node], lineInfo, or content is unavailable.
  String getLineIndent(AstNode? node) {
    if (node == null) return '';
    try {
      final lineInfo = unitResult.lineInfo;
      final content = unitResult.content;
      if (content.isEmpty) return '';

      final location = lineInfo.getLocation(node.offset);
      final line = location.lineNumber - 1;
      if (line < 0) return '';

      final lineStart = lineInfo.getOffsetOfLine(line);
      if (lineStart < 0 || lineStart >= content.length) return '';

      final indent = StringBuffer();
      for (var i = lineStart; i < content.length; i++) {
        final ch = content[i];
        if (ch == ' ' || ch == '\t') {
          indent.write(ch);
        } else {
          break;
        }
      }
      return indent.toString();
    } catch (e, st) {
      developer.log(
        'getLineIndent failed',
        name: 'saropa_lints',
        error: e,
        stackTrace: st,
      );
      return '';
    }
  }
}

/// Factory function that creates a fix producer.
///
/// Re-exported from [ProducerGenerator] for convenience so rule files
/// don't need to import from analysis_server_plugin internals.
typedef SaropaFixGenerator = ProducerGenerator;
