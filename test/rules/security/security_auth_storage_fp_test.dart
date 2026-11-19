// ignore_for_file: depend_on_referenced_packages
//
// Resolved-AST oracle tests for false-positive / false-negative fixes in
// security_auth_storage_rules.dart. Each group reproduces the audited bug,
// then pins the fixed behavior.
//
// Harness: example/lib/__rule_harness__ runs ONE rule with full resolution and
// returns the diagnostics it reports (rule code + line). No Flutter dependency
// is available, so fixtures use minimal LOCAL stubs for any non-core type.

import 'package:saropa_lints/src/rules/security/security_auth_storage_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

void main() {
  // --------------------------------------------------------------------------
  // require_token_refresh
  //
  // Audit: two `reporter.atToken(node.nameToken, code)` calls could BOTH fire
  // for one class (duplicate diagnostics), and the second (`hasAccessToken &&
  // !hasExpiryCheck`) fired for essentially every auth/session/token class that
  // stores an access token even when refresh logic is present.
  // --------------------------------------------------------------------------
  group('require_token_refresh', () {
    // Class name uses a whole-word `auth`/`session`/`token` match (the rule's
    // own gate). `Session` matches `\bsession\b`; `AuthService` would NOT (no
    // word boundary inside the identifier).
    test(
      'reports EXACTLY ONCE on an auth class with no refresh logic',
      () async {
        const code = '''
class Session {
  String? accessToken;
}
''';
        final diags = await runRuleResolved(RequireTokenRefreshRule(), code);
        final refresh = diags
            .where((d) => d.ruleName == 'require_token_refresh')
            .toList();
        expect(refresh, hasLength(1));
      },
    );

    test('does NOT report when refresh logic is present', () async {
      const code = '''
class Session {
  String? accessToken;
  String? refreshToken;
  DateTime? tokenExpiry;

  Future<void> refreshAccessToken() async {}

  Future<void> ensureFresh() async {
    if (tokenExpiry?.isBefore(DateTime.now()) ?? true) {
      await refreshAccessToken();
    }
  }
}
''';
      final codes = await reportedRuleCodes(RequireTokenRefreshRule(), code);
      expect(codes.contains('require_token_refresh'), isFalse);
    });

    test('does NOT report when a refresh method exists but no expiry check '
        '(the duplicate-branch false positive)', () async {
      const code = '''
class Session {
  String? accessToken;
  String? refreshToken;

  Future<void> refreshAccessToken() async {}
}
''';
      final codes = await reportedRuleCodes(RequireTokenRefreshRule(), code);
      expect(codes.contains('require_token_refresh'), isFalse);
    });
  });

  // --------------------------------------------------------------------------
  // avoid_jwt_decode_client
  //
  // Audit: the instance-creation branch reported on ANY constructor whose
  // lowercased type name matched `jwt`/`jsonwebtoken` (e.g. `JwtModel(...)`,
  // `JsonWebToken.fromMap(...)`) with NO authorization-context guard — unlike
  // the method branch, which requires a role/admin/permission/scope/claim
  // context.
  // --------------------------------------------------------------------------
  group('avoid_jwt_decode_client', () {
    // Type name `JsonWebToken` matches `\bjsonwebtoken\b`; the named
    // constructor `.fromMap` makes this an InstanceCreationExpression. With no
    // role/admin/permission/scope/claim context, it must NOT be flagged
    // (parity with the method branch).
    test(
      'does NOT report a JWT constructor with NO authorization context',
      () async {
        const code = '''
class JsonWebToken {
  JsonWebToken.fromMap(this.data);
  final Map<String, Object?> data;
}

void main() {
  final model = JsonWebToken.fromMap(<String, Object?>{});
  print(model.data);
}
''';
        final codes = await reportedRuleCodes(AvoidJwtDecodeClientRule(), code);
        expect(codes.contains('avoid_jwt_decode_client'), isFalse);
      },
    );

    test(
      'DOES report a JWT constructor used in an authorization decision',
      () async {
        // The construction is lexically inside the `if` condition, matching the
        // ancestor-walk auth-context guard (the same shape the method branch
        // requires). `if (claims.role ...)` with the construct in a sibling
        // statement is intentionally NOT flagged.
        const code = '''
class JsonWebToken {
  JsonWebToken.fromMap(this.role);
  final String role;
}

bool canAdmin() {
  if (JsonWebToken.fromMap('admin').role == 'admin') {
    return true;
  }
  return false;
}
''';
        final codes = await reportedRuleCodes(AvoidJwtDecodeClientRule(), code);
        expect(codes.contains('avoid_jwt_decode_client'), isTrue);
      },
    );

    test('STILL reports the method-call authorization case', () async {
      // Method name `decode` matches `\bdecode\b`; receiver `jwtToken` matches
      // `\btoken\b`; the enclosing `if` tests a role → authorization context.
      const code = '''
class Jwt {
  Map<String, dynamic> decode() => <String, dynamic>{};
}

void check(Jwt jwt) {
  if (jwt.decode()['role'] == 'admin') {
    print('admin');
  }
}
''';
      final codes = await reportedRuleCodes(AvoidJwtDecodeClientRule(), code);
      expect(codes.contains('avoid_jwt_decode_client'), isTrue);
    });
  });

  // --------------------------------------------------------------------------
  // require_biometric_fallback
  //
  // Audit: `_authBioTargetPatterns` required the receiver SOURCE to contain a
  // whole-word `auth`/`bio`, so the canonical local_auth call
  // `localAuth.authenticate(biometricOnly: true)` (receiver `localAuth` is one
  // token, no word boundary) was MISSED.
  // --------------------------------------------------------------------------
  group('require_biometric_fallback', () {
    test('DOES report local_auth localAuth.authenticate(biometricOnly: true) '
        '(the missed false-negative)', () async {
      const code = '''
class LocalAuthentication {
  Future<bool> authenticate({
    String localizedReason = '',
    bool biometricOnly = false,
  }) async => true;
}

Future<void> login() async {
  final localAuth = LocalAuthentication();
  await localAuth.authenticate(
    localizedReason: 'Scan',
    biometricOnly: true,
  );
}
''';
      final codes = await reportedRuleCodes(
        RequireBiometricFallbackRule(),
        code,
      );
      expect(codes.contains('require_biometric_fallback'), isTrue);
    });

    test('does NOT report when biometricOnly is false', () async {
      const code = '''
class LocalAuthentication {
  Future<bool> authenticate({
    String localizedReason = '',
    bool biometricOnly = false,
  }) async => true;
}

Future<void> login() async {
  final localAuth = LocalAuthentication();
  await localAuth.authenticate(
    localizedReason: 'Scan',
    biometricOnly: false,
  );
}
''';
      final codes = await reportedRuleCodes(
        RequireBiometricFallbackRule(),
        code,
      );
      expect(codes.contains('require_biometric_fallback'), isFalse);
    });

    test(
      'does NOT report an unrelated authenticate() on a non-auth receiver',
      () async {
        // A `Server.authenticate` that has nothing to do with biometrics and
        // no `biometricOnly` argument must stay silent.
        const code = '''
class Server {
  Future<bool> authenticate({bool biometricOnly = false}) async => true;
}

Future<void> connect() async {
  final server = Server();
  await server.authenticate();
}
''';
        final codes = await reportedRuleCodes(
          RequireBiometricFallbackRule(),
          code,
        );
        expect(codes.contains('require_biometric_fallback'), isFalse);
      },
    );
  });

  // --------------------------------------------------------------------------
  // require_data_encryption
  //
  // Audit: `_authKeywordPattern` matched the bare substring `auth` anywhere in
  // the argument-list source, so calls writing auth-**status**/configuration
  // metadata (`authStatusFields`, `authRequiredMessage`) — not credentials —
  // were flagged. The fix strips only the matched metadata identifier out of
  // the scanned text rather than skipping the whole call, so a metadata field
  // sitting alongside a real credential in the same call still triggers. See
  // bugs/require_data_encryption_false_positive_auth_status_metadata_keyword_match.md
  // (relocated to plans/history/2026.09/2026.09.18/ once resolved).
  // --------------------------------------------------------------------------
  group('require_data_encryption', () {
    test('does NOT report a spread auth-status/config metadata map', () async {
      const code = '''
import 'dart:convert';
import 'dart:io';

class ServerContext {
  Map<String, dynamic> get authStatusFields =>
      <String, dynamic>{'authRequired': false, 'authScheme': null};
}

class Handler {
  final ServerContext ctx = ServerContext();

  void sendHealth(HttpResponse res) {
    res.write(
      jsonEncode(<String, dynamic>{'ok': true, ...ctx.authStatusFields}),
    );
  }
}
''';
      final codes = await reportedRuleCodes(RequireDataEncryptionRule(), code);
      expect(codes.contains('require_data_encryption'), isFalse);
    });

    test(
      'does NOT report a static authRequiredMessage rejection string',
      () async {
        const code = '''
import 'dart:convert';
import 'dart:io';

class Handler {
  void sendUnauthorized(HttpResponse res) {
    const String authRequiredMessage = 'Authentication required';
    res.write(
      jsonEncode(<String, String>{'error': authRequiredMessage}),
    );
  }
}
''';
        final codes = await reportedRuleCodes(
          RequireDataEncryptionRule(),
          code,
        );
        expect(codes.contains('require_data_encryption'), isFalse);
      },
    );

    test(
      'STILL reports when a metadata field AND a real credential are in '
      'the SAME call (the metadata exclusion must not blanket-skip)',
      () async {
        const code = '''
import 'dart:convert';
import 'dart:io';

void sendHealth(HttpResponse res, String password) {
  res.write(
    jsonEncode(<String, dynamic>{'authScheme': 'basic', 'password': password}),
  );
}
''';
        final codes = await reportedRuleCodes(
          RequireDataEncryptionRule(),
          code,
        );
        expect(codes.contains('require_data_encryption'), isTrue);
      },
    );

    test(
      'STILL reports authRequired metadata alongside a real accessToken',
      () async {
        const code = '''
import 'dart:convert';
import 'dart:io';

void sendHealth(HttpResponse res, String accessToken) {
  res.write(
    jsonEncode(<String, dynamic>{
      'authRequired': true,
      'accessToken': accessToken,
    }),
  );
}
''';
        final codes = await reportedRuleCodes(
          RequireDataEncryptionRule(),
          code,
        );
        expect(codes.contains('require_data_encryption'), isTrue);
      },
    );

    test(
      'STILL reports a bare userAuthScheme identifier (the metadata patterns '
      "are anchored with \\b, so a prefixed identifier isn't recognized as "
      'safe metadata and falls through to the generic auth keyword check)',
      () async {
        const code = '''
void store(String userAuthScheme) {
  box.put('scheme', userAuthScheme);
}

dynamic box;
''';
        final codes = await reportedRuleCodes(
          RequireDataEncryptionRule(),
          code,
        );
        expect(codes.contains('require_data_encryption'), isTrue);
      },
    );
  });
}
