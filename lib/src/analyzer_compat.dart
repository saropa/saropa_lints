// ignore_for_file: depend_on_referenced_packages

/// Compatibility shims for analyzer 9-11.
///
/// In analyzer 12, [ClassBody] exposes `.members` directly.
/// In analyzer 11, [ClassBody] is sealed with no `.members` — only
/// [BlockClassBody] has it, while [EmptyClassBody] has none.
///
/// This extension bridges the gap so rule code can continue using
/// `node.body.members` unchanged.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart';

/// Provides `.members` on [ClassBody] for analyzer 11 compatibility.
///
/// In analyzer 12 this getter is native on [ClassBody].
/// In analyzer 11 only [BlockClassBody] has it; [EmptyClassBody] has no
/// members. This extension returns an empty list for [EmptyClassBody].
extension ClassBodyMembersCompat on ClassBody {
  /// The members declared in the class body.
  ///
  /// Returns the real member list for [BlockClassBody], or an empty
  /// unmodifiable list for [EmptyClassBody].
  List<ClassMember> get members {
    final self = this;
    if (self is BlockClassBody) return self.members;

    // EmptyClassBody — no members exist
    return const [];
  }
}

/// Backfills `DiagnosticCode.lowerCaseName` for analyzer versions that only
/// expose `name`.
extension DiagnosticCodeLowerCaseCompat on DiagnosticCode {
  /// Canonical snake_case rule name used in config keys and reports.
  String get lowerCaseName {
    final name = this.name;
    if (name.isEmpty) return '';
    // analyzer 9 exposes camelCase names for many lints.
    return name
        .replaceAllMapped(RegExp(r'(?<=[a-z0-9])[A-Z]'), (m) => '_${m[0]}')
        .replaceAll('-', '_')
        .toLowerCase();
  }
}

/// Backfills `ConstructorDeclaration.typeName` for analyzer 9 where the API
/// still exposes `returnType`.
extension ConstructorTypeNameCompat on ConstructorDeclaration {
  Identifier? get typeName => returnType;
}

/// Backfills `ExtensionTypeDeclaration.primaryConstructor` for analyzer 9 by
/// reading it from `namePart` when declaring constructors AST is enabled.
extension ExtensionTypePrimaryConstructorCompat on ExtensionTypeDeclaration {
  PrimaryConstructorDeclaration? get primaryConstructor {
    try {
      final part = namePart;
      if (part is PrimaryConstructorDeclaration) {
        return part;
      }
    } on UnsupportedError {
      // Legacy extension-type AST shape has no primary constructor node.
    }
    return null;
  }
}
