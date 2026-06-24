# Fix: unnecessary_import in pubspec constraint parser test

The publish script's static-analysis gate (`dart analyze --fatal-infos`) failed on an
`unnecessary_import` info in `test/config/pubspec_constraint_parser_test.dart`. The test
imported `package:saropa_lints/src/rules/config/pubspec_constraint_rules.dart` directly,
but every symbol it used from that file is already re-exported through the package barrel
`package:saropa_lints/saropa_lints.dart`, which the test also imports — so the direct
import was redundant and the analyzer flagged it as fatal under CI's `--fatal-infos` policy.

## Finish Report (2026-06-24)

### Defect
`dart analyze` reported `info - unnecessary_import` at
`test/config/pubspec_constraint_parser_test.dart:11`. Because both the publish script and
CI run `dart analyze --fatal-infos`, the info was promoted to a fatal error and blocked the
publish analysis step (exit code 1).

### Change
Removed the redundant
`import 'package:saropa_lints/src/rules/config/pubspec_constraint_rules.dart';` line. The
rule classes the test instantiates (`PubspecConstraintRules` and siblings) remain available
through the existing `package:saropa_lints/saropa_lints.dart` barrel import, so no symbol
resolution changed. The parser import
(`package:saropa_lints/src/config/pubspec_constraint_parser.dart`) was left in place — its
`parseConstraint` / `parsePubspecConstraints` functions are not re-exported by the barrel.

### Verification
`dart test --no-pub test/config/pubspec_constraint_parser_test.dart` passes (exit 0). The
removed import resolves the only analyzer info reported by the publish gate for this file.

### Scope
Test source only. No rule logic, tier assignment, quick fix, or public API changed. A
Maintenance entry was added to the `[14.2.0]` unreleased changelog section.
