// OK: Imports a normal module that does NOT re-export main.dart.
// Used by tests to ensure the rule does not trigger on compliant code.
import 'avoid_barrel_files_fixture.dart';

void useModule() {}
