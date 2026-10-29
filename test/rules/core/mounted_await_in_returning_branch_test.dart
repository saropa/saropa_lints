// Regression: an `await` inside an always-exiting `if` branch must not put
// later `setState` calls in the "after await" danger zone.
// Rules: check_mounted_after_async, require_mounted_check_after_await,
// require_mounted_check, use_setstate_synchronously.
library;

import 'package:saropa_lints/src/rules/core/async_rules.dart';
import 'package:saropa_lints/src/rules/core/state_management_rules.dart';
import 'package:saropa_lints/src/rules/widget/widget_lifecycle_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

String _stateSrc(String body) =>
    '''
class State<T> {
  bool get mounted => true;
  void setState(void Function() fn) {}
}
class W {}
class S extends State<W> {
  bool busy = false;
  Future<void> advance() async {}
  Future<bool> write() async => true;
  Future<void> save(bool hasPicks) async {
$body
  }
}
''';

const String _exitingBranch = '''
    if (!hasPicks) {
      await advance();
      return;
    }
    setState(() => busy = true);
''';

const String _fallThrough = '''
    if (!hasPicks) {
      await advance();
    }
    setState(() => busy = true);
''';

void main() {
  final rules = <String, dynamic Function()>{
    'check_mounted_after_async': () => CheckMountedAfterAsyncRule(),
    'require_mounted_check_after_await': () =>
        RequireMountedCheckAfterAwaitRule(),
    'require_mounted_check': () => RequireMountedCheckRule(),
    'use_setstate_synchronously': () => UseSetStateSynchronouslyRule(),
  };

  rules.forEach((name, make) {
    group(name, () {
      test('silent when the await is only in an exiting branch', () async {
        final codes = await reportedRuleCodes(
          make(),
          _stateSrc(_exitingBranch),
        );
        expect(codes, isNot(contains(name)));
      });

      test('still fires when the awaiting branch falls through', () async {
        final codes = await reportedRuleCodes(make(), _stateSrc(_fallThrough));
        expect(codes, contains(name));
      });
    });
  });
}
