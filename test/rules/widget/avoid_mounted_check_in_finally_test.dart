// Regression/behavior tests for avoid_mounted_check_in_finally.
//
// The rule is not yet wired into the global tier registry (a separate
// process handles the three-way registration centrally to avoid merge
// conflicts across parallel rule-authoring agents). This test therefore
// exercises the rule class directly via the resolved-rule harness, which
// runs a single rule against inline source without depending on
// lib/saropa_lints.dart or lib/src/tiers.dart.
//
// The harness resolves fixtures against the `example` package, which has no
// Flutter dependency — `State`/`Widget` resolve to InvalidType there. The
// rule's State-class gate (`isWidgetOrStateClass`) is lexeme-based (matches
// a superclass name literally ending in "State"/"Widget"), not a resolved
// type check, so it still gates correctly under this harness.
library;

import 'package:saropa_lints/src/rules/widget/avoid_mounted_check_in_finally_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

void main() {
  group('avoid_mounted_check_in_finally', () {
    test(
      'fires on `if (mounted)` inside finally, after an await, guarding '
      'setState',
      () async {
        final codes = await reportedRuleCodes(
          AvoidMountedCheckInFinallyRule(),
          '''
// The example package this harness resolves against has no Flutter
// dependency (State/StatefulWidget resolve to InvalidType), but the rule's
// requiresFlutterImport gate is a text check on the import string — not on
// resolution — so this import is required for the rule to run at all.
import 'package:flutter/material.dart';

class MyState extends State<StatefulWidget> {
  bool _isLoading = false;

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    } finally {
      _dispose();
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _dispose() {}
}
''',
        );
        expect(codes, contains('avoid_mounted_check_in_finally'));
      },
    );

    test(
      'fires on `if (!mounted) return;` inside finally guarding a '
      'Navigator call',
      () async {
        final codes = await reportedRuleCodes(
          AvoidMountedCheckInFinallyRule(),
          '''
import 'package:flutter/material.dart';

class MyState extends State<StatefulWidget> {
  Future<void> _save() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    } finally {
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }
}
''',
        );
        expect(codes, contains('avoid_mounted_check_in_finally'));
      },
    );

    test(
      'does NOT fire when mounted is checked immediately after the await, '
      'outside the finally block',
      () async {
        final codes = await reportedRuleCodes(
          AvoidMountedCheckInFinallyRule(),
          '''
import 'package:flutter/material.dart';

class MyState extends State<StatefulWidget> {
  bool _isLoading = false;

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    } finally {
      _dispose();
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  void _dispose() {}
}
''',
        );
        expect(codes, isEmpty);
      },
    );

    test(
      'does NOT fire when the mounted-gated body only logs (no setState/'
      'navigation)',
      () async {
        final codes = await reportedRuleCodes(
          AvoidMountedCheckInFinallyRule(),
          '''
import 'package:flutter/material.dart';

class MyState extends State<StatefulWidget> {
  Future<void> _refresh() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    } finally {
      if (mounted) {
        print('refresh finished while still mounted');
      }
    }
  }
}
''',
        );
        expect(codes, isEmpty);
      },
    );

    test(
      'does NOT fire when the try block has no await (no async gap to '
      'guard against)',
      () async {
        final codes = await reportedRuleCodes(
          AvoidMountedCheckInFinallyRule(),
          '''
import 'package:flutter/material.dart';

class MyState extends State<StatefulWidget> {
  bool _busy = false;

  void _run() {
    try {
      _busy = true;
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}
''',
        );
        expect(codes, isEmpty);
      },
    );

    test(
      'does NOT fire when mounted is checked in the try body, not finally '
      '(control)',
      () async {
        final codes = await reportedRuleCodes(
          AvoidMountedCheckInFinallyRule(),
          '''
import 'package:flutter/material.dart';

class MyState extends State<StatefulWidget> {
  Future<void> _load() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      if (mounted) {
        setState(() {});
      }
    } finally {
      print('load attempted');
    }
  }
}
''',
        );
        expect(codes, isEmpty);
      },
    );

    test('does NOT fire outside a State/Widget class (control)', () async {
      final codes = await reportedRuleCodes(
        AvoidMountedCheckInFinallyRule(),
        '''
import 'package:flutter/material.dart';

class PlainService {
  bool mounted = false;

  Future<void> run() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    } finally {
      if (mounted) {
        setState();
      }
    }
  }

  void setState() {}
}
''',
      );
      expect(codes, isEmpty);
    });
  });
}
