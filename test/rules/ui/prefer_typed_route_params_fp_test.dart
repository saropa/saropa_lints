// Regression test for a prefer_typed_route_params false positive, verified
// against resolved source via the oracle harness:
//
// The rule's "already parsed" exclusion matched a grandparent
// MethodInvocation's method name against RegExp(r'\bparse\b') — a whole-word
// match. A same-file wrapper like `ServerUtils.parseLimit(...)` (which
// internally calls int.tryParse and clamps the range) has no word boundary
// between "parse" and "Limit", so the regex never matched and the rule
// flagged an already-parsed value.
//
// An initial fix loosened the pattern to the unanchored `pars(e|ing)`, which
// over-matched: `sparseView(...)` and `openParserScreen(...)` both contain
// "parse"/"Parse" as a run of letters (sPARSEView, openPARSERScreen) despite
// doing no parsing at all, so the loosened regex silently swallowed those
// real positives. The actual fix instead prefers a resolved check: a value
// is treated as already converted when the wrapping call's resolved return
// type is one of the numeric "parsed" types (int/double/num) — not merely
// "not String" and not based on the method's name.
//
// A follow-up review caught that including `bool` in that return-type check
// was itself an over-match: bool-returning methods are commonly *sinks*
// that don't convert anything (`Set.add`, `Set.contains`, a user-defined
// `bool save(String? id)`), so treating any bool-returning wrapper as
// "already parsed" silently swallowed those too. `bool` was removed from
// the return-type check; `bool.parse`/`bool.tryParse` are instead matched
// specifically by their resolved dart:core `bool` receiver. The dead
// `correspondingParameter` type check (which could never fire — passing a
// String argument to a non-String/non-dynamic parameter doesn't compile)
// was also removed. The name-based regex is anchored (matches
// `parse`/`tryParse` only at the start of the identifier or the start of an
// UpperCase camelCase word, never mid-word after a lowercase letter) and is
// used only as a last-resort fallback when the wrapping call's return type
// doesn't resolve to anything useful (null, InvalidType, or dynamic).
library;

import 'package:saropa_lints/src/rules/ui/navigation_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

void main() {
  group('prefer_typed_route_params', () {
    test(
      'does NOT flag a queryParameters value piped through a parseXxx wrapper',
      () async {
        final codes = await reportedRuleCodes(PreferTypedRouteParamsRule(), '''
import 'dart:io';

abstract final class ServerUtils {
  static int parseLimit(String? value) {
    if (value == null) return 100;
    final int? n = int.tryParse(value);
    if (n == null || n < 1) return 100;
    return n > 1000 ? 1000 : n;
  }
}

void handle(HttpRequest request) {
  final int limit = ServerUtils.parseLimit(
    request.uri.queryParameters['limit'],
  );
}
''');
        expect(codes, isNot(contains('prefer_typed_route_params')));
      },
    );

    test(
      'still flags a route parameter passed directly with no parse wrapper',
      () async {
        final codes = await reportedRuleCodes(PreferTypedRouteParamsRule(), '''
import 'dart:io';

void handle(HttpRequest request) {
  greet(request.uri.queryParameters['name']);
}

void greet(Object? name) {}
''');
        expect(codes, contains('prefer_typed_route_params'));
      },
    );

    test('still flags a name that merely CONTAINS "parse" (sparseView) — no '
        'actual conversion happens', () async {
      final codes = await reportedRuleCodes(PreferTypedRouteParamsRule(), '''
import 'dart:io';

void handle(HttpRequest request) {
  sparseView(request.uri.queryParameters['id']);
}

void sparseView(String? id) {}
''');
      expect(codes, contains('prefer_typed_route_params'));
    });

    test('still flags a name that merely CONTAINS "Parser" (openParserScreen) '
        '— no actual conversion happens', () async {
      final codes = await reportedRuleCodes(PreferTypedRouteParamsRule(), '''
import 'dart:io';

void handle(HttpRequest request) {
  openParserScreen(request.uri.queryParameters['id']);
}

void openParserScreen(String? id) {}
''');
      expect(codes, contains('prefer_typed_route_params'));
    });

    test('still flags a bool-returning Set.add sink (bool return type is not '
        'proof of parsing)', () async {
      final codes = await reportedRuleCodes(PreferTypedRouteParamsRule(), '''
import 'dart:io';

void handle(HttpRequest request) {
  final Set<String?> s = <String?>{};
  s.add(request.uri.queryParameters['id']);
}
''');
      expect(codes, contains('prefer_typed_route_params'));
    });

    test('still flags a bool-returning Set.contains sink (bool return type is '
        'not proof of parsing)', () async {
      final codes = await reportedRuleCodes(PreferTypedRouteParamsRule(), '''
import 'dart:io';

void handle(HttpRequest request) {
  final Set<String?> s = <String?>{};
  s.contains(request.uri.queryParameters['id']);
}
''');
      expect(codes, contains('prefer_typed_route_params'));
    });

    test(
      'still flags a user-defined bool-returning wrapper (bool save(String?))',
      () async {
        final codes = await reportedRuleCodes(PreferTypedRouteParamsRule(), '''
import 'dart:io';

bool save(String? id) => id != null;

void handle(HttpRequest request) {
  save(request.uri.queryParameters['id']);
}
''');
        expect(codes, contains('prefer_typed_route_params'));
      },
    );
  });
}
