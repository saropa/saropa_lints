# Dart SDK 3.0.0

## 3.0.0

- 2023-05-10

### Language

Dart 3.0 adds the following features. To use them, set your package's [SDK
constraint][language version] lower bound to 3.0 or greater (`sdk: '^3.0.0'`).

[language version]: https://dart.dev/to/language-version

- **[Records]**: Records are anonymous immutable data structures that let you
  aggregate multiple values together, similar to [tuples][] in other languages.
  With records, you can return multiple values from a function, create composite
  map keys, or use them any other place where you want to bundle a couple of
  objects together.

  For example, using a record to return two values:

  ```dart
  (double x, double y) geoLocation(String name) {
    if (name == 'Nairobi') {
      return (-1.2921, 36.8219);
    } else {
      ...
    }
  }
  ```

- **[Pattern matching]**: Expressions build values out of smaller pieces.
  Conversely, patterns are an expressive tool for decomposing values back into
  their constituent parts. Patterns can call getters on an object, access
  elements from a list, pull fields out of a record, etc. For example, we can
  destructure the record from the previous example like so:

  ```dart
  var (lat, long) = geoLocation('Nairobi');
  print('Nairobi is at $lat, $long.');
  ```

  Patterns can also be used in [switch cases]. There, you can destructure values
  and also test them to see if they have a certain type or value:

  ```dart
  switch (object) {
    case [int a]:
      print('A list with a single integer element $a');
    case ('name', _):
      print('A two-element record whose first field is "name".');
    default: print('Some other object.');
  }
  ```

  Also, as you can see, non-empty switch cases no longer need `break;`
  statements.

  **Breaking change**: Dart 3.0 interprets [switch cases] as patterns instead of
  constant expressions. Most constant expressions found in switch cases are
  valid patterns with the same meaning (named constants, literals, etc.). You
  may need to tweak a few constant expressions to make them valid. This only
  affects libraries that have upgraded to language version 3.0.

- **[Switch expressions]**: Switch expressions allow you to use patterns and
  multi-way branching in contexts where a statement isn't allowed:

  ```dart
  return TextButton(
    onPressed: _goPrevious,
    child: Text(switch (page) {
      0 => 'Exit story',
      1 => 'First page',
      _ when page == _lastPage => 'Start over',
      _ => 'Previous page',
    }),
  );
  ```

- **[If-case statements and elements]**: A new if construct that matches a value
  against a pattern and executes the then or else branch depending on whether
  the pattern matches:

  ```dart
  if (json case ['user', var name]) {
    print('Got user message for user $name.');
  }
  ```

  There is also a corresponding [if-case element] that can be used in collection
  literals.

- **[Sealed classes]**: When you mark a type `sealed`, the compiler ensures that
  switches on values of that type [exhaustively cover] every subtype. This
  enables you to program in an [algebraic datatype][] style with the
  compile-time safety you expect:

  ```dart
  sealed class Amigo {}
  class Lucky extends Amigo {}
  class Dusty extends Amigo {}
  class Ned extends Amigo {}

  String lastName(Amigo amigo) =>
      switch (amigo) {
        Lucky _ => 'Day',
        Ned _   => 'Nederlander',
      };
  ```

  In this last example, the compiler reports an error that the switch doesn't
  cover the subclass `Dusty`.

- **[Class modifiers]**: New modifiers `final`, `interface`, `base`, and `mixin`
  on `class` and `mixin` declarations let you control how the type can be used.
  By default, Dart is flexible in that a single class declaration can be used as
  an interface, a superclass, or even a mixin. This flexibility can make it
  harder to evolve an API over time without breaking users. We mostly keep the
  current flexible defaults, but these new modifiers give you finer-grained
  control over how the type can be used.

  **Breaking change:** Class declarations from libraries that have been upgraded
  to Dart 3.0 can no longer be used as mixins by default. If you want the class
  to be usable as both a class and a mixin, mark it [`mixin class`][mixin
  class]. If you want it to be used only as a mixin, make it a `mixin`
  declaration. If you haven't upgraded a class to Dart 3.0, you can still use it
  as a mixin.

