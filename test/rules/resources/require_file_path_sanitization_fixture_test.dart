// Resolved-analyzer tests for `require_file_path_sanitization`.
//
// The rule decides whether a parameter reaches a `File`/`Directory` path by
// looking at identifier references. These tests pin both directions: a property
// or literal that merely SPELLS a parameter name stays silent, and every real
// reference to a parameter (this is a security rule) still reports.
//
// Fixtures deliberately avoid cascades, spreads and the sanitizer/platform-API
// words, because any of those in the enclosing body suppresses the rule and
// would make a negative assertion pass for the wrong reason.
library;

import 'package:saropa_lints/src/rules/resources/file_handling_rules.dart';
import 'package:test/test.dart';

import '../../support/fixture_message_harness.dart';

void main() {
  group('RequireFilePathSanitizationRule - resolved', () {
    final rule = RequireFilePathSanitizationRule();

    test('silent when only a property shares the parameter name', () async {
      await assertFixtureMarkers(rule, '''
import 'dart:io';

void probe(String? path) {
  final Directory appDir = Directory('/data/app');
  // LINT_NOT: require_file_path_sanitization
  File('\${appDir.path}/.write_probe');
}
''');
    });

    test('silent on a property of a dynamic receiver', () async {
      // No element resolves for the property, so the structural skip (not the
      // element comparison) has to reject it.
      await assertFixtureMarkers(rule, '''
import 'dart:io';

dynamic settings;

void probe(String path) {
  // LINT_NOT: require_file_path_sanitization
  File('\${settings.path}/probe');
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
    // LINT_NOT: require_file_path_sanitization
    File('\$root/id.json');
    // LINT_NOT: require_file_path_sanitization
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
    // LINT_NOT: require_file_path_sanitization
    File('/data/\$path');
  }
}
''');
    });

    test('fires on interpolated parameter after a .path read', () async {
      await assertFixtureMarkers(rule, '''
import 'dart:io';

void probe(String path) {
  final Directory dir = Directory('/data');
  // LINT: require_file_path_sanitization
  File('\${dir.path}/\$path');
}
''');
    });

    test('fires on concatenated parameter', () async {
      await assertFixtureMarkers(rule, '''
import 'dart:io';

void probe(String name) {
  // LINT: require_file_path_sanitization
  File('/data/' + name);
}
''');
    });

    test('fires when the parameter is the receiver of a member', () async {
      await assertFixtureMarkers(rule, '''
import 'dart:io';

class Request {
  String fileName = '';
  String pick() => fileName;
}

void viaProperty(Request request) {
  // LINT: require_file_path_sanitization
  File('/data/\${request.fileName}');
}

void viaMethod(Request request) {
  // LINT: require_file_path_sanitization
  File('/data/\${request.pick()}');
}

void viaUri(Uri uri) {
  // LINT: require_file_path_sanitization
  File('/data\${uri.path}');
}

void viaDynamic(dynamic payload) {
  // LINT: require_file_path_sanitization
  File('/data/\${payload.name}');
}
''');
    });

    test('fires when a Directory parameter is the path base', () async {
      // The parameter itself is referenced, so this stays in scope even though
      // the appended segment is constant.
      await assertFixtureMarkers(rule, '''
import 'dart:io';

void probe(String? path, Directory appDir) {
  // LINT: require_file_path_sanitization
  File('\${appDir.path}/.write_probe');
}
''');
    });

    test('fires on parameter nested in a call and an index', () async {
      await assertFixtureMarkers(rule, '''
import 'dart:io';

String wrap(String value) => value;

void nested(String name) {
  // LINT: require_file_path_sanitization
  File('/data/\${wrap(name)}');
}

void indexed(Map<String, String> params) {
  // LINT: require_file_path_sanitization
  File('/data/\${params['file']}');
}

void callback(String Function() build) {
  // LINT: require_file_path_sanitization
  File('/data/\${build()}');
}
''');
    });
  });
}
