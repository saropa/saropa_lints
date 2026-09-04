// Behavioral tests for new_instance_cascade: fires when two or more
// immediately-consecutive statements each configure the same
// freshly-constructed local variable (method call or plain property
// assignment), and stays silent on every edge case called out in the
// proposal (single call, an unrelated statement breaking the run,
// reassignment of the receiver, and calls split across control flow).
// Runs the real rule against resolved source via the harness so detection
// logic — not just metadata — is verified.
library;

import 'package:saropa_lints/src/rules/stylistic/new_instance_cascade_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

void main() {
  group('new_instance_cascade', () {
    test('fires on 2 consecutive property assignments on a fresh instance', () async {
      final codes = await reportedRuleCodes(NewInstanceCascadeRule(), '''
class TextEditingController {
  String text = '';
  int selection = 0;
}

void build() {
  final controller = TextEditingController();
  controller.text = 'hello';
  controller.selection = 5;
}
''');
      expect(codes, contains('new_instance_cascade'));
    });

    test('fires on 2 consecutive method calls on a fresh instance', () async {
      final codes = await reportedRuleCodes(NewInstanceCascadeRule(), '''
class Builder {
  void add(int value) {}
  void build() {}
}

void run() {
  final builder = Builder();
  builder.add(1);
  builder.add(2);
}
''');
      expect(codes, contains('new_instance_cascade'));
    });

    test('does NOT fire on a single configuring statement', () async {
      final codes = await reportedRuleCodes(NewInstanceCascadeRule(), '''
class TextEditingController {
  String text = '';
}

void build() {
  final controller = TextEditingController();
  controller.text = 'hello';
}
''');
      expect(codes, isEmpty);
    });

    test('does NOT fire when an unrelated statement breaks the run', () async {
      final codes = await reportedRuleCodes(NewInstanceCascadeRule(), '''
class TextEditingController {
  String text = '';
  int selection = 0;
}

void log(String message) {}

void build() {
  final controller = TextEditingController();
  controller.text = 'hello';
  log('controller created');
  controller.selection = 5;
}
''');
      expect(codes, isEmpty);
    });

    test('does NOT fire when the receiver is reassigned instead of configured', () async {
      final codes = await reportedRuleCodes(NewInstanceCascadeRule(), '''
class TextEditingController {
  String text = '';
}

void build() {
  var controller = TextEditingController();
  controller = TextEditingController();
  controller.text = 'hello';
}
''');
      expect(codes, isEmpty);
    });

    test('does NOT fire when calls are split across an if block', () async {
      final codes = await reportedRuleCodes(NewInstanceCascadeRule(), '''
class TextEditingController {
  String text = '';
  int selection = 0;
}

void build(bool flag) {
  final controller = TextEditingController();
  controller.text = 'hello';
  if (flag) {
    controller.selection = 5;
  }
}
''');
      expect(codes, isEmpty);
    });

    test('does NOT fire when the intermediate statement reads the variable', () async {
      final codes = await reportedRuleCodes(NewInstanceCascadeRule(), '''
class Value {
  int amount = 0;
}

class Builder {
  Value read() => Value();
  void configure(int amount) {}
}

void build() {
  final builder = Builder();
  final value = builder.read();
  builder.configure(value.amount);
}
''');
      expect(codes, isEmpty);
    });

    test('does NOT fire on an already-cascaded initializer', () async {
      final codes = await reportedRuleCodes(NewInstanceCascadeRule(), '''
class TextEditingController {
  String text = '';
  int selection = 0;
}

void build() {
  final controller = TextEditingController()
    ..text = 'hello'
    ..selection = 5;
}
''');
      expect(codes, isEmpty);
    });

    test(
      'does NOT fire when the second statement\'s RHS self-references the receiver',
      () async {
        // `controller.selection = TextSelection(offset: controller.text.length)`
        // could not be folded into `Ctrl()..selection = ...controller...`
        // without referencing `controller` before it is bound — a compile
        // error, so the rule must stay silent.
        final codes = await reportedRuleCodes(NewInstanceCascadeRule(), '''
class TextEditingController {
  String text = '';
  int selection = 0;
}

void build() {
  final controller = TextEditingController();
  controller.text = 'hello';
  controller.selection = controller.text.length;
}
''');
        expect(codes, isEmpty);
      },
    );

    test(
      'does NOT fire when a method-call argument self-references the receiver',
      () async {
        // Same self-reference hazard as the assignment case above, but via
        // a method-call argument instead of an assignment's RHS.
        final codes = await reportedRuleCodes(NewInstanceCascadeRule(), '''
class TextEditingController {
  String text = '';
  void jumpTo(int offset) {}
}

void build() {
  final controller = TextEditingController();
  controller.text = 'hello';
  controller.jumpTo(controller.text.length);
}
''');
        expect(codes, isEmpty);
      },
    );

    test(
      'fires once on 3+ consecutive configuring statements, at the first',
      () async {
        // Guards the "report once, at the first match" behavior the
        // `count >= 2` early-return relies on but was previously unasserted
        // for runs longer than 2.
        final codes = await reportedRuleCodes(NewInstanceCascadeRule(), '''
class TextEditingController {
  String text = '';
  int selection = 0;
  void addListener(void Function() f) {}
}

void build() {
  final controller = TextEditingController();
  controller.text = 'hello';
  controller.selection = 5;
  controller.addListener(() {});
}
''');
        expect(codes.where((c) => c == 'new_instance_cascade').length, 1);
      },
    );

    test(
      'fires on trailing statements after a partially-cascaded initializer',
      () async {
        // A declaration that already carries a partial cascade
        // (`Ctrl()..text = 'a'`) must not stop detection entirely — two or
        // more further un-cascaded statements are still a legitimate
        // cascade opportunity.
        final codes = await reportedRuleCodes(NewInstanceCascadeRule(), '''
class TextEditingController {
  String text = '';
  int selection = 0;
  void addListener(void Function() f) {}
}

void build() {
  final controller = TextEditingController()..text = 'hello';
  controller.selection = 5;
  controller.addListener(() {});
}
''');
        expect(codes, contains('new_instance_cascade'));
      },
    );
  });
}
