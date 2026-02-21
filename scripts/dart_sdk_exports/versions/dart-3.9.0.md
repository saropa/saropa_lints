# Dart SDK 3.9.0

## 3.9.0

**Released on:** 2025-08-13

### Language

Dart 3.9 assumes null safety when computing type promotion, reachability, and
definite assignment. This makes these features produce more accurate results for
modern Dart programs. As a result of this change, more dead_code warnings may be
produced. To take advantage of these improvements, set your package's [SDK
constraint][language version] lower bound to 3.9 or greater (`sdk: '^3.9.0'`).

[language version]: https://dart.dev/to/language-version

### Tools

#### Analyzer

- The [dart command-line tool][] commands that use the analysis server now run
  the AOT-compiled analysis server snapshot. These include `dart analyze`,
  `dart fix`, and `dart language-server`.

  There is no functional difference when using the AOT-compiled analysis server
  snapshot. But various tests indicate that there is a significant speedup in
  the time to analyze a project.

  In case of an incompatibility with the AOT-compiled snapshot, a
  `--no-use-aot-snapshot` flag may be passed to these commands. (Please file an
  issue with the appropriate project if you find that you need to use this
  flag! It will be removed in the future.) This flag directs the tool to revert
  to the old behavior, using the JIT-compiled analysis server snapshot. To
  direct the Dart Code plugin for VS Code to pass this flag, use the
  [`dart.analyzerAdditionalArgs`][vs-code-args] setting. To direct the Dart
  IntelliJ plugin to pass this flag, use the `dart.server.additional.arguments`
  registry property, similar to [these steps][intellij-args].

- Add the [`switch_on_type`][] lint rule.
- Add the [`unnecessary_unawaited`][] lint rule.
- Support a new annotation, `@awaitNotRequired`, which is used by the
  `discarded_futures` and `unawaited_futures` lint rules.
- Improve the `avoid_types_as_parameter_names` lint rule to include type
  parameters.
- The definition of an "obvious type" is expanded for the relevant lint rules,
  to include the type of a parameter.
- Many small improvements to the `discarded_futures` and `unawaited_futures`
  lint rules.
- The code that calculates fixes and assists has numerous performance
  improvements.
- A new "Remove async" assist is available.
- A new "Convert to normal parameter" assist is available for field formal
  parameters.
- New fixes are available for the following diagnostics:
  - `for_in_of_invalid_type`
  - `implicit_this_reference_in_initializer`
  - `prefer_foreach`
  - `undefined_operator`
  - `use_if_null_to_convert_nulls_to_bools`
- Numerous fixes and improvements are included in the "create method," "create
  getter," "create mixin," "add super constructor," and "replace final with
  var" fixes.
- Dependencies listed in `dependency_overrides` in a `pubspec.yaml` file now
  have document links to pub.dev.
- Improvements to type parameters and type arguments in the LSP type hierarchy.
- Folding try/catch/finally blocks is now supported for LSP clients.
- Improve code completion suggestions with regards to operators, extension
  members, named parameters, doc comments, patterns, collection if-elements and
  for-elements, and more.
- Improve syntax highlighting of escape sequences in string literals.
- Add "library cycle" information to the diagnostic pages.
- (Thanks [@FMorschel](https://github.com/FMorschel) for many of the above
  enhancements!)


[dart command-line tool]: https://dart.dev/tools/dart-tool
[vs-code-args]: https://dartcode.org/docs/settings/#dartanalyzeradditionalargs
[intellij-args]: https://github.com/dart-lang/sdk/blob/main/pkg/analysis_server/doc/tutorial/instrumentation.md#intellij-idea-and-android-studio
[`switch_on_type`]: http://dart.dev/lints/switch_on_type
[`unnecessary_unawaited`]: http://dart.dev/lints/unnecessary_unawaited

#### Dart build

- Breaking change of feature in preview: `dart build -f exe <target>` is now
  `dart build cli --target=<target>`. See `dart build cli --help` for more info.

#### Dart Development Compiler (dartdevc)

- Outstanding async code now checks and cancels itself after a hot restart if
  it was started in a different generation of the application before the
  restart. This includes outstanding `Future`s created by calling
  `JSPromise.toDart` from the`dart:js_interop` and the underlying the
  `dart:js_util` helper `promiseToFuture`. Dart callbacks will not be run, but
  callbacks on the JavaScript side will still be executed.
- Fixed a soundness issue that allowed direct invocation of the value returned
  from a getter without any runtime checks when the getter's return type was a
  generic type argument instantiated as `dynamic` or `Function`.

  A getter defined as:

  ```dart
  class Container<T> {
    T get value => _value;
    ...
  }
  ```

  Could trigger the issue with a direct invocation:

  ```dart
  Container<dynamic>().value('Invocation with missing runtime checks!');
  ```

#### Dart native compiler

Added [cross-compilation][] support for
target architectures of `arm` (ARM32) and `riscv64` (RV64GC)
when the target OS is Linux.

[cross-compilation]: https://dart.dev/tools/dart-compile#cross-compilation-exe

#### Pub

- [Git dependencies][] can now be version-solved based on git tags.

  Use a `tag_pattern` in the descriptor and a version constraint, and all
  commits matching the pattern will be considered during resolution. For
  example:

  ```yaml
  dependencies:
    my_dependency:
      git:
        url: https://github.com/example/my_dependency
        tag_pattern: v{{version}}
      version: ^2.0.1
  ```

- Starting from language version 3.9 the `flutter` constraint upper bound is now
  respected in your root package. For example:

  ```yaml
  name: my_app
  environment:
    sdk: ^3.9.0
    flutter: 3.33.0
  ```

  Results in `dart pub get` failing if invoked with a version of
  the Flutter SDK different from `3.33.0`.

  The upper bound of the flutter constraint is still ignored in
  packages used as dependencies.
  See https://github.com/flutter/flutter/issues/95472 for details.

[Git dependencies]: https://dart.dev/tools/pub/dependencies#git-packages
