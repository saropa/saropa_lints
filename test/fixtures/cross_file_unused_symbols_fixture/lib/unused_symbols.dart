import 'package:meta/meta.dart';

class UsedClass {}

class UnusedClass {}

String usedTopLevelFunction() => 'used';

String unusedTopLevelFunction() => 'unused';

const String usedConstValue = 'x';

const String unusedConstValue = 'y';

String _privateCandidate() => 'p';

@visibleForTesting
String helperForTests() => 'keep';
