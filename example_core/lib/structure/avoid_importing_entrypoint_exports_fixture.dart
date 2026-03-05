// LINT: Importing from a file that re-exports main.dart pulls the entry point into the dependency graph.
import 'entrypoint_barrel.dart';

void useBarrel() {}
