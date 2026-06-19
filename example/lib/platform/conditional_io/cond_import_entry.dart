// Public entry: conditional IMPORT picks the implementation at compile time.
// The io branch (cond_import_native.dart) is only loaded when dart.library.io
// is defined, so require_platform_check is suppressed inside it.
import 'cond_import_web.dart'
    if (dart.library.io) 'cond_import_native.dart';

void run() => serve();
