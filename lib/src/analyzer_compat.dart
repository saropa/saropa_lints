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

/// Safe `.body.members` access for [ClassDeclaration] in analyzer v9.
///
/// In analyzer v9 the `useDeclaringConstructorsAst` feature gate is not
/// enabled by default. Accessing `.body` on class-like declarations throws
/// `UnsupportedError` at runtime. The pre-gate API exposes `.members`
/// directly on the declaration node — this extension tries the modern path
/// first and falls back to the legacy one.
extension SafeClassDeclMembers on ClassDeclaration {
  /// Members declared inside this class.
  ///
  /// Tries `.body.members` (analyzer 10+), falls back to the pre-declaring-
  /// constructors `.members` API (analyzer 9).
  List<ClassMember> get bodyMembers {
    try {
      return body.members;
    } on UnsupportedError {
      // analyzer v9: useDeclaringConstructorsAst gate not enabled,
      // members live directly on the declaration
      try {
        return (this as dynamic).members as List<ClassMember>;
      } catch (_) {
        return const [];
      }
    }
  }
}

/// Safe `.body.members` access for [EnumDeclaration] in analyzer v9.
///
/// See [SafeClassDeclMembers] for rationale.
extension SafeEnumDeclMembers on EnumDeclaration {
  /// Members declared inside this enum.
  List<ClassMember> get bodyMembers {
    try {
      return body.members;
    } on UnsupportedError {
      try {
        return (this as dynamic).members as List<ClassMember>;
      } catch (_) {
        return const [];
      }
    }
  }
}

/// Safe `.body.members` access for [MixinDeclaration] in analyzer v9.
///
/// See [SafeClassDeclMembers] for rationale.
extension SafeMixinDeclMembers on MixinDeclaration {
  /// Members declared inside this mixin.
  List<ClassMember> get bodyMembers {
    try {
      return body.members;
    } on UnsupportedError {
      try {
        return (this as dynamic).members as List<ClassMember>;
      } catch (_) {
        return const [];
      }
    }
  }
}

/// Safe `.body.members` access for [ExtensionTypeDeclaration] in analyzer v9.
///
/// See [SafeClassDeclMembers] for rationale.
extension SafeExtensionTypeDeclMembers on ExtensionTypeDeclaration {
  /// Members declared inside this extension type.
  List<ClassMember> get bodyMembers {
    try {
      return body.members;
    } on UnsupportedError {
      try {
        return (this as dynamic).members as List<ClassMember>;
      } catch (_) {
        return const [];
      }
    }
  }
}

/// Safe `.body.members` access for [ExtensionDeclaration] in analyzer v9.
///
/// [ExtensionDeclaration.body] is nullable in some analyzer versions, so
/// this also handles the null case.
extension SafeExtensionDeclMembers on ExtensionDeclaration {
  /// Members declared inside this extension.
  List<ClassMember> get bodyMembers {
    try {
      return body?.members ?? const [];
    } on UnsupportedError {
      try {
        return (this as dynamic).members as List<ClassMember>;
      } catch (_) {
        return const [];
      }
    }
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
  Identifier? get typeName {
    final self = this as dynamic;
    try {
      final value = self.typeName;
      if (value is Identifier) return value;
    } on NoSuchMethodError {
      // analyzer 9/11 surface may not expose this getter.
    }
    try {
      final value = self.returnType;
      if (value is Identifier) return value;
    } on NoSuchMethodError {
      // analyzer 12+ surface removed returnType.
    }
    return null;
  }
}

/// Backfills `ExtensionTypeDeclaration.primaryConstructor` for analyzer 9 by
/// reading it from `namePart` when declaring constructors AST is enabled.
extension ExtensionTypePrimaryConstructorCompat on ExtensionTypeDeclaration {
  PrimaryConstructorDeclaration? get primaryConstructor {
    final self = this as dynamic;
    try {
      final value = self.primaryConstructor;
      if (value is PrimaryConstructorDeclaration) return value;
    } on NoSuchMethodError {
      // analyzer versions without this accessor.
    }
    try {
      final part = self.namePart;
      if (part is PrimaryConstructorDeclaration) {
        return part;
      }
    } on UnsupportedError {
      // Legacy extension-type AST shape has no primary constructor node.
    }
    return null;
  }
}
