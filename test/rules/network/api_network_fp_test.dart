// Resolved-AST false-positive regression tests for three rules in
// lib/src/rules/network/api_network_rules.dart:
//   - require_api_error_mapping (dead-variable cleanup; detection unchanged)
//   - prefer_streaming_response (OOM concern is bodyBytes only; file proximity)
//   - avoid_over_fetching (guess heuristic firing on ordinary repository code)
//
// Each block first PINS the legitimate positive (rule still fires where it
// should), then asserts the false-positive shape is silent.
library;

import 'package:saropa_lints/src/rules/network/api_network_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

void main() {
  group('require_permission_status_check', () {
    final rule = RequirePermissionStatusCheckRule();

    // Positive: a real media recorder (receiver type resolves to a recognized
    // media source, name `audiorecorder`) with no preceding permission check
    // still fires after the receiver-type gate was added.
    test(
      'flags media recorder startRecording without a permission check',
      () async {
        const code = '''
class AudioRecorder {
  void startRecording() {}
}

class Caller {
  void f() {
    final recorder = AudioRecorder();
    recorder.startRecording();
  }
}
''';
        final codes = await reportedRuleCodes(rule, code);
        expect(codes, contains('require_permission_status_check'));
      },
    );

    // FP: an in-process query recorder shares the name `startRecording` but its
    // receiver type resolves to an app-domain type with no media/permission
    // package origin, so the name-only match must no longer fire.
    test('does not flag an app-domain QueryRecorder.startRecording', () async {
      const code = '''
class QueryRecorder {
  void startRecording() {}
}

class Caller {
  void f() {
    final recorder = QueryRecorder();
    recorder.startRecording();
  }
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, isNot(contains('require_permission_status_check')));
    });

    // FP: other gated names (startScan, getContacts) on an unrelated app-domain
    // object are the same name-collision class and must also stay silent.
    test(
      'does not flag gated names on an unrelated app-domain object',
      () async {
        const code = '''
class QueryRecorder {
  List<String> getContacts() => const [];
  void startScan() {}
}

class Caller {
  void f() {
    final recorder = QueryRecorder();
    recorder.getContacts();
    recorder.startScan();
  }
}
''';
        final codes = await reportedRuleCodes(rule, code);
        expect(codes, isNot(contains('require_permission_status_check')));
      },
    );
  });

  group('require_api_error_mapping', () {
    final rule = RequireApiErrorMappingRule();

    // Positive: http.* in a try with no specific catch still flags.
    test('flags http call with only a generic catch', () async {
      const code = '''
void f(dynamic http) {
  try {
    http.get('x');
  } catch (e) {
    print(e);
  }
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, contains('require_api_error_mapping'));
    });

    // Negative: a specific catch clause suppresses the lint (detection intact
    // after the dead-variable removal).
    test('does not flag http call with a specific catch', () async {
      const code = '''
class SocketException implements Exception {}

void f(dynamic http) {
  try {
    http.get('x');
  } on SocketException catch (e) {
    print(e);
  }
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, isNot(contains('require_api_error_mapping')));
    });
  });

  group('prefer_streaming_response', () {
    final rule = PreferStreamingResponseRule();

    // The rule listens on PropertyAccess nodes; `response.bodyBytes` where
    // `response` is a bare identifier is a PrefixedIdentifier, so a deeper
    // target (`client.response.bodyBytes`) is used to form a real
    // PropertyAccess that the visitor sees.

    // Positive: bodyBytes buffered then written to a file is the real OOM case.
    test('flags bodyBytes written to a file', () async {
      const code = '''
class Inner {
  List<int> get bodyBytes => const <int>[];
}

class Client {
  Inner get response => Inner();
}

Future<void> f(Client client, dynamic file) async {
  final bytes = client.response.bodyBytes;
  await file.writeAsBytes(bytes);
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, contains('prefer_streaming_response'));
    });

    // FP #1: `.body` is a String, not the OOM concern. Must stay silent even
    // with a file write adjacent.
    test('does not flag .body (String, not bytes)', () async {
      const code = '''
class Inner {
  String get body => '';
}

class Client {
  Inner get response => Inner();
}

Future<void> f(Client client, dynamic file) async {
  final text = client.response.body;
  await file.writeAsBytes(text);
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, isNot(contains('prefer_streaming_response')));
    });

    // FP #2: bodyBytes for an in-memory purpose, with an unrelated `file`
    // parameter many ancestors away, must not trip on distant proximity.
    test('does not flag bodyBytes when no file op is adjacent', () async {
      const code = '''
class Inner {
  List<int> get bodyBytes => const <int>[];
}

class Client {
  Inner get response => Inner();
}

int unrelated(Client client, dynamic file) {
  final length = client.response.bodyBytes.length;
  return length;
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, isNot(contains('prefer_streaming_response')));
    });
  });

  group('avoid_over_fetching', () {
    final rule = AvoidOverFetchingRule();

    // Positive: fetch a whole object, then feed exactly one of its fields into
    // a call (the documented over-fetch shape). Verifies the conservative
    // rewrite did not turn the rule into a no-op.
    test('flags fetched object whose single field feeds a call', () async {
      const code = '''
class Text {
  Text(String value);
}

class Widget {
  dynamic api;
  Future<Text> build(int id) async {
    final user = await api.getUser(id);
    return Text(user.name);
  }
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, contains('avoid_over_fetching'));
    });

    // FP: an ordinary short repository method that fetches and returns an id
    // has no over-fetching signal, yet the old heuristic fired.
    test('does not flag a short repo fetch returning an id', () async {
      const code = '''
class Repo {
  Future<int> userId(dynamic api, int id) async {
    final result = await api.fetch(id);
    return result.id;
  }
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, isNot(contains('avoid_over_fetching')));
    });

    // FP: fetch then return a single name field — same shape, also no signal.
    test('does not flag a short repo fetch returning a name', () async {
      const code = '''
class Repo {
  Future<String> userName(dynamic api, int id) async {
    final user = await api.fetch(id);
    return user.name;
  }
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, isNot(contains('avoid_over_fetching')));
    });
  });
}
