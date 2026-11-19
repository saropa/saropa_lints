import 'package:saropa_lints/src/rules/hardware/bluetooth_hardware_rules.dart';
import 'package:saropa_lints/src/rules/packages/drift_rules.dart';
import 'package:saropa_lints/src/rules/packages/sign_in_with_apple_rules.dart';
import 'package:saropa_lints/src/rules/packages/speech_to_text_rules.dart';
import 'package:saropa_lints/src/rules/security/security_auth_storage_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

/// Regression coverage for the false-positive reports:
/// require_apple_signin_nonce (revocation code), require_drift_equals_value
/// (static const String), require_qr_permission_check (MobileScanner),
/// require_speech_stop_on_dispose (private helper), require_data_encryption
/// (clearing credentials with null).
void main() {
  group('require_apple_signin_nonce', () {
    const String stub = '''
class SignInWithApple {
  static Future<Object> getAppleIDCredential({
    List<Object>? scopes, String? nonce}) async => Object();
}
''';
    test('empty scopes (revocation code) is not reported', () async {
      final d = await runRuleResolved(RequireAppleSigninNonceRule(), '''
$stub
Future<void> f() async {
  await SignInWithApple.getAppleIDCredential(scopes: const <Object>[]);
}
''');
      expect(d, isEmpty);
    });
    test('non-empty scopes without nonce is still reported', () async {
      final d = await runRuleResolved(RequireAppleSigninNonceRule(), '''
$stub
Future<void> f(Object email) async {
  await SignInWithApple.getAppleIDCredential(scopes: [email]);
}
''');
      expect(d, hasLength(1));
    });
  });

  group('require_drift_equals_value', () {
    const String head = '''
import 'package:drift/drift.dart';
class Col { Object equals(Object v) => v; }
enum Status { active }
abstract final class Holder {
  static const String name = 'x';
  static const int count = 1;
}
''';
    test('static const String/int is not reported', () async {
      final d = await runRuleResolved(RequireDriftEqualsValueRule(), '''
$head
void f(Col c) {
  c.equals(Holder.name);
  c.equals(Holder.count);
}
''');
      expect(d, isEmpty);
    });
    test('enum argument is still reported', () async {
      final d = await runRuleResolved(RequireDriftEqualsValueRule(), '''
$head
void f(Col c) {
  c.equals(Status.active);
}
''');
      expect(d, hasLength(1));
    });
  });

  group('require_qr_permission_check', () {
    test('MobileScanner is not reported; QRView still is', () async {
      final d = await runRuleResolved(RequireQrPermissionCheckRule(), '''
class MobileScanner { MobileScanner({Object? controller}); }
class QRView { QRView(); }
Object a() => MobileScanner();
Object b() => QRView();
''');
      expect(d, hasLength(1));
    });
  });

  group('require_speech_stop_on_dispose', () {
    const String head = '''
class State<T> { void dispose() {} }
class SpeechToText { Future<void> cancel() async {} Future<void> stop() async {} }
''';
    test('cancel through same-class helper is not reported', () async {
      final d = await runRuleResolved(RequireSpeechStopOnDisposeRule(), '''
$head
class S extends State<Object> {
  final SpeechToText _speech = SpeechToText();
  @override
  void dispose() { _cancelEngine(); super.dispose(); }
  Future<void> _cancelEngine() async { await _speech.cancel(); }
}
''');
      expect(d, isEmpty);
    });
    test('private helper declared outside the class is trusted', () async {
      final d = await runRuleResolved(RequireSpeechStopOnDisposeRule(), '''
$head
class S extends State<Object> {
  final SpeechToText _speech = SpeechToText();
  @override
  void dispose() { _cancelEngine(); super.dispose(); }
}
extension on S {
  Future<void> _cancelEngine() async { await _speech.cancel(); }
}
''');
      expect(d, isEmpty);
    });
    test('helper that does not stop/cancel is still reported', () async {
      final d = await runRuleResolved(RequireSpeechStopOnDisposeRule(), '''
$head
class S extends State<Object> {
  final SpeechToText _speech = SpeechToText();
  @override
  void dispose() { _noop(); super.dispose(); }
  void _noop() {}
}
''');
      expect(d, hasLength(1));
    });
    test('no dispose at all is still reported', () async {
      final d = await runRuleResolved(RequireSpeechStopOnDisposeRule(), '''
$head
class S extends State<Object> {
  final SpeechToText _speech = SpeechToText();
}
''');
      expect(d, hasLength(1));
    });
  });

  group('require_data_encryption', () {
    const String head = '''
class Value<T> { const Value(this.v); final T v; }
class AuthCompanion {
  const AuthCompanion({this.token, this.password});
  final Value<String?>? token;
  final Value<String?>? password;
}
class Updater { Future<int> write(Object o) async => 1; }
''';
    test('clearing credentials with Value(null) is not reported', () async {
      final d = await runRuleResolved(RequireDataEncryptionRule(), '''
$head
Future<void> f(Updater u) async {
  await u.write(const AuthCompanion(token: Value<String?>(null)));
}
''');
      expect(d, isEmpty);
    });
    test('storing a real credential is still reported', () async {
      final d = await runRuleResolved(RequireDataEncryptionRule(), '''
$head
Future<void> f(Updater u, String t) async {
  await u.write(AuthCompanion(token: Value<String?>(t)));
}
''');
      expect(d, hasLength(1));
    });
    test('null token beside a real password is still reported', () async {
      final d = await runRuleResolved(RequireDataEncryptionRule(), '''
$head
Future<void> f(Updater u, String p) async {
  await u.write(AuthCompanion(token: Value<String?>(null), password: Value<String?>(p)));
}
''');
      expect(d, hasLength(1));
    });
  });
}
