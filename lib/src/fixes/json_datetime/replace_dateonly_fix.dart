// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace the strip-time idiom with DateUtils.dateOnly().
///
/// Matches `DateTime(x.year, x.month, x.day)` where x is a non-nullable
/// DateTime, and replaces it with `DateUtils.dateOnly(x)`.
/// Also matches the explicit-midnight-zeros variant:
/// `DateTime(x.year, x.month, x.day, 0, 0, 0)` (3-6 trailing zero literals).
///
/// Not offered for:
///   - `.utc()` constructors (bails on any named constructor; DateUtils.dateOnly
///     returns local time, so UTC semantics would be lost)
///   - nullable receivers (DateUtils.dateOnly doesn't accept DateTime?)
///   - non-DateTime types that happen to have .year/.month/.day
///   - fewer than 3 positional args or non-zero trailing args
///   - named arguments present
///   - mismatched receivers across the 3 property-access args
///   - pure Dart projects (no package:flutter/ import in the file)
class ReplaceDateOnlyFix extends SaropaFixProducer {
  ReplaceDateOnlyFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceDateOnly',
    60,
    'Replace with DateUtils.dateOnly()',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // Walk up to the InstanceCreationExpression.
    final creation = node is InstanceCreationExpression
        ? node
        : node.thisOrAncestorOfType<InstanceCreationExpression>();
    if (creation == null) return;

    // Must be unnamed DateTime constructor (not .utc, .fromMilliseconds, etc.).
    final constructorName = creation.constructorName;
    if (constructorName.type.name.lexeme != 'DateTime') return;
    if (constructorName.name != null) return;

    final args = creation.argumentList.arguments;

    // Need at least 3 positional args (.year, .month, .day). Accept 4-6 only
    // if the trailing args are all integer literal 0 (the explicit-midnight
    // variant: DateTime(x.year, x.month, x.day, 0, 0, 0)).
    if (args.length < 3 || args.length > 6) return;
    if (args.any((a) => a is NamedExpression)) return;

    // Trailing args beyond the first 3 must all be literal 0.
    for (var i = 3; i < args.length; i++) {
      final arg = args[i];
      if (arg is! IntegerLiteral || arg.value != 0) return;
    }

    // Each arg must be a property access with .year, .month, .day (in order).
    const expectedProperties = ['year', 'month', 'day'];
    final receivers = <String>[];

    for (var i = 0; i < 3; i++) {
      final arg = args[i];
      final propertyName = _getPropertyName(arg);
      if (propertyName != expectedProperties[i]) return;

      final receiver = _getReceiverSource(arg);
      if (receiver == null) return;
      receivers.add(receiver);
    }

    // All three must share the same receiver.
    if (receivers[0] != receivers[1] || receivers[1] != receivers[2]) return;

    // Receiver's static type must be non-nullable DateTime.
    final receiverType = _getReceiverStaticType(args[0]);
    if (receiverType == null) return;
    if (!_isDateTime(receiverType)) return;
    if (receiverType.nullabilitySuffix != NullabilitySuffix.none) return;

    // DateUtils lives in package:flutter/material.dart — bail in pure Dart
    // projects where Flutter is not available (no flutter import in the file).
    if (!_hasFlutterImport(creation)) return;

    final receiverSource = receivers[0];
    final replacement = 'DateUtils.dateOnly($receiverSource)';

    await builder.addDartFileEdit(file, (builder) {
      // Replace the entire DateTime(...) expression.
      builder.addSimpleReplacement(
        SourceRange(creation.offset, creation.length),
        replacement,
      );

      // Ensure flutter/material.dart is imported (provides DateUtils).
      builder.importLibrary(
        Uri.parse('package:flutter/material.dart'),
      );
    });
  }

  /// Extracts the property name from a PropertyAccess or PrefixedIdentifier.
  /// Returns null if the node is neither type.
  static String? _getPropertyName(Expression expr) {
    if (expr is PropertyAccess) return expr.propertyName.name;
    if (expr is PrefixedIdentifier) return expr.identifier.name;
    return null;
  }

  /// Extracts the receiver source from a PropertyAccess or PrefixedIdentifier.
  /// Returns null if the node is neither type.
  static String? _getReceiverSource(Expression expr) {
    if (expr is PropertyAccess) return expr.target?.toSource();
    if (expr is PrefixedIdentifier) return expr.prefix.toSource();
    return null;
  }

  /// Gets the static type of the receiver expression.
  /// Returns null if the type can't be resolved.
  static DartType? _getReceiverStaticType(Expression expr) {
    if (expr is PropertyAccess) return expr.target?.staticType;
    if (expr is PrefixedIdentifier) return expr.prefix.staticType;
    return null;
  }

  /// Checks if a DartType is the core DateTime type (dart:core).
  static bool _isDateTime(DartType type) {
    if (type is! InterfaceType) return false;
    return type.element.name == 'DateTime' &&
        type.element.library.uri.toString() == 'dart:core';
  }

  /// Returns true if the compilation unit containing [node] has at least one
  /// `package:flutter/` import. Without Flutter, DateUtils is unavailable and
  /// the fix would produce unresolvable code.
  static bool _hasFlutterImport(AstNode node) {
    final unit = node.thisOrAncestorOfType<CompilationUnit>();
    if (unit == null) return false;
    for (final directive in unit.directives) {
      if (directive is ImportDirective) {
        final uri = directive.uri.stringValue;
        if (uri != null && uri.startsWith('package:flutter/')) return true;
      }
    }
    return false;
  }
}
