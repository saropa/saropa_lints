// Resolved-analyzer tests for `avoid_path_traversal`.
//
// The rule decides whether a parameter reaches a `File`/`Directory` path by
// looking at identifier references. These tests pin both directions: a property
// or literal that merely SPELLS a parameter name stays silent, and every real
// reference to a parameter (this is a security rule) still reports.
//
// Fixtures deliberately avoid the validator and platform-API words
// (`basename`, `startsWith`, `systemTemp`, ...), because any of those in the
// enclosing body suppresses the rule and would make a negative assertion pass
// for the wrong reason.
library;

import 'package:saropa_lints/src/rules/security/security_network_input_rules.dart';
import 'package:test/test.dart';

import '../../support/fixture_message_harness.dart';

void main() {
  group('AvoidPathTraversalRule - parameter references', () {
    final rule = AvoidPathTraversalRule();

    test('silent when only a property shares the parameter name', () async {
      await assertFixtureMarkers(rule, '''
import 'dart:io';

void probe(String path) {
  final Directory appDir = Directory('/data/app');
  // LINT_NOT: avoid_path_traversal
  File('\${appDir.path}/.write_probe');
}
''');
    });

    test('silent when literal text or a field spells the name', () async {
      await assertFixtureMarkers(rule, '''
import 'dart:io';

class Store {
  final String name = 'fixed';

  void save(String id, String name) {
    final String root = '/data';
    // LINT_NOT: avoid_path_traversal
    File('\$root/id.json');
    // LINT_NOT: avoid_path_traversal
    File('\$root/\${this.name}');
  }
}
''');
    });

    test('silent when a local shadows the parameter name', () async {
      await assertFixtureMarkers(rule, '''
import 'dart:io';

void probe(String path) {
  if (path.isEmpty) {
    final String path = 'fixed';
    // LINT_NOT: avoid_path_traversal
    File('/data/\$path');
  }
}
''');
    });

    test('fires when the parameter really reaches the path', () async {
      await assertFixtureMarkers(rule, '''
import 'dart:io';

void interpolated(String path) {
  final Directory dir = Directory('/data');
  // LINT: avoid_path_traversal
  File('\${dir.path}/\$path');
}

void concatenated(String name) {
  // LINT: avoid_path_traversal
  File('/data/' + name);
}

void viaProperty(Uri uri) {
  // LINT: avoid_path_traversal
  Directory('/data\${uri.path}');
}

void indexed(Map<String, String> params) {
  // LINT: avoid_path_traversal
  File('/data/\${params['file']}');
}
''');
    });

    test('fires when a later parameter is not fed only literals', () async {
      // `folder` only ever receives a literal, `name` does not. Checking just
      // the first referenced parameter used to suppress this report.
      await assertFixtureMarkers(rule, '''
import 'dart:io';

void _open(String folder, String name) {
  // LINT: avoid_path_traversal
  File('\$folder/\$name');
}

void entry(String userInput) => _open('data', userInput);
''');
    });

    test('silent when every parameter is fed only literals', () async {
      await assertFixtureMarkers(rule, '''
import 'dart:io';

void _open(String folder, String name) {
  // LINT_NOT: avoid_path_traversal
  File('\$folder/\$name');
}

void entry() => _open('data', 'file.txt');
''');
    });
  });
}
