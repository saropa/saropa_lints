// ignore_for_file: always_specify_types

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/source/source_range.dart';

/// True when an instance creation of [typeLexeme] should be reported by
/// Material deprecation rules.
///
/// * `package:flutter/...` → **true**
/// * Null [typeElement] or null library → **true**
/// * If [compilationUnit] declares a class-like [typeLexeme] → **false**
/// * Otherwise → **true** (unresolved snippet, non-Material dependency types that
///   reuse a Material name may be flagged — prefer renaming locally)
bool isMaterialMigrationInstanceCreationTarget({
  required Element? typeElement,
  required String typeLexeme,
  required CompilationUnit compilationUnit,
}) {
  if (typeElement == null) return true;
  final LibraryElement? lib = typeElement.library;
  if (lib == null) return true;
  final Uri uri = lib.uri;
  if (uri.isScheme('package') &&
      uri.pathSegments.isNotEmpty &&
      uri.pathSegments.first == 'flutter') {
    return true;
  }
  if (compilationUnitDeclaresClassLikeName(compilationUnit, typeLexeme)) {
    return false;
  }
  return true;
}

/// True when [unit] declares a class, mixin, enum, or type alias named [typeName].
bool compilationUnitDeclaresClassLikeName(
  CompilationUnit unit,
  String typeName,
) {
  for (final CompilationUnitMember d in unit.declarations) {
    if (d is ClassDeclaration && d.namePart.typeName.lexeme == typeName) {
      return true;
    }
    if (d is ClassTypeAlias && d.name.lexeme == typeName) return true;
    if (d is EnumDeclaration && d.namePart.typeName.lexeme == typeName) {
      return true;
    }
    if (d is MixinDeclaration && d.name.lexeme == typeName) return true;
  }
  return false;
}

/// Source range to delete a [NamedExpression] inside an [ArgumentList], including
/// an adjacent comma and surrounding whitespace (leading or trailing).
///
/// Returns null when [named] is not a direct child of an argument list.
///
/// For a **middle** named argument, only a **leading** comma is absorbed (not
/// both neighbors) so `a: 1, b: 2, c: 3` stays valid after removing `b: 2`.
SourceRange? sourceRangeForDeletingNamedArgument(
  String unitContent,
  NamedExpression named,
) {
  if (named.parent is! ArgumentList) return null;

  int start = named.offset;
  int end = named.end;
  var ateLeadingComma = false;

  if (start > 0) {
    int i = start - 1;
    while (i >= 0 &&
        (unitContent[i] == ' ' ||
            unitContent[i] == '\t' ||
            unitContent[i] == '\n')) {
      i--;
    }
    if (i >= 0 && unitContent[i] == ',') {
      while (i > 0 &&
          (unitContent[i - 1] == ' ' || unitContent[i - 1] == '\t')) {
        i--;
      }
      start = i;
      ateLeadingComma = true;
    }
  }

  if (!ateLeadingComma && end < unitContent.length) {
    int i = end;
    while (i < unitContent.length &&
        (unitContent[i] == ' ' || unitContent[i] == '\t')) {
      i++;
    }
    if (i < unitContent.length && unitContent[i] == ',') {
      i++;
      while (i < unitContent.length &&
          (unitContent[i] == ' ' || unitContent[i] == '\t')) {
        i++;
      }
      end = i;
    }
  }

  return SourceRange(start, end - start);
}
