import 'package:saropa_lints/src/rules/network/api_network_rules.dart';
import 'package:test/test.dart';
import '../../support/syntactic_rule_harness.dart';

/// Regression coverage for a private send helper that returns the HTTP
/// response unread
/// (plans/history/2026.11/2026.11.26/require_http_status_check_false_positive_response_returned_to_caller.md).
///
/// The rule is syntactic (`usesTypeResolution => false`), so the syntactic
/// harness is the pass that matches both the IDE and `scan` behavior.
void main() {
  // The rule only runs in files importing an HTTP client; the import text is
  // enough, the package does not need to resolve.
  const String header = "import 'package:http/http.dart' as http;\n";

  /// 1-based lines reported for [body] (line 1 is the import header).
  List<int> reportedLines(String body) {
    return runRuleSyntactic(
      RequireHttpStatusCheckRule(),
      '$header$body',
    ).map((d) => d.line).toList();
  }

  group('RequireHttpStatusCheckRule - pass-through send helpers', () {
    test('private helper returning the response; caller checks status', () {
      expect(
        reportedLines('''
class Api {
  /// Sends; [create] checks the status.
  Future<http.Response> _send(http.Client client, Uri uri) async {
    return await client.post(uri);
  }

  Future<String?> create(http.Client client, Uri uri) async {
    final http.Response response = await _send(client, uri);
    if (response.statusCode != 200) return null;
    return response.body;
  }
}
'''),
        isEmpty,
      );
    });

    test('expression-bodied helper chained through a second helper', () {
      expect(
        reportedLines('''
class Api {
  Future<http.Response> _post(http.Client client, Uri uri) =>
      client.post(uri);

  Future<http.Response> _send(http.Client client, Uri uri) =>
      _post(client, uri);

  Future<String?> create(http.Client client, Uri uri) async {
    final response = await _send(client, uri);
    if (response.statusCode != 200) return null;
    return response.body;
  }
}
'''),
        isEmpty,
      );
    });

    test('obligation moves to the caller: caller without status check', () {
      // The helper is exempt, but the caller reading the body unchecked is
      // reported — the violation is not lost, it is relocated.
      expect(
        reportedLines('''
class Api {
  Future<http.Response> _send(http.Client client, Uri uri) async {
    return await client.post(uri);
  }

  Future<String> create(http.Client client, Uri uri) async {
    final response = await _send(client, uri);
    return response.body;
  }
}
'''),
        <int>[7],
      );
    });

    test('still reports: body decoded with no status check', () {
      expect(
        reportedLines('''
class Api {
  Future<dynamic> load(Uri uri) async {
    final response = await http.get(uri);
    return jsonDecode(response.body);
  }
}
'''),
        <int>[3],
      );
    });

    test('still reports: public helper (callers may be in other files)', () {
      expect(
        reportedLines('''
class Api {
  Future<http.Response> send(http.Client client, Uri uri) async {
    return await client.post(uri);
  }
}
'''),
        <int>[3],
      );
    });

    test('still reports: response read inside the helper', () {
      expect(
        reportedLines('''
class Api {
  Future<String> _send(http.Client client, Uri uri) async {
    return (await client.post(uri)).body;
  }

  Future<String> create(http.Client client, Uri uri) async {
    final String text = await _send(client, uri);
    return text;
  }
}
'''),
        <int>[3],
      );
    });

    test('still reports: helper torn off (escapes the caller check)', () {
      expect(
        reportedLines('''
class Api {
  Future<http.Response> _send(http.Client client, Uri uri) async {
    return await client.post(uri);
  }

  void register(void Function(Object) sink) {
    sink(_send);
  }
}
'''),
        <int>[3],
      );
    });

    test('still reports: helper called from a constructor', () {
      expect(
        reportedLines('''
class Api {
  Api(http.Client client, Uri uri) {
    _send(client, uri);
  }

  Future<http.Response> _send(http.Client client, Uri uri) async {
    return await client.post(uri);
  }
}
'''),
        <int>[7],
      );
    });

    test('still reports: helper in a part file (unseen callers)', () {
      // Another file of the same library can call `_send` and read the body.
      expect(
        reportedLines('''
part of 'api.dart';
class Api {
  Future<http.Response> _send(http.Client client, Uri uri) async {
    return await client.post(uri);
  }

  Future<String?> create(http.Client client, Uri uri) async {
    final response = await _send(client, uri);
    if (response.statusCode != 200) return null;
    return response.body;
  }
}
'''),
        <int>[4],
      );
    });

    // Name-matching soundness: every case below shares the helper's name
    // across classes, a hierarchy, a mixin or an extension. Matching by name
    // is a superset of the real call graph, so each one must either withhold
    // the exemption or move the report onto the unchecked caller. None may
    // leave an unchecked body read unreported.
    test('same name in another class that reads the body', () {
      expect(
        reportedLines('''
class Api {
  Future<http.Response> _send(http.Client client, Uri uri) =>
      client.post(uri);
}

class Other {
  Future<String> _send(http.Client client, Uri uri) async {
    final response = await client.post(uri);
    return response.body;
  }
}
'''),
        <int>[3, 8],
      );
    });

    test('same-file subclass override that reads the body', () {
      expect(
        reportedLines('''
class Api {
  Future<http.Response> _send(http.Client client, Uri uri) =>
      client.post(uri);
}

class LoggingApi extends Api {
  @override
  Future<http.Response> _send(http.Client client, Uri uri) async {
    final response = await client.post(uri);
    print(response.body);
    return response;
  }
}
'''),
        <int>[3, 9],
      );
    });

    test('mixin helper: unchecked caller in the mixing class', () {
      expect(
        reportedLines('''
mixin Sender {
  Future<http.Response> _send(http.Client client, Uri uri) =>
      client.post(uri);
}

class Api with Sender {
  Future<String> create(http.Client client, Uri uri) async {
    final response = await _send(client, uri);
    return response.body;
  }
}
'''),
        <int>[8],
      );
    });

    test('extension helper: unchecked caller through the extension', () {
      expect(
        reportedLines('''
extension on http.Client {
  Future<http.Response> _send(Uri uri) => this.post(uri);
  Future<http.Response> _sendVia(http.Client client, Uri uri) =>
      client.post(uri);
}

class Api {
  Future<String> create(http.Client client, Uri uri) async {
    final response = await client._sendVia(client, uri);
    return response.body;
  }
}
'''),
        <int>[9],
      );
    });

    test('interface member of the same name withholds the exemption', () {
      // `Base._send` has no body to prove pass-through, so the name is not
      // exempt and the implementation is reported on its own.
      expect(
        reportedLines('''
abstract class Base {
  Future<http.Response> _send(http.Client client, Uri uri);
}

class Impl implements Base {
  @override
  Future<http.Response> _send(http.Client client, Uri uri) =>
      client.post(uri);
}
'''),
        <int>[8],
      );
    });

    test('same-named local function is not mistaken for the helper', () {
      // A local `_send` shadows the name in `other`; treating its call as an
      // HTTP call would be a false positive there. The name collision
      // withholds the exemption instead, so only the helper is reported.
      expect(
        reportedLines('''
class Api {
  Future<http.Response> _send(http.Client client, Uri uri) async {
    return await client.post(uri);
  }

  Future<String?> create(http.Client client, Uri uri) async {
    final response = await _send(client, uri);
    if (response.statusCode != 200) return null;
    return response.body;
  }

  void other() {
    void _send() {}
    _send();
  }
}
'''),
        <int>[3],
      );
    });
  });
}
