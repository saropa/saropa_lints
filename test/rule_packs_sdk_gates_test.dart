import 'package:saropa_lints/src/config/rule_packs.dart';
import 'package:test/test.dart';

void main() {
  group('packPassesSdkGate', () {
    test('dart_sdk_3_2 passes when sdk lower bound is >= 3.2.0', () {
      const pubspec = '''
name: demo
environment:
  sdk: ">=3.2.0 <4.0.0"
''';
      expect(packPassesSdkGate('dart_sdk_3_2', pubspec), isTrue);
    });

    test('dart_sdk_3_2 fails when sdk lower bound is below 3.2.0', () {
      const pubspec = '''
name: demo
environment:
  sdk: ">=3.1.0 <4.0.0"
''';
      expect(packPassesSdkGate('dart_sdk_3_2', pubspec), isFalse);
    });

    test('dart_sdk_3_4 passes when sdk lower bound is >= 3.4.0', () {
      const pubspec = '''
name: demo
environment:
  sdk: ">=3.4.0 <4.0.0"
''';
      expect(packPassesSdkGate('dart_sdk_3_4', pubspec), isTrue);
    });

    test('flutter_sdk_3_7 passes when flutter lower bound is >= 3.7.0', () {
      const pubspec = '''
name: demo
environment:
  flutter: ">=3.7.0"
''';
      expect(packPassesSdkGate('flutter_sdk_3_7', pubspec), isTrue);
    });

    test('flutter_sdk_3_10 fails when flutter lower bound is below 3.10.0', () {
      const pubspec = '''
name: demo
environment:
  flutter: ">=3.7.0"
''';
      expect(packPassesSdkGate('flutter_sdk_3_10', pubspec), isFalse);
    });

    test('flutter_sdk_3_16 passes when flutter lower bound is >= 3.16.0', () {
      const pubspec = '''
name: demo
environment:
  flutter: ">=3.16.0"
''';
      expect(packPassesSdkGate('flutter_sdk_3_16', pubspec), isTrue);
    });

    test('flutter_sdk_3_24 passes when flutter lower bound is >= 3.24.0', () {
      const pubspec = '''
name: demo
environment:
  flutter: ">=3.24.0"
''';
      expect(packPassesSdkGate('flutter_sdk_3_24', pubspec), isTrue);
    });

    test('flutter_sdk_3_29 passes when flutter lower bound is >= 3.29.0', () {
      const pubspec = '''
name: demo
environment:
  flutter: ">=3.29.0"
''';
      expect(packPassesSdkGate('flutter_sdk_3_29', pubspec), isTrue);
    });

    test('flutter_sdk_3_32 passes when flutter lower bound is >= 3.32.0', () {
      const pubspec = '''
name: demo
environment:
  flutter: ">=3.32.0"
''';
      expect(packPassesSdkGate('flutter_sdk_3_32', pubspec), isTrue);
    });

    test('flutter_sdk_3_38 passes when flutter lower bound is >= 3.38.0', () {
      const pubspec = '''
name: demo
environment:
  flutter: ">=3.38.0"
''';
      expect(packPassesSdkGate('flutter_sdk_3_38', pubspec), isTrue);
    });

    test('flutter_sdk_3_0 passes on modern flutter constraints', () {
      const pubspec = '''
name: demo
environment:
  flutter: ">=3.7.0"
''';
      expect(packPassesSdkGate('flutter_sdk_3_0', pubspec), isTrue);
    });
  });

  group('isRulePackApplicable with SDK packs', () {
    test('sdk packs can be applicable without dependency markers', () {
      const pubspec = '''
name: demo
environment:
  sdk: ">=3.2.0 <4.0.0"
  flutter: ">=3.7.0"
''';
      expect(isRulePackApplicable('dart_sdk_3_2', pubspec, null), isTrue);
      expect(isRulePackApplicable('dart_sdk_3_4', pubspec, null), isFalse);
      expect(isRulePackApplicable('flutter_sdk_3_0', pubspec, null), isTrue);
      expect(isRulePackApplicable('flutter_sdk_3_7', pubspec, null), isTrue);
      expect(isRulePackApplicable('flutter_sdk_3_10', pubspec, null), isFalse);
      expect(isRulePackApplicable('flutter_sdk_3_16', pubspec, null), isFalse);
      expect(isRulePackApplicable('flutter_sdk_3_19', pubspec, null), isFalse);
      expect(isRulePackApplicable('flutter_sdk_3_22', pubspec, null), isFalse);
      expect(isRulePackApplicable('flutter_sdk_3_24', pubspec, null), isFalse);
      expect(isRulePackApplicable('flutter_sdk_3_28', pubspec, null), isFalse);
      expect(isRulePackApplicable('flutter_sdk_3_29', pubspec, null), isFalse);
      expect(isRulePackApplicable('flutter_sdk_3_32', pubspec, null), isFalse);
      expect(isRulePackApplicable('flutter_sdk_3_35', pubspec, null), isFalse);
      expect(isRulePackApplicable('flutter_sdk_3_38', pubspec, null), isFalse);
    });

    test('higher flutter constraints enable higher sdk packs', () {
      const pubspec = '''
name: demo
environment:
  sdk: ">=3.2.0 <4.0.0"
  flutter: ">=3.24.0"
''';
      expect(isRulePackApplicable('flutter_sdk_3_10', pubspec, null), isTrue);
      expect(isRulePackApplicable('flutter_sdk_3_16', pubspec, null), isTrue);
      expect(isRulePackApplicable('flutter_sdk_3_18', pubspec, null), isTrue);
      expect(isRulePackApplicable('flutter_sdk_3_19', pubspec, null), isTrue);
      expect(isRulePackApplicable('flutter_sdk_3_22', pubspec, null), isTrue);
      expect(isRulePackApplicable('flutter_sdk_3_24', pubspec, null), isTrue);
      expect(isRulePackApplicable('flutter_sdk_3_28', pubspec, null), isFalse);
      expect(isRulePackApplicable('flutter_sdk_3_29', pubspec, null), isFalse);
      expect(isRulePackApplicable('flutter_sdk_3_32', pubspec, null), isFalse);
      expect(isRulePackApplicable('flutter_sdk_3_35', pubspec, null), isFalse);
      expect(isRulePackApplicable('flutter_sdk_3_38', pubspec, null), isFalse);
    });

    test('latest flutter constraints enable flutter_sdk_3_29', () {
      const pubspec = '''
name: demo
environment:
  flutter: ">=3.29.0"
''';
      expect(isRulePackApplicable('flutter_sdk_3_29', pubspec, null), isTrue);
      expect(isRulePackApplicable('flutter_sdk_3_32', pubspec, null), isFalse);
      expect(isRulePackApplicable('flutter_sdk_3_35', pubspec, null), isFalse);
      expect(isRulePackApplicable('flutter_sdk_3_38', pubspec, null), isFalse);
    });

    test('flutter 3.32 constraints enable flutter_sdk_3_32', () {
      const pubspec = '''
name: demo
environment:
  flutter: ">=3.32.0"
''';
      expect(isRulePackApplicable('flutter_sdk_3_32', pubspec, null), isTrue);
      expect(isRulePackApplicable('flutter_sdk_3_35', pubspec, null), isFalse);
      expect(isRulePackApplicable('flutter_sdk_3_38', pubspec, null), isFalse);
    });

    test('flutter 3.38 constraints enable newest sdk packs', () {
      const pubspec = '''
name: demo
environment:
  flutter: ">=3.38.0"
''';
      expect(isRulePackApplicable('flutter_sdk_3_35', pubspec, null), isTrue);
      expect(isRulePackApplicable('flutter_sdk_3_38', pubspec, null), isTrue);
    });
  });
}
