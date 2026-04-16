// ignore_for_file: depend_on_referenced_packages

/// Compatibility shims for analyzer 11.
///
/// In analyzer 12, [ClassBody] exposes `.members` directly.
/// In analyzer 11, [ClassBody] is sealed with no `.members` — only
/// [BlockClassBody] has it, while [EmptyClassBody] has none.
///
/// This extension bridges the gap so rule code can continue using
/// `node.body.members` unchanged.
library;

import 'package:analyzer/dart/ast/ast.dart';

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
