// Regression/behavior tests for mutable_tearoff.
//
// This exercises the rule class directly via the resolved-rule harness,
// which runs a single rule against inline source with full type/element
// resolution, independent of the rule's registration in
// lib/saropa_lints.dart / lib/src/tiers.dart (the rule IS registered in
// both — see plans/history/2026.09/2026.09.04/proposal_mutable_tearoff.md
// — but the harness lets these tests stay fast and self-contained).
library;

import 'package:saropa_lints/src/rules/code_quality/mutable_tearoff_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

void main() {
  group('mutable_tearoff', () {
    test('fires on a tear-off stored from a mutable instance field', () async {
      final codes = await reportedRuleCodes(MutableTearoffRule(), '''
typedef VoidCallback = void Function();

class Handler {
  void handleTap() {}
}

class Controller {
  Handler handler = Handler();
  late final VoidCallback onTap = handler.handleTap;
}
''');
      expect(codes, contains('mutable_tearoff'));
    });

    test(
      'fires on a tear-off assigned (not initialized) from a mutable field',
      () async {
        final codes = await reportedRuleCodes(MutableTearoffRule(), '''
typedef VoidCallback = void Function();

class Handler {
  void handleTap() {}
}

class Controller {
  Handler handler = Handler();
  VoidCallback? cached;

  void bind() {
    cached = handler.handleTap;
  }
}
''');
        expect(codes, contains('mutable_tearoff'));
      },
    );

    test('fires on a tear-off stored from a mutable local variable', () async {
      final codes = await reportedRuleCodes(MutableTearoffRule(), '''
typedef VoidCallback = void Function();

class Handler {
  void handleTap() {}
}

void run() {
  Handler handler = Handler();
  final VoidCallback callback = handler.handleTap;
  callback();
}
''');
      expect(codes, contains('mutable_tearoff'));
    });

    test('fires on a tear-off stored from a non-final parameter', () async {
      final codes = await reportedRuleCodes(MutableTearoffRule(), '''
typedef VoidCallback = void Function();

class Handler {
  void handleTap() {}
}

void run(Handler handler) {
  final VoidCallback cb = handler.handleTap;
  cb();
}
''');
      expect(codes, contains('mutable_tearoff'));
    });

    test('does NOT fire when the receiver field is final', () async {
      final codes = await reportedRuleCodes(MutableTearoffRule(), '''
typedef VoidCallback = void Function();

class Handler {
  void handleTap() {}
}

class Controller {
  final Handler handler = Handler();
  late final VoidCallback onTap = handler.handleTap;
}
''');
      expect(codes, isEmpty);
    });

    test('does NOT fire when the receiver parameter is final', () async {
      final codes = await reportedRuleCodes(MutableTearoffRule(), '''
typedef VoidCallback = void Function();

class Handler {
  void handleTap() {}
}

void run(final Handler handler) {
  final VoidCallback cb = handler.handleTap;
  cb();
}
''');
      expect(codes, isEmpty);
    });

    test('does NOT fire on this.method — this can never be reassigned even '
        'though the class has mutable fields', () async {
      final codes = await reportedRuleCodes(MutableTearoffRule(), '''
typedef VoidCallback = void Function();

class Controller {
  int counter = 0;

  void bump() {
    counter++;
  }

  late final VoidCallback onBump = this.bump;
}
''');
      expect(codes, isEmpty);
    });

    test(
      'does NOT fire when the tear-off is immediately invoked, not stored',
      () async {
        final codes = await reportedRuleCodes(MutableTearoffRule(), '''
class Handler {
  void handleTap() {}
}

void run() {
  Handler handler = Handler();
  handler.handleTap();
}
''');
        expect(codes, isEmpty);
      },
    );

    test('does NOT fire when the tear-off is passed as a one-shot argument, '
        'never retained past the call', () async {
      final codes = await reportedRuleCodes(MutableTearoffRule(), '''
typedef VoidCallback = void Function();

class Handler {
  void handleTap() {}
}

void run(List<VoidCallback> sink) {
  Handler handler = Handler();
  sink.add(handler.handleTap);
}
''');
      expect(codes, isEmpty);
    });

    test('does NOT fire on a field read (not a method tear-off), even from a '
        'mutable receiver', () async {
      final codes = await reportedRuleCodes(MutableTearoffRule(), '''
typedef VoidCallback = void Function();

class Handler {
  VoidCallback onTapField = () {};
}

void run(Handler handler) {
  final VoidCallback cb = handler.onTapField;
  cb();
}
''');
      expect(codes, isEmpty);
    });

    test(
      'does NOT fire on a plain sync call with no tear-off (control)',
      () async {
        final codes = await reportedRuleCodes(MutableTearoffRule(), '''
class Handler {
  void handleTap() {}
}

void run() {
  final handler = Handler();
  handler.handleTap();
}
''');
        expect(codes, isEmpty);
      },
    );

    test(
      'fires on a tear-off stored as an element of a list literal',
      () async {
        final codes = await reportedRuleCodes(MutableTearoffRule(), '''
typedef VoidCallback = void Function();

class Handler {
  void handleTap() {}
}

void run(Handler handler) {
  final List<VoidCallback> callbacks = [handler.handleTap];
  callbacks.first();
}
''');
        expect(codes, contains('mutable_tearoff'));
      },
    );

    test(
      'fires on a tear-off stored as the value of a map literal entry',
      () async {
        final codes = await reportedRuleCodes(MutableTearoffRule(), '''
typedef VoidCallback = void Function();

class Handler {
  void handleTap() {}
}

void run(Handler handler) {
  final Map<String, VoidCallback> callbacks = {'tap': handler.handleTap};
  callbacks['tap']!();
}
''');
        expect(codes, contains('mutable_tearoff'));
      },
    );

    test('fires on a tear-off stored as a positional record field', () async {
      final codes = await reportedRuleCodes(MutableTearoffRule(), '''
typedef VoidCallback = void Function();

class Handler {
  void handleTap() {}
}

void run(Handler handler) {
  final (VoidCallback,) record = (handler.handleTap,);
  record.\$1();
}
''');
      expect(codes, contains('mutable_tearoff'));
    });

    test('fires on a tear-off returned via a return statement', () async {
      final codes = await reportedRuleCodes(MutableTearoffRule(), '''
typedef VoidCallback = void Function();

class Handler {
  void handleTap() {}
}

VoidCallback getCallback(Handler handler) {
  return handler.handleTap;
}
''');
      expect(codes, contains('mutable_tearoff'));
    });

    test('fires on a tear-off returned via an arrow-bodied function', () async {
      final codes = await reportedRuleCodes(MutableTearoffRule(), '''
typedef VoidCallback = void Function();

class Handler {
  void handleTap() {}
}

VoidCallback getCallback(Handler handler) => handler.handleTap;
''');
      expect(codes, contains('mutable_tearoff'));
    });

    test('fires on a tear-off stored via a constructor initializer-list '
        'assignment', () async {
      final codes = await reportedRuleCodes(MutableTearoffRule(), '''
typedef VoidCallback = void Function();

class Handler {
  void handleTap() {}
}

class Controller {
  final VoidCallback onTap;

  Controller(Handler handlerParam) : onTap = handlerParam.handleTap;
}
''');
      expect(codes, contains('mutable_tearoff'));
    });

    test(
      'fires on a tear-off stored via a compound (??=) assignment',
      () async {
        final codes = await reportedRuleCodes(MutableTearoffRule(), '''
typedef VoidCallback = void Function();

class Handler {
  void handleTap() {}
}

class Controller {
  Handler handler = Handler();
  VoidCallback? cached;

  void bind() {
    cached ??= handler.handleTap;
  }
}
''');
        expect(codes, contains('mutable_tearoff'));
      },
    );

    test('fires on a tear-off stored from a mutable top-level variable '
        'receiver', () async {
      final codes = await reportedRuleCodes(MutableTearoffRule(), '''
typedef VoidCallback = void Function();

class Handler {
  void handleTap() {}
}

Handler handler = Handler();

void run() {
  final VoidCallback callback = handler.handleTap;
  callback();
}
''');
      expect(codes, contains('mutable_tearoff'));
    });

    test('fires on a tear-off stored from a mutable static field receiver '
        '(unqualified reference — a class-qualified `Registry.handler.method` '
        'reference is a 3-identifier chain, out of scope per the rule\'s '
        'documented chained-receiver limitation)', () async {
      final codes = await reportedRuleCodes(MutableTearoffRule(), '''
typedef VoidCallback = void Function();

class Handler {
  void handleTap() {}
}

class Registry {
  static Handler handler = Handler();

  static VoidCallback run() {
    final VoidCallback callback = handler.handleTap;
    return callback;
  }
}
''');
      expect(codes, contains('mutable_tearoff'));
    });

    test(
      'fires on a tear-off of an extension method from a mutable receiver',
      () async {
        final codes = await reportedRuleCodes(MutableTearoffRule(), '''
typedef VoidCallback = void Function();

class Handler {}

extension HandlerExtension on Handler {
  void handleTap() {}
}

void run() {
  Handler handler = Handler();
  final VoidCallback callback = handler.handleTap;
  callback();
}
''');
        expect(codes, contains('mutable_tearoff'));
      },
    );

    test('does NOT fire on an import-prefixed call, and does not crash '
        'resolving the prefix as a receiver', () async {
      final codes = await reportedRuleCodes(MutableTearoffRule(), '''
import 'dart:math' as math;

void run() {
  final int result = math.min(1, 2);
  result.toString();
}
''');
      expect(codes, isEmpty);
    });

    test('does NOT fire on a tear-off passed as a named argument to a '
        'one-shot call, even though it resembles a record field', () async {
      final codes = await reportedRuleCodes(MutableTearoffRule(), '''
typedef VoidCallback = void Function();

class Handler {
  void handleTap() {}
}

void register({required VoidCallback onTap}) {
  onTap();
}

void run(Handler handler) {
  register(onTap: handler.handleTap);
}
''');
      expect(codes, isEmpty);
    });
  });
}
