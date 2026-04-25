import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:saropa_lints/src/rules/widget/state_lifecycle_dispose_scan.dart';
import 'package:test/test.dart';

void main() {
  group('isTrackedFieldDisposedInStateLifecycle', () {
    test('local alias then dispose in dispose() — disposed', () {
      final ClassDeclaration cls = _parseStateClass(r'''
class W {}
class _S extends State<W> {
  ScrollController? _scrollController;

  @override
  void dispose() {
    final ScrollController? c = _scrollController;
    if (c != null) {
      c.removeListener(_onScroll);
      c.dispose();
    }
    super.dispose();
  }

  void _onScroll() {}
}
''');
      expect(
        isTrackedFieldDisposedInStateLifecycle(
          cls,
          '_scrollController',
          {'_scrollController'},
        ),
        isTrue,
      );
    });

    test('bang local alias dispose — disposed', () {
      final ClassDeclaration cls = _parseStateClass(r'''
class W {}
class _S extends State<W> {
  ScrollController? _c;

  @override
  void dispose() {
    final ScrollController c = _c!;
    c.dispose();
    super.dispose();
  }
}
''');
      expect(
        isTrackedFieldDisposedInStateLifecycle(cls, '_c', {'_c'}),
        isTrue,
      );
    });

    test('dispose only in didUpdateWidget — disposed', () {
      final ClassDeclaration cls = _parseStateClass(r'''
class W {}
class _S extends State<W> {
  ScrollController? _c;

  @override
  void didUpdateWidget(W oldWidget) {
    super.didUpdateWidget(oldWidget);
    _c?.dispose();
  }
}
''');
      expect(
        isTrackedFieldDisposedInStateLifecycle(cls, '_c', {'_c'}),
        isTrue,
      );
    });

    test('private helper from dispose — disposed', () {
      final ClassDeclaration cls = _parseStateClass(r'''
class W {}
class _S extends State<W> {
  ScrollController? _c;

  @override
  void dispose() {
    _tearDown();
    super.dispose();
  }

  void _tearDown() {
    _c?.dispose();
  }
}
''');
      expect(
        isTrackedFieldDisposedInStateLifecycle(cls, '_c', {'_c'}),
        isTrue,
      );
    });

    test('alias with removeListener only — not disposed', () {
      final ClassDeclaration cls = _parseStateClass(r'''
class W {}
class _S extends State<W> {
  ScrollController? _c;

  @override
  void dispose() {
    final ScrollController? c = _c;
    if (c != null) {
      c.removeListener(_onScroll);
    }
    super.dispose();
  }

  void _onScroll() {}
}
''');
      expect(
        isTrackedFieldDisposedInStateLifecycle(cls, '_c', {'_c'}),
        isFalse,
      );
    });

    test('no disposal — not disposed', () {
      final ClassDeclaration cls = _parseStateClass(r'''
class W {}
class _S extends State<W> {
  ScrollController? _c;

  @override
  void initState() {
    super.initState();
    _c = ScrollController();
  }
}
''');
      expect(
        isTrackedFieldDisposedInStateLifecycle(cls, '_c', {'_c'}),
        isFalse,
      );
    });
  });
}

ClassDeclaration _parseStateClass(String source) {
  final result = parseString(
    content: '''
class StatefulWidget {}
class State<T> {
  void initState() {}
  void dispose() {}
  void didUpdateWidget(T oldWidget) {}
}
class ScrollController {
  void addListener(void Function() l) {}
  void removeListener(void Function() l) {}
  void dispose() {}
}
$source
''',
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );
  ClassDeclaration? found;
  result.unit.accept(
    _PickClassDeclaration((c) {
      if (c.namePart.typeName.lexeme == '_S') found = c;
    }),
  );
  expect(found, isNotNull, reason: 'fixture must declare _S');
  return found!;
}

class _PickClassDeclaration extends RecursiveAstVisitor<void> {
  _PickClassDeclaration(this.onClass);

  final void Function(ClassDeclaration node) onClass;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    onClass(node);
    super.visitClassDeclaration(node);
  }
}