- **Breaking change** [#50902][]: Dart reports a compile-time error if a
  `continue` statement targets a [label] that is not a loop (`for`, `do` and
  `while` statements) or a `switch` member. Fix this by changing the `continue`
  to target a valid labeled statement.

- **Breaking change** [language/#2357][]: Starting in language version 3.0,
  Dart reports a compile-time error if a colon (`:`) is used as the
  separator before the default value of an optional named parameter.
  Fix this by changing the colon (`:`) to an equal sign (`=`).

[records]: https://dart.dev/language/records
[tuples]: https://en.wikipedia.org/wiki/Tuple
[pattern matching]: https://dart.dev/language/patterns
[switch cases]: https://dart.dev/language/branches#switch
[switch expressions]: https://dart.dev/language/branches#switch-expressions
[if-case statements and elements]: https://dart.dev/language/branches#if-case
[if-case element]: https://dart.dev/language/collections#control-flow-operators
[sealed classes]: https://dart.dev/language/class-modifiers#sealed
[exhaustively cover]: https://dart.dev/language/branches#exhaustiveness-checking
[algebraic datatype]: https://en.wikipedia.org/wiki/Algebraic_data_type
[class modifiers]: https://dart.dev/language/class-modifiers
[mixin class]: https://dart.dev/language/mixins#class-mixin-or-mixin-class
[#50902]: https://github.com/dart-lang/sdk/issues/50902
[label]: https://dart.dev/language/branches#switch
[language/#2357]: https://github.com/dart-lang/language/issues/2357

### Libraries

#### General changes

- **Breaking Change**: Non-`mixin` classes in the platform libraries
  can no longer be mixed in, unless they are explicitly marked as `mixin class`.
  The following existing classes have been made mixin classes:
  * `Iterable`
  * `IterableMixin` (now alias for `Iterable`)
  * `IterableBase` (now alias for `Iterable`)
  * `ListMixin`
  * `SetMixin`
  * `MapMixin`
  * `LinkedListEntry`
  * `StringConversionSink`

#### `dart:core`
- Added `bool.parse` and `bool.tryParse` static methods.
- Added `DateTime.timestamp()` constructor to get current time as UTC.
- The type of `RegExpMatch.pattern` is now `RegExp`, not just `Pattern`.

- **Breaking change** [#49529][]:
  - Removed the deprecated `List` constructor, as it wasn't null safe.
    Use list literals (e.g. `[]` for an empty list or `<int>[]` for an empty
    typed list) or [`List.filled`][].
  - Removed the deprecated `onError` argument on [`int.parse`][], [`double.parse`][],
    and [`num.parse`][]. Use the [`tryParse`][] method instead.
  - Removed the deprecated [`proxy`][] and [`Provisional`][] annotations.
    The original `proxy` annotation has no effect in Dart 2,
    and the `Provisional` type and [`provisional`][] constant
    were only used internally during the Dart 2.0 development process.
  - Removed the deprecated [`Deprecated.expires`][] getter.
    Use [`Deprecated.message`][] instead.
  - Removed the deprecated [`CastError`][] error.
    Use [`TypeError`][] instead.
  - Removed the deprecated [`FallThroughError`][] error. The kind of
    fall-through previously throwing this error was made a compile-time
    error in Dart 2.0.
  - Removed the deprecated [`NullThrownError`][] error. This error is never
    thrown from null safe code.
  - Removed the deprecated [`AbstractClassInstantiationError`][] error. It was made
    a compile-time error to call the constructor of an abstract class in Dart 2.0.
  - Removed the deprecated [`CyclicInitializationError`]. Cyclic dependencies are
    no longer detected at runtime in null safe code. Such code will fail in other
    ways instead, possibly with a StackOverflowError.
  - Removed the deprecated [`NoSuchMethodError`][] default constructor.
    Use the [`NoSuchMethodError.withInvocation`][] named constructor instead.
  - Removed the deprecated [`BidirectionalIterator`][] class.
    Existing bidirectional iterators can still work, they just don't have
    a shared supertype locking them to a specific name for moving backwards.

- **Breaking change when migrating code to Dart 3.0**:
  Some changes to platform libraries only affect code when that code is migrated
  to language version 3.0.
  - The `Function` type can no longer be implemented, extended or mixed in.
    Since Dart 2.0 writing `implements Function` has been allowed
    for backwards compatibility, but it has not had any effect.
    In Dart 3.0, the `Function` type is `final` and cannot be subtyped,
    preventing code from mistakenly assuming it works.
  - The following declarations can only be implemented, not extended:
    * `Comparable`
    * `Exception`
    * `Iterator`
    * `Pattern`
    * `Match`
    * `RegExp`
    * `RegExpMatch`
    * `StackTrace`
    * `StringSink`

    None of these declarations contained any implementation to inherit,
    and are marked as `interface` to signify that they are only intended
    as interfaces.
  - The following declarations can no longer be implemented or extended:
    * `MapEntry`
    * `OutOfMemoryError`
    * `StackOverflowError`
    * `Expando`
    * `WeakReference`
    * `Finalizer`

    The `MapEntry` value class is restricted to enable later optimizations.
    The remaining classes are tightly coupled to the platform and not
    intended to be subclassed or implemented.

[#49529]: https://github.com/dart-lang/sdk/issues/49529
[`List.filled`]: https://api.dart.dev/stable/2.18.6/dart-core/List/List.filled.html
[`int.parse`]: https://api.dart.dev/stable/2.18.4/dart-core/int/parse.html
[`double.parse`]: https://api.dart.dev/stable/2.18.4/dart-core/double/parse.html
[`num.parse`]: https://api.dart.dev/stable/2.18.4/dart-core/num/parse.html
[`tryParse`]: https://api.dart.dev/stable/2.18.4/dart-core/num/tryParse.html
[`Deprecated.expires`]: https://api.dart.dev/stable/2.18.4/dart-core/Deprecated/expires.html
[`Deprecated.message`]: https://api.dart.dev/stable/2.18.4/dart-core/Deprecated/message.html
[`AbstractClassInstantiationError`]: https://api.dart.dev/stable/2.17.4/dart-core/AbstractClassInstantiationError-class.html
[`CastError`]: https://api.dart.dev/stable/2.17.4/dart-core/CastError-class.html
[`FallThroughError`]: https://api.dart.dev/stable/2.17.4/dart-core/FallThroughError-class.html
[`NoSuchMethodError`]: https://api.dart.dev/stable/2.18.4/dart-core/NoSuchMethodError/NoSuchMethodError.html
[`NoSuchMethodError.withInvocation`]: https://api.dart.dev/stable/2.18.4/dart-core/NoSuchMethodError/NoSuchMethodError.withInvocation.html
[`CyclicInitializationError`]: https://api.dart.dev/dev/2.19.0-430.0.dev/dart-core/CyclicInitializationError-class.html
[`Provisional`]: https://api.dart.dev/stable/2.18.4/dart-core/Provisional-class.html
[`provisional`]: https://api.dart.dev/stable/2.18.4/dart-core/provisional-constant.html
[`proxy`]: https://api.dart.dev/stable/2.18.4/dart-core/proxy-constant.html
[`CastError`]: https://api.dart.dev/stable/2.18.3/dart-core/CastError-class.html
[`TypeError`]: https://api.dart.dev/stable/2.18.3/dart-core/TypeError-class.html
[`FallThroughError`]: https://api.dart.dev/dev/2.19.0-374.0.dev/dart-core/FallThroughError-class.html
[`NullThrownError`]: https://api.dart.dev/dev/2.19.0-430.0.dev/dart-core/NullThrownError-class.html
[`AbstractClassInstantiationError`]: https://api.dart.dev/stable/2.18.3/dart-core/AbstractClassInstantiationError-class.html
[`CyclicInitializationError`]: https://api.dart.dev/dev/2.19.0-430.0.dev/dart-core/CyclicInitializationError-class.html
[`BidirectionalIterator`]: https://api.dart.dev/dev/2.19.0-430.0.dev/dart-core/BidirectionalIterator-class.html

#### `dart:async`

- Added extension member `wait` on iterables and 2-9 tuples of futures.

- **Breaking change** [#49529][]:
  - Removed the deprecated [`DeferredLibrary`][] class.
    Use the [`deferred as`][] import syntax instead.

[#49529]: https://github.com/dart-lang/sdk/issues/49529
[`DeferredLibrary`]: https://api.dart.dev/stable/2.18.4/dart-async/DeferredLibrary-class.html
[`deferred as`]: https://dart.dev/language/libraries#deferred-loading

#### `dart:collection`

- Added extension members `nonNulls`, `firstOrNull`, `lastOrNull`,
  `singleOrNull`, `elementAtOrNull` and `indexed` on `Iterable`s.
  Also exported from `dart:core`.
- Deprecated the `HasNextIterator` class ([#50883][]).

- **Breaking change when migrating code to Dart 3.0**:
  Some changes to platform libraries only affect code when it is migrated
  to language version 3.0.
  - The following interface can no longer be extended, only implemented:
    * `Queue`
  - The following implementation classes can no longer be implemented:
    * `LinkedList`
    * `LinkedListEntry`
  - The following implementation classes can no longer be implemented
    or extended:
    * `HasNextIterator` (Also deprecated.)
    * `HashMap`
    * `LinkedHashMap`
    * `HashSet`
    * `LinkedHashSet`
    * `DoubleLinkedQueue`
    * `ListQueue`
    * `SplayTreeMap`
    * `SplayTreeSet`

[#50883]: https://github.com/dart-lang/sdk/issues/50883

#### `dart:developer`

- **Breaking change** [#49529][]:
  - Removed the deprecated [`MAX_USER_TAGS`][] constant.
    Use [`maxUserTags`][] instead.
- Callbacks passed to `registerExtension` will be run in the zone from which
  they are registered.

- **Breaking change** [#50231][]:
  - Removed the deprecated [`Metrics`][], [`Metric`][], [`Counter`][],
    and [`Gauge`][] classes as they have been broken since Dart 2.0.

[#49529]: https://github.com/dart-lang/sdk/issues/49529
[#50231]: https://github.com/dart-lang/sdk/issues/50231
[`MAX_USER_TAGS`]: https://api.dart.dev/stable/2.19.6/dart-developer/UserTag/MAX_USER_TAGS-constant.html
[`maxUserTags`]: https://api.dart.dev/beta/2.19.0-255.2.beta/dart-developer/UserTag/maxUserTags-constant.html
[`Metrics`]: https://api.dart.dev/stable/2.18.2/dart-developer/Metrics-class.html
[`Metric`]: https://api.dart.dev/stable/2.18.2/dart-developer/Metric-class.html
[`Counter`]: https://api.dart.dev/stable/2.18.2/dart-developer/Counter-class.html
[`Gauge`]: https://api.dart.dev/stable/2.18.2/dart-developer/Gauge-class.html

#### `dart:ffi`

- The experimental `@FfiNative` annotation is now deprecated.
  Usages should be replaced with the new `@Native` annotation.

#### `dart:html`

- **Breaking change**: As previously announced, the deprecated `registerElement`
  and `registerElement2` methods in `Document` and `HtmlDocument` have been
  removed.  See [#49536](https://github.com/dart-lang/sdk/issues/49536) for
  details.

#### `dart:math`

- **Breaking change when migrating code to Dart 3.0**:
  Some changes to platform libraries only affect code when it is migrated
  to language version 3.0.
  - The `Random` interface can only be implemented, not extended.

#### `dart:io`

- Added `name` and `signalNumber` to the `ProcessSignal` class.
- Deprecate `NetworkInterface.listSupported`. Has always returned true since
  Dart 2.3.
- Finalize `httpEnableTimelineLogging` parameter name transition from `enable`
  to `enabled`. See [#43638][].
- Favor IPv4 connections over IPv6 when connecting sockets. See
  [#50868].
- **Breaking change** [#51035][]:
  - Update `NetworkProfiling` to accommodate new `String` ids
    that are introduced in vm_service:11.0.0

[#43638]: https://github.com/dart-lang/sdk/issues/43638
[#50868]: https://github.com/dart-lang/sdk/issues/50868
[#51035]: https://github.com/dart-lang/sdk/issues/51035

#### `dart:js_util`

- Added several helper functions to access more JavaScript operators, like
  `delete` and the `typeof` functionality.
- `jsify` is now permissive and has inverse semantics to `dartify`.
- `jsify` and `dartify` both handle types they understand natively more
  efficiently.
- Signature of `callMethod` has been aligned with the other methods and
  now takes `Object` instead of `String`.

### Tools

#### Observatory
- Observatory is no longer served by default and users should instead use Dart
  DevTools. Users requiring specific functionality in Observatory should set
  the `--serve-observatory` flag.

#### Web Dev Compiler (DDC)
- Removed deprecated command line flags `-k`, `--kernel`, and `--dart-sdk`.
- The compile time flag `--nativeNonNullAsserts`, which ensures web library APIs
are sound in their nullability, is by default set to true in sound mode. For
more information on the flag, see [NATIVE_NULL_ASSERTIONS.md][].

[NATIVE_NULL_ASSERTIONS.md]: https://github.com/dart-lang/sdk/blob/main/sdk/lib/html/doc/NATIVE_NULL_ASSERTIONS.md

#### dart2js
- The compile time flag `--native-null-assertions`, which ensures web library
APIs are sound in their nullability, is by default set to true in sound mode,
unless `-O3` or higher is passed, in which case they are not checked. For more
information on the flag, see [NATIVE_NULL_ASSERTIONS.md][].

[NATIVE_NULL_ASSERTIONS.md]: https://github.com/dart-lang/sdk/blob/main/sdk/lib/html/doc/NATIVE_NULL_ASSERTIONS.md

#### Dart2js

- Cleanup related to [#46100](https://github.com/dart-lang/sdk/issues/46100):
  the internal dart2js snapshot fails unless it is called from a supported
  interface, such as `dart compile js`, `flutter build`, or
  `build_web_compilers`. This is not expected to be a visible change.

#### Formatter

* Format `sync*` and `async*` functions with `=>` bodies.
* Don't split after `<` in collection literals.
* Better indentation of multiline function types inside type argument lists.
* Fix bug where parameter metadata wouldn't always split when it should.

#### Analyzer

- Most static analysis "hints" are converted to be "warnings," and any
  remaining hints are intended to be converted soon after the Dart 3.0 release.
  This means that any (previously) hints reported by `dart analyze` are now
  considered "fatal" (will result in a non-zero exit code). The previous
  behavior, where such hints (now warnings) are not fatal, can be achieved by
  using the `--no-fatal-warnings` flag. This behavior can also be altered, on a
  code-by-code basis, by [changing the severity of rules] in an analysis
  options file.
- Add static enforcement of the SDK-only `@Since` annotation. When code in a
  package uses a Dart SDK element annotated with `@Since`, analyzer will report
  a warning if the package's [Dart SDK constraint] allows versions of Dart
  which don't include that element.
- Protects the Dart Analysis Server against extreme memory usage by limiting
  the number of plugins per analysis context to 1. (issue [#50981][]).

[changing the severity of rules]: https://dart.dev/tools/analysis#changing-the-severity-of-rules
[Dart SDK constraint]: https://dart.dev/tools/pub/pubspec#sdk-constraints

#### Linter

Updates the Linter to `1.35.0`, which includes changes that

- add new lints:
  - `implicit_reopen`
  - `unnecessary_breaks`
  - `type_literal_in_constant_pattern`
  - `invalid_case_patterns`
- update existing lints to support patterns and class modifiers
- remove support for:
  - `enable_null_safety`
  - `invariant_booleans`
  - `prefer_bool_in_asserts`
  - `prefer_equal_for_default_values`
  - `super_goes_last`
- fix `unnecessary_parenthesis` false-positives with null-aware expressions.
- fix `void_checks` to allow assignments of `Future<dynamic>?` to parameters
  typed `FutureOr<void>?`.
- fix `use_build_context_synchronously` in if conditions.
- fix a false positive for `avoid_private_typedef_functions` with generalized
  type aliases.
- update `unnecessary_parenthesis` to detect some doubled parens.
- update `void_checks` to allow returning `Never` as void.
- update `no_adjacent_strings_in_list` to support set literals and for- and
  if-elements.
- update `avoid_types_as_parameter_names` to handle type variables.
- update `avoid_positional_boolean_parameters` to handle typedefs.
- update `avoid_redundant_argument_values` to check parameters of redirecting
  constructors.
- improve performance for `prefer_const_literals_to_create_immutables`.
- update `use_build_context_synchronously` to check context properties.
- improve `unnecessary_parenthesis` support for property accesses and method
  invocations.
- update `unnecessary_parenthesis` to allow parentheses in more null-aware
  cascade contexts.
- update `unreachable_from_main` to track static elements.
- update `unnecessary_null_checks` to not report on arguments passed to
  `Future.value` or `Completer.complete`.
- mark `always_use_package_imports` and `prefer_relative_imports` as
  incompatible rules.
- update `only_throw_errors` to not report on `Never`-typed expressions.
- update `unnecessary_lambdas` to not report with `late final` variables.
- update `avoid_function_literals_in_foreach_calls` to not report with nullable-
  typed targets.
- add new lint: `deprecated_member_use_from_same_package` which replaces the
  soft-deprecated analyzer hint of the same name.
- update `public_member_api_docs` to not require docs on enum constructors.
- update `prefer_void_to_null` to not report on as-expressions.

#### Migration tool removal

The null safety migration tool (`dart migrate`) has been removed.  If you still
have code which needs to be migrated to null safety, please run `dart migrate`
using Dart version 2.19, before upgrading to Dart version 3.0.

#### Pub

- To preserve compatibility with null-safe code pre Dart 3, Pub will interpret a
  language constraint indicating a language version of `2.12` or higher and an
  upper bound of `<3.0.0` as `<4.0.0`.

  For example `>=2.19.2 <3.0.0` will be interpreted as `>=2.19.2 <4.0.0`.
- `dart pub publish` will no longer warn about `dependency_overrides`. Dependency
  overrides only take effect in the root package of a resolution.
- `dart pub token add` now verifies that the given token is valid for including
  in a header according to [RFC 6750 section
  2.1](https://www.rfc-editor.org/rfc/rfc6750#section-2.1). This means they must
  contain only the characters: `^[a-zA-Z0-9._~+/=-]+$`. Before a failure would
  happen when attempting to send the authorization header.
- `dart pub get` and related commands will now by default also update the
  dependencies in the `example` folder (if it exists). Use `--no-example` to
  avoid this.
- On Windows the `PUB_CACHE` has moved to `%LOCALAPPDATA%`, since Dart 2.8 the
  `PUB_CACHE` has been created in `%LOCALAPPDATA%` when one wasn't present.
  Hence, this only affects users with a `PUB_CACHE` created by Dart 2.7 or
  earlier. If you have `path/to/.pub-cache/bin` in `PATH` you may need to
  update your `PATH`.
