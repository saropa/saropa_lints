// Proves the assumption behind `isConstBackedList`: a bare name with a
// top-level declaration binds to it even when a supertype or mixin, in this
// file or another, declares the same name. Checked against the analyzer's own
// element resolution.
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/widget_ancestor_utils.dart';
import 'package:test/test.dart';

import '../../support/safe_delete.dart';

/// Supertypes living in another file, each declaring `items`.
const String _other = '''
class Base {
  List<String> items = <String>[];
}

mixin Mixed {
  List<String> get items => <String>[];
}

class Middle extends Base {}
''';

const String _constItems = "const List<String> items = <String>['a'];";

/// A class whose method counts a list by the bare name `items`.
String _user(String header, [String members = '']) =>
    '''
class ListView {
  ListView({Object? itemCount});
}

$header {
  $members
  Object build() => ListView(itemCount: items.length);
}
''';

void main() {
  late Directory dir;
  late AnalysisContextCollection collection;
  var counter = 0;

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('saropa_scoping_');
    File(p.join(dir.path, 'other.dart')).writeAsStringSync(_other);
    File(p.join(dir.path, 'consts.dart')).writeAsStringSync('$_constItems\n');
    collection = AnalysisContextCollection(
      includedPaths: [p.normalize(dir.path)],
    );
  });

  tearDownAll(() async {
    await collection.dispose();
    safeDeleteDir(dir);
  });

  /// Resolves [code] and returns where `items` is declared (`library` or the
  /// enclosing type's name) plus the helper's verdict.
  Future<(String?, bool)> check(String code) async {
    final path = p.normalize(p.join(dir.path, 'case${counter++}.dart'));
    File(path).writeAsStringSync(code);
    final context = collection.contextFor(path);
    context.changeFile(path);
    await context.applyPendingFileChanges();
    final result = await context.currentSession.getResolvedUnit(path);
    final finder = _Count();
    (result as ResolvedUnitResult).unit.accept(finder);
    final owner = finder.count?.prefix.element?.enclosingElement;
    final arguments = finder.arguments;
    expect(arguments, isNotNull);
    return (
      owner is LibraryElement ? 'library' : owner?.name,
      isConstBackedList(arguments!),
    );
  }

  const supertypes = <String, String>{
    'base class': 'class C extends Base',
    'indirect base': 'class C extends Middle',
    'mixin': 'class C with Mixed',
    'base and mixin': 'class C extends Base with Mixed',
  };
  const import = "import 'other.dart';";

  for (final entry in supertypes.entries) {
    test('${entry.key}: the top-level constant wins', () async {
      final code = '$import\n$_constItems\n${_user(entry.value)}';
      expect(await check(code), ('library', true));
    });

    // Control: without a top-level declaration the member is what binds,
    // and it is runtime data, so the lint must stay.
    test('${entry.key}: alone, the member binds and is not const', () async {
      final (owner, constant) = await check('$import\n${_user(entry.value)}');
      expect(owner, isIn(['Base', 'Mixed']));
      expect(constant, isFalse);
    });
  }

  // An imported constant also beats the inherited member, but the helper only
  // reads this file, so it keeps the lint.
  test('imported constant: binds to the library, lint kept', () async {
    final code =
        "$import\nimport 'consts.dart';\n${_user('class C extends Base')}";
    expect(await check(code), ('library', false));
  });

  test('a member declared by the class itself does shadow', () async {
    final code =
        '$_constItems\n${_user('class C', 'List<String> items = [];')}';
    expect(await check(code), ('C', false));
  });
}

/// Finds the `items.length` count and the argument list holding it.
class _Count extends RecursiveAstVisitor<void> {
  PrefixedIdentifier? count;
  ArgumentList? arguments;

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.identifier.name == 'length') {
      count = node;
      arguments = node.thisOrAncestorOfType<ArgumentList>();
    }
    super.visitPrefixedIdentifier(node);
  }
}
