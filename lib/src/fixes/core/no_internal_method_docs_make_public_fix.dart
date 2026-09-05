// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Removes the leading underscore from a private declaration's
/// name, making it public.
///
/// Matches `NoInternalMethodDocsRule`, which reports the [Comment] node
/// (the `///` doc comment attached to a private method, function, or
/// constructor). The rule's premise is that a DartDoc comment on a private
/// member is either dead documentation or a sign the member should be
/// public. This fix takes the second reading: instead of downgrading the
/// comment to `//`, it strips the leading `_` from the declaration's name
/// so the `///` comment becomes legitimate public API documentation.
///
/// This only edits the declaration's name token — it does not rename call
/// sites elsewhere in the file or project. A member that already has other
/// private-only usages (e.g. relying on library-private access) may need
/// manual follow-up after applying this fix.
class NoInternalMethodDocsMakePublicFix extends SaropaFixProducer {
  NoInternalMethodDocsMakePublicFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.noInternalMethodDocsMakePublic',
    49,
    'Make member public (remove underscore)',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final AstNode? node = coveringNode;
    if (node == null) return;

    // The rule reports on the Comment node directly, but the fix also
    // tolerates being invoked from a child token/node inside it.
    final Comment? comment = node is Comment
        ? node
        : node.thisOrAncestorOfType<Comment>();
    if (comment == null) return;

    // The doc comment is only ever attached as the documentationComment of
    // the declaration that owns it, so the parent node is the declaration
    // to rename. Only methods, functions, and constructors are reported by
    // this rule, so those are the only three shapes handled here.
    final AstNode? declaration = comment.parent;
    final SourceRange? nameRange = switch (declaration) {
      MethodDeclaration(:final name) => SourceRange(name.offset, name.length),
      FunctionDeclaration(:final name) => SourceRange(
        name.offset,
        name.length,
      ),
      ConstructorDeclaration(name: final Token? name) when name != null =>
        SourceRange(name.offset, name.length),
      _ => null,
    };
    if (nameRange == null) return;

    // Removing exactly the first character of the name range strips the
    // leading underscore without touching the rest of the identifier.
    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(SourceRange(nameRange.offset, 1), '');
    });
  }
}
