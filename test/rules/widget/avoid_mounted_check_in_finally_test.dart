// Regression/behavior tests for avoid_mounted_check_in_finally (v2 premise).
//
// PREMISE NOTE: v1 of this rule flagged every `if (mounted) { setState(); }`
// inside a `finally` block and told authors to move it after the try/finally.
// That was verified WRONG against the Dart VM: when the try body throws, the
// finally runs and the exception keeps propagating, so statements after the
// try/finally never execute (the analyzer reports them as `dead_code`). The
// v1 advice left `_isLoading` stuck true on every error path. v2 keeps the
// rule name but retargets it at an ordering bug — an UNGUARDED widget-tree
// call written above a `mounted`-guarded one in the SAME finally block.
//
// The rule is fully registered (export in lib/src/rules/all_rules.dart,
// factory in lib/saropa_lints.dart, tier assignment in lib/src/tiers.dart).
// This test exercises the rule class directly via the resolved-rule harness,
// which runs a single rule against inline source without depending on any of
// those three registration points — that keeps the test fast and immune to
// unrelated registration churn elsewhere in the codebase.
//
// The harness resolves fixtures against the `example` package, which has no
// Flutter dependency — `State`/`Widget` resolve to InvalidType there. The
// rule's State-class gate (`isWidgetOrStateClass`) is lexeme-based (matches a
// superclass name literally ending in "State"/"Widget"), not a resolved type
// check, so it still gates correctly under this harness.
library;

import 'package:saropa_lints/src/rules/widget/avoid_mounted_check_in_finally_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';
import '../../support/rule_instantiation_assertions.dart';

void main() {
  group('avoid_mounted_check_in_finally', () {
    test(
      'fires on an unguarded setState above a mounted-guarded Navigator call '
      'in the same finally block',
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
    try {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    } finally {
      setState(() => _isLoading = false);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }
}
''',
        );
        expect(codes, contains('avoid_mounted_check_in_finally'));
      },
    );

    test(
      'fires on an unguarded Navigator call above an "if (!mounted) return;" '
      'guard clause in the same finally block',
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
      Navigator.of(context).pop();
      if (!mounted) return;
      setState(() {});
    }
  }
}
''',
        );
        expect(codes, contains('avoid_mounted_check_in_finally'));
      },
    );

    test(
      'fires when the async gap comes from an OUTER try (nested-try false '
      'negative fixed in v2)',
      () async {
        final codes = await reportedRuleCodes(
          AvoidMountedCheckInFinallyRule(),
          '''
import 'package:flutter/material.dart';

class MyState extends State<StatefulWidget> {
  Future<void> _save() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      try {
        _syncOp();
      } finally {
        setState(() {});
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } finally {
      _cleanup();
    }
  }

  void _syncOp() {}

  void _cleanup() {}
}
''',
        );
        expect(codes, contains('avoid_mounted_check_in_finally'));
      },
    );

    test(
      'fires when the async gap comes from an await in a catch clause '
      '(recovery path still falls into the same finally)',
      () async {
        final codes = await reportedRuleCodes(
          AvoidMountedCheckInFinallyRule(),
          '''
import 'package:flutter/material.dart';

class MyState extends State<StatefulWidget> {
  Future<void> _save() async {
    try {
      _syncOp();
    } catch (e) {
      await _recover();
    } finally {
      setState(() {});
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void _syncOp() {}

  Future<void> _recover() async {}
}
''',
        );
        expect(codes, contains('avoid_mounted_check_in_finally'));
      },
    );

    // ---------------------------------------------------------------------
    // Premise regression: the shapes v1 wrongly flagged must now stay silent.
    // ---------------------------------------------------------------------

    test(
      'does NOT fire on the canonical guarded state reset inside finally — '
      'the v1 "BAD" example, which is actually correct code',
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _dispose() {}
}
''',
        );
        expect(codes, isEmpty);
      },
    );

    test(
      'does NOT fire when every widget-tree operation sits inside the single '
      'mounted guard',
      () async {
        final codes = await reportedRuleCodes(
          AvoidMountedCheckInFinallyRule(),
          '''
import 'package:flutter/material.dart';

class MyState extends State<StatefulWidget> {
  bool _isLoading = false;

  Future<void> _submit() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pop();
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
      'does NOT fire when the early-return guard comes first, protecting '
      'every call below it',
      () async {
        final codes = await reportedRuleCodes(
          AvoidMountedCheckInFinallyRule(),
          '''
import 'package:flutter/material.dart';

class MyState extends State<StatefulWidget> {
  bool _isLoading = false;

  Future<void> _submit() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.of(context).pop();
    }
  }
}
''',
        );
        expect(codes, isEmpty);
      },
    );

    // ---------------------------------------------------------------------
    // Gate controls.
    // ---------------------------------------------------------------------

    test(
      'does NOT fire without an await — no async gap means no disposal risk',
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
      setState(() => _busy = false);
      if (mounted) {
        Navigator.of(context).pop();
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
      'does NOT fire when the outer await happens AFTER the inner '
      'try/finally (offset bound on the async-gap search)',
      () async {
        final codes = await reportedRuleCodes(
          AvoidMountedCheckInFinallyRule(),
          '''
import 'package:flutter/material.dart';

class MyState extends State<StatefulWidget> {
  Future<void> _save() async {
    try {
      try {
        _syncOp();
      } finally {
        setState(() {});
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    } finally {
      _cleanup();
    }
  }

  void _syncOp() {}

  void _cleanup() {}
}
''',
        );
        expect(codes, isEmpty);
      },
    );

    test(
      'does NOT fire when the guard only logs — no evidence the author was '
      'reasoning about disposal',
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
      setState(() {});
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
      'does NOT fire on a compound condition (mounted && x) — out of scope '
      'by design, only the exact mounted/!mounted shapes are matched',
      () async {
        final codes = await reportedRuleCodes(
          AvoidMountedCheckInFinallyRule(),
          '''
import 'package:flutter/material.dart';

class MyState extends State<StatefulWidget> {
  bool _shouldUpdate = true;

  Future<void> _submit() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    } finally {
      setState(() {});
      if (mounted && _shouldUpdate) {
        Navigator.of(context).pop();
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
      'does NOT fire when the mounted check is inside a nested closure '
      'created within finally, not the finally block itself',
      () async {
        final codes = await reportedRuleCodes(
          AvoidMountedCheckInFinallyRule(),
          '''
import 'package:flutter/material.dart';

class MyState extends State<StatefulWidget> {
  Future<void> _submit() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    } finally {
      setState(() {});
      Future<void>(() async {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
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
      setState();
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

  // Rule Instantiation: metadata smoke test.
  group('avoid_mounted_check_in_finally - Rule Instantiation', () {
    test('AvoidMountedCheckInFinallyRule', () {
      assertRuleMetadata(
        AvoidMountedCheckInFinallyRule(),
        'avoid_mounted_check_in_finally',
      );
    });
  });
}
