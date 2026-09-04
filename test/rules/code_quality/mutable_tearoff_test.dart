// Regression/behavior tests for mutable_tearoff.
//
// The rule is not yet wired into the global tier registry (a separate
// process handles the three-way registration centrally to avoid merge
// conflicts across parallel rule-authoring agents). This test therefore
// exercises the rule class directly via the resolved-rule harness, which
// runs a single rule against inline source without depending on
// lib/saropa_lints.dart or lib/src/tiers.dart.
library;

import 'package:saropa_lints/src/rules/code_quality/mutable_tearoff_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

void main() {
  group('mutable_tearoff', () {
    test('fires on a tear-off stored from a mutable instance field', () async {
      final codes = await reportedRuleCodes(
        MutableTearoffRule(),
        '''
typedef VoidCallback = void Function();

class Handler {
  void handleTap() {}
}

class Controller {
  Handler handler = Handler();
  late final VoidCallback onTap = handler.handleTap;
}
''',
      );
      expect(codes, contains('mutable_tearoff'));
    });

    test(
      'fires on a tear-off assigned (not initialized) from a mutable field',
      () async {
        final codes = await reportedRuleCodes(
          MutableTearoffRule(),
          '''
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
''',
        );
        expect(codes, contains('mutable_tearoff'));
      },
    );

    test('fires on a tear-off stored from a mutable local variable', () async {
      final codes = await reportedRuleCodes(
        MutableTearoffRule(),
        '''
typedef VoidCallback = void Function();

class Handler {
  void handleTap() {}
}

void run() {
  Handler handler = Handler();
  final VoidCallback callback = handler.handleTap;
  callback();
}
''',
      );
      expect(codes, contains('mutable_tearoff'));
    });

    test('fires on a tear-off stored from a non-final parameter', () async {
      final codes = await reportedRuleCodes(
        MutableTearoffRule(),
        '''
typedef VoidCallback = void Function();

class Handler {
  void handleTap() {}
}

void run(Handler handler) {
  final VoidCallback cb = handler.handleTap;
  cb();
}
''',
      );
      expect(codes, contains('mutable_tearoff'));
    });

    test('does NOT fire when the receiver field is final', () async {
      final codes = await reportedRuleCodes(
        MutableTearoffRule(),
        '''
typedef VoidCallback = void Function();

class Handler {
  void handleTap() {}
}

class Controller {
  final Handler handler = Handler();
  late final VoidCallback onTap = handler.handleTap;
}
''',
      );
      expect(codes, isEmpty);
    });

    test('does NOT fire when the receiver parameter is final', () async {
      final codes = await reportedRuleCodes(
        MutableTearoffRule(),
        '''
typedef VoidCallback = void Function();

class Handler {
  void handleTap() {}
}

void run(final Handler handler) {
  final VoidCallback cb = handler.handleTap;
  cb();
}
''',
      );
      expect(codes, isEmpty);
    });

    test(
      'does NOT fire on this.method — this can never be reassigned even '
      'though the class has mutable fields',
      () async {
        final codes = await reportedRuleCodes(
          MutableTearoffRule(),
          '''
typedef VoidCallback = void Function();

class Controller {
  int counter = 0;

  void bump() {
    counter++;
  }

  late final VoidCallback onBump = this.bump;
}
''',
        );
        expect(codes, isEmpty);
      },
    );

    test(
      'does NOT fire when the tear-off is immediately invoked, not stored',
      () async {
        final codes = await reportedRuleCodes(
          MutableTearoffRule(),
          '''
class Handler {
  void handleTap() {}
}

void run() {
  Handler handler = Handler();
  handler.handleTap();
}
''',
        );
        expect(codes, isEmpty);
      },
    );

    test(
      'does NOT fire when the tear-off is passed as a one-shot argument, '
      'never retained past the call',
      () async {
        final codes = await reportedRuleCodes(
          MutableTearoffRule(),
          '''
typedef VoidCallback = void Function();

class Handler {
  void handleTap() {}
}

void run(List<VoidCallback> sink) {
  Handler handler = Handler();
  sink.add(handler.handleTap);
}
''',
        );
        expect(codes, isEmpty);
      },
    );

    test(
      'does NOT fire on a field read (not a method tear-off), even from a '
      'mutable receiver',
      () async {
        final codes = await reportedRuleCodes(
          MutableTearoffRule(),
          '''
typedef VoidCallback = void Function();

class Handler {
  VoidCallback onTapField = () {};
}

void run(Handler handler) {
  final VoidCallback cb = handler.onTapField;
  cb();
}
''',
        );
        expect(codes, isEmpty);
      },
    );

    test('does NOT fire on a plain sync call with no tear-off (control)', () async {
      final codes = await reportedRuleCodes(
        MutableTearoffRule(),
        '''
class Handler {
  void handleTap() {}
}

void run() {
  final handler = Handler();
  handler.handleTap();
}
''',
      );
      expect(codes, isEmpty);
    });
  });
}
