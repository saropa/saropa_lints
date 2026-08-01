import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:saropa_lints/src/target_matcher_utils.dart';
import 'package:test/test.dart';

FunctionBody _parseDisposeBody(String classSource) {
  final unit =
      parseString(content: classSource, throwIfDiagnostics: false).unit;
  for (final decl in unit.declarations) {
    if (decl is ClassDeclaration) {
      for (final member in decl.childEntities) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          return member.body;
        }
      }
    }
  }
  throw StateError('No dispose() found');
}

void main() {
  group('isFieldCleanedUpInSource - regex path', () {
    test('plain dot call', () {
      expect(
        isFieldCleanedUpInSource('_ctrl', 'dispose', '_ctrl.dispose();'),
        isTrue,
      );
    });

    test('null-aware call', () {
      expect(
        isFieldCleanedUpInSource('_ctrl', 'dispose', '_ctrl?.dispose();'),
        isTrue,
      );
    });

    test('cascade call', () {
      expect(
        isFieldCleanedUpInSource(
          '_ctrl',
          'dispose',
          '_ctrl..removeListener(f)..dispose();',
        ),
        isTrue,
      );
    });

    test('cascade without target method returns false', () {
      expect(
        isFieldCleanedUpInSource(
          '_ctrl',
          'dispose',
          '_ctrl..removeListener(f);',
        ),
        isFalse,
      );
    });

    test('cascade close', () {
      expect(
        isFieldCleanedUpInSource(
          '_sub',
          'cancel',
          '_sub..pause()..cancel();',
        ),
        isTrue,
      );
    });

    test('different field name returns false', () {
      expect(
        isFieldCleanedUpInSource('_other', 'dispose', '_ctrl..dispose();'),
        isFalse,
      );
    });

    test('does not match across statement boundaries', () {
      expect(
        isFieldCleanedUpInSource(
          '_ctrl',
          'dispose',
          '_ctrl..removeListener(f); _other..dispose();',
        ),
        isFalse,
      );
    });

    test('single cascade section', () {
      expect(
        isFieldCleanedUpInSource('_ctrl', 'dispose', '_ctrl..dispose();'),
        isTrue,
      );
    });

    test('three cascade sections', () {
      expect(
        isFieldCleanedUpInSource(
          '_ctrl',
          'dispose',
          '_ctrl..removeListener(a)..removeListener(b)..dispose();',
        ),
        isTrue,
      );
    });
  });

  group('hasCascadeCleanup - AST path', () {
    test('single cascade section: field..dispose()', () {
      final body = _parseDisposeBody('''
class S {
  void dispose() {
    _ctrl..dispose();
  }
}
''');
      expect(hasCascadeCleanup('_ctrl', 'dispose', body), isTrue);
    });

    test('multi-section cascade: field..removeListener(f)..dispose()', () {
      final body = _parseDisposeBody('''
class S {
  void dispose() {
    _ctrl..removeListener(f)..dispose();
  }
}
''');
      expect(hasCascadeCleanup('_ctrl', 'dispose', body), isTrue);
    });

    test('three sections', () {
      final body = _parseDisposeBody('''
class S {
  void dispose() {
    _ctrl..removeListener(a)..removeListener(b)..dispose();
  }
}
''');
      expect(hasCascadeCleanup('_ctrl', 'dispose', body), isTrue);
    });

    test('cascade without dispose returns false', () {
      final body = _parseDisposeBody('''
class S {
  void dispose() {
    _ctrl..removeListener(f);
  }
}
''');
      expect(hasCascadeCleanup('_ctrl', 'dispose', body), isFalse);
    });

    test('different field returns false', () {
      final body = _parseDisposeBody('''
class S {
  void dispose() {
    _other..dispose();
  }
}
''');
      expect(hasCascadeCleanup('_ctrl', 'dispose', body), isFalse);
    });

    test('cascade with closure containing semicolons', () {
      final body = _parseDisposeBody('''
class S {
  void dispose() {
    _ctrl..addListener(() { doSomething(); })..dispose();
  }
}
''');
      expect(hasCascadeCleanup('_ctrl', 'dispose', body), isTrue);
    });

    test('PropertyAccess target: this._ctrl..dispose()', () {
      final body = _parseDisposeBody('''
class S {
  void dispose() {
    this._ctrl..removeListener(f)..dispose();
  }
}
''');
      expect(hasCascadeCleanup('_ctrl', 'dispose', body), isTrue);
    });

    test('does not match dispose on a nested cascade target', () {
      final body = _parseDisposeBody('''
class S {
  void dispose() {
    _other..addListener(() { _ctrl..dispose(); });
  }
}
''');
      expect(hasCascadeCleanup('_other', 'dispose', body), isFalse);
    });
  });

  group('hasCascadeCleanupWhere - predicate matching', () {
    test('matches disposeSafe via predicate', () {
      final body = _parseDisposeBody('''
class S {
  void dispose() {
    _ctrl..removeListener(f)..disposeSafe();
  }
}
''');
      expect(
        hasCascadeCleanupWhere(
          '_ctrl',
          (name) => name.contains('dispose') || name.contains('Dispose'),
          body,
        ),
        isTrue,
      );
    });
  });

  group('isFieldCleanedUp - combined regex + AST', () {
    test('direct call via regex', () {
      final body = _parseDisposeBody('''
class S {
  void dispose() {
    _ctrl.dispose();
  }
}
''');
      expect(isFieldCleanedUp('_ctrl', 'dispose', body), isTrue);
    });

    test('cascade via AST', () {
      final body = _parseDisposeBody('''
class S {
  void dispose() {
    _ctrl..removeListener(f)..dispose();
  }
}
''');
      expect(isFieldCleanedUp('_ctrl', 'dispose', body), isTrue);
    });

    test('no cleanup returns false', () {
      final body = _parseDisposeBody('''
class S {
  void dispose() {
    _ctrl..removeListener(f);
  }
}
''');
      expect(isFieldCleanedUp('_ctrl', 'dispose', body), isFalse);
    });
  });
}
