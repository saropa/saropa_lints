// ignore_for_file: depend_on_referenced_packages

/// Utilities for resolving [Element] from analyzer identifier-like AST nodes.
library;

import 'dart:developer' as developer;

import 'package:analyzer/dart/element/element.dart';

/// Best-effort [Element] for nodes that expose `.element` and/or `.staticElement`
/// (e.g. [SimpleIdentifier], [MethodInvocation.methodName],
/// [PropertyAccess.propertyName], [ConstructorName]).
///
/// Order: tries `.element` (analyzer 9+ style), then `.staticElement` (older
/// resolution paths). Exceptions from either access are swallowed unless
/// [logFailures] is true (useful for debugging rule crashes without spamming
/// hot paths).
Element? elementFromAstIdentifier(Object? id, {bool logFailures = false}) {
  if (id == null) return null;
  try {
    final dynamic d = id;
    final Object? e = d.element;
    if (e is Element) return e;
  } on Object catch (e, st) {
    if (logFailures) {
      developer.log(
        'elementFromAstIdentifier .element failed',
        name: 'saropa_lints',
        error: e,
        stackTrace: st,
      );
    }
  }
  try {
    final dynamic d = id;
    final Object? s = d.staticElement;
    if (s is Element) return s;
  } on Object catch (e, st) {
    if (logFailures) {
      developer.log(
        'elementFromAstIdentifier .staticElement failed',
        name: 'saropa_lints',
        error: e,
        stackTrace: st,
      );
    }
  }
  return null;
}
