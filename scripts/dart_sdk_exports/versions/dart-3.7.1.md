# Dart SDK 3.7.1

## 3.7.1

**Released on:** 2025-02-26

This is a patch release that:

 - Fixes a bug in the DevTools network profiler that was causing network
   traffic to be dropped (issue [#8888]).
 - Fixes a bug in DDC that prevents code from compiling when it includes
   factory constructors containing generic local functions (issue [#160338]).
 - Fixes a bug in the CFE that didn't correctly mark wildcard variables
   in formal parameters, causing the wildcard variables to appear in
   variable lists while debugging (issue [#60121]).

[#8888]: https://github.com/flutter/devtools/issues/8888
[#160338]: https://github.com/flutter/flutter/issues/160338
[#60121]: https://github.com/dart-lang/sdk/issues/60121
