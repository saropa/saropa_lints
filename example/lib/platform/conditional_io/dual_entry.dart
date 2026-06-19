// Conditional entry that picks dual_native.dart for the io branch. On its own
// this would mark dual_native.dart native-only — but dual_unconditional.dart
// also imports it unconditionally, so it can still load on web.
import 'cond_import_web.dart'
    if (dart.library.io) 'dual_native.dart';

void run() {}
