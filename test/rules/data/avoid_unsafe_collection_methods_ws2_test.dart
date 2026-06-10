import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:saropa_lints/src/rules/data/collection_rules.dart';
import 'package:test/test.dart';

/// WS-2 false-positive fixes for `avoid_unsafe_collection_methods`. The rule's
/// report gate needs a resolved collection type, but its GUARD recognition is
/// pure syntactic analysis, exercised here on unresolved `parseString` ASTs via
/// `isAccessGuardedForTesting`. `true` = recognized non-empty (NO lint); `false`
/// = unguarded (the rule would report).
void main() {
  bool guarded(String body) {
    final unit = parseString(
      content: 'class _C { void m() { $body } }',
      throwIfDiagnostics: false,
    ).unit;
    final finder = _AccessFinder();
    unit.accept(finder);
    return AvoidUnsafeCollectionMethodsRule.isAccessGuardedForTesting(
      finder.node!,
      finder.target!,
    );
  }

  group('NO lint — guard recognized', () {
    test('Pattern 1: combined `== null || isEmpty` early return', () {
      expect(
        guarded('if (pages == null || pages.isEmpty) { return; } pages.first;'),
        isTrue,
      );
    });

    test('Pattern 2a: `|| length < 2` early return', () {
      expect(
        guarded('if (xs == null || xs.length < 2) { return; } xs.first;'),
        isTrue,
      );
    });

    test('Pattern 2b: `length <= 1` early return', () {
      expect(guarded('if (xs.length <= 1) { return; } xs.first;'), isTrue);
    });

    test('Pattern 3: `continue` guard in a for loop', () {
      expect(
        guarded(
          'for (final c in groups) { if (c.length != 1) { continue; } '
          'c.first; }',
        ),
        isTrue,
      );
    });

    test('Pattern 4: access nested one block below the guard', () {
      expect(
        guarded(
          'if (contacts.isEmpty) { return; } if (true) { contacts.first; }',
        ),
        isTrue,
      );
    });

    test('Pattern 5a: map.keys.first after `if (map.isEmpty) return`', () {
      expect(
        guarded('if (buckets.isEmpty) { return; } buckets.keys.first;'),
        isTrue,
      );
    });

    test('Pattern 5b: map.keys.first inside `while (map.length > n)`', () {
      expect(
        guarded('while (map.length > maxN) { map.keys.first; }'),
        isTrue,
      );
    });

    test('Pattern 6: extension `isListNullOrEmpty` early return', () {
      expect(
        guarded('if (files.isListNullOrEmpty) { return; } files.first;'),
        isTrue,
      );
    });

    test('Pattern 6 (chained `?.` + `?? true`, access via `!`)', () {
      expect(
        guarded(
          'if (result?.files.isListNullOrEmpty ?? true) { return; } '
          'result!.files.first;',
        ),
        isTrue,
      );
    });

    test('Pattern 7: indexed target with inline isNotEmpty guard', () {
      expect(
        guarded('if (props[k]!.isNotEmpty) { props[k]!.first; }'),
        isTrue,
      );
    });

    test('Pattern 8: split() result through a local variable', () {
      expect(
        guarded("final parts = prefix.split(';'); parts.first;"),
        isTrue,
      );
    });
  });

  group('LINT — genuinely unguarded (true positives preserved)', () {
    test('bare access with no guard', () {
      expect(guarded('items.last;'), isFalse);
    });

    test('ternary condition unrelated to the collection', () {
      expect(guarded('flag ? items.first : fallback;'), isFalse);
    });
  });
}

/// Finds the first `.first`/`.last`/`.single` access and its target.
class _AccessFinder extends RecursiveAstVisitor<void> {
  static const Set<String> _unsafe = <String>{'first', 'last', 'single'};
  AstNode? node;
  Expression? target;

  @override
  void visitPropertyAccess(PropertyAccess n) {
    if (node == null && _unsafe.contains(n.propertyName.name)) {
      node = n;
      target = n.realTarget;
    }
    super.visitPropertyAccess(n);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier n) {
    if (node == null && _unsafe.contains(n.identifier.name)) {
      node = n;
      target = n.prefix;
    }
    super.visitPrefixedIdentifier(n);
  }
}
