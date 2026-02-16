// ignore_for_file: depend_on_referenced_packages

/// Base class for saropa_lints quick fixes in the native plugin system.
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

import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/src/correction/fix_generators.dart';

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
}

/// Factory function that creates a fix producer.
///
/// Re-exported from [ProducerGenerator] for convenience so rule files
/// don't need to import from analysis_server_plugin internals.
typedef SaropaFixGenerator = ProducerGenerator;
