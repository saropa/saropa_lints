import 'used_dep.dart' as used_alias;
import 'unused_dep.dart' as unused_alias;
import 'show_hide_dep.dart' show shownUsed, shownDead;
import 'hide_dep.dart' hide hiddenDead;
import 'show_only_dead.dart' show onlyDead;
import 'reexport_barrel.dart';
import 'deferred_dep.dart' deferred as deferred_dep;

String callUsed() => used_alias.usedFromDep();

String callShown() => shownUsed();

String callVisible() => visibleUsed();

String callReexported() => fromReexportSource();

Future<void> preloadDeferred() => deferred_dep.loadLibrary();
