// Public entry: conditional EXPORT picks the implementation at compile time.
// The io branch (cond_export_native.dart) is only loaded when dart.library.io
// is defined. require_platform_check must be suppressed inside that branch.
export 'cond_export_web.dart'
    if (dart.library.io) 'cond_export_native.dart';
