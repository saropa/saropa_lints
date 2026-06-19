// ignore_for_file: depend_on_referenced_packages
// Unconditional import of dual_native.dart. This is the path that can pull the
// dart:io code into a web build, which is why require_platform_check must keep
// firing in dual_native.dart despite the conditional reference in dual_entry.dart.
import 'dual_native.dart';

void trigger() => cache();
