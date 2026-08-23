// ignore_for_file: unused_element, unused_field

/// Fixture for `prefer_primary_constructor` lint rule.
/// Quick fix: Rewrite class using primary constructor syntax.
///
/// NOTE: This rule only fires when pubspec.yaml declares sdk: >=3.13.0.
/// The example project's pubspec must satisfy that constraint for these
/// expect_lint markers to trigger.

// ---------------------------------------------------------------------------
// BAD: Simple class with two final fields — expect LINT
// ---------------------------------------------------------------------------

// expect_lint: prefer_primary_constructor
class SimplePoint {
  SimplePoint(this.x, this.y);

  final double x;
  final double y;
}

// ---------------------------------------------------------------------------
// BAD: Class with const constructor and final fields — expect LINT
// ---------------------------------------------------------------------------

// expect_lint: prefer_primary_constructor
class ConstConfig {
  const ConstConfig(this.host, this.port);

  final String host;
  final int port;
}

// ---------------------------------------------------------------------------
// BAD: Class with named parameters — expect LINT
// ---------------------------------------------------------------------------

// expect_lint: prefer_primary_constructor
class UserProfile {
  const UserProfile({required this.id, required this.displayName});

  final String id;
  final String displayName;
}

// ---------------------------------------------------------------------------
// BAD: Class with optional parameters and defaults — expect LINT
// ---------------------------------------------------------------------------

// expect_lint: prefer_primary_constructor
class Settings {
  Settings({this.timeout = 30, this.retries = 3});

  final int timeout;
  final int retries;
}

// ---------------------------------------------------------------------------
// GOOD: Class extending another class — no lint
// ---------------------------------------------------------------------------

class _Base {
  const _Base();
}

class ExtendsAnother extends _Base {
  const ExtendsAnother(this.value);

  final String value;
}

// ---------------------------------------------------------------------------
// GOOD: Class with initializer list — no lint
// ---------------------------------------------------------------------------

class WithInitializer {
  WithInitializer(this.value) : doubled = value * 2;

  final int value;
  final int doubled;
}

// ---------------------------------------------------------------------------
// GOOD: Class with constructor body — no lint
// ---------------------------------------------------------------------------

class WithBody {
  WithBody(this.raw) {
    // ignore: avoid_print
    print('created');
  }

  final String raw;
}

// ---------------------------------------------------------------------------
// GOOD: Class with factory constructor — no lint
// ---------------------------------------------------------------------------

class WithFactory {
  WithFactory(this.data);

  factory WithFactory.empty() => WithFactory('');

  final String data;
}

// ---------------------------------------------------------------------------
// GOOD: Class with non-final fields — no lint
// ---------------------------------------------------------------------------

class MutableFields {
  MutableFields(this.counter);

  int counter;
}

// ---------------------------------------------------------------------------
// GOOD: Class with fields not in constructor — no lint
// ---------------------------------------------------------------------------

class ExtraField {
  ExtraField(this.name);

  final String name;
  final String tag = 'default';
}

// ---------------------------------------------------------------------------
// GOOD: Widget subclass — no lint (extends StatelessWidget)
// ---------------------------------------------------------------------------

// Simulating a Widget hierarchy without depending on Flutter:
// The rule checks `node.extendsClause != null` which covers any extends.
class _StatelessWidget {
  const _StatelessWidget();
}

class MyWidget extends _StatelessWidget {
  const MyWidget(this.title);

  final String title;
}

// ---------------------------------------------------------------------------
// GOOD: Mixin class — no lint
// ---------------------------------------------------------------------------

mixin class MixinClass {
  MixinClass(this.value);

  final int value;
}

// ---------------------------------------------------------------------------
// GOOD: Extension type — no lint (already uses primary constructors)
// ---------------------------------------------------------------------------

extension type const Wrapper(int value) implements int {}

// ---------------------------------------------------------------------------
// GOOD: Class with multiple constructors — no lint
// ---------------------------------------------------------------------------

class MultipleCtors {
  MultipleCtors(this.label);

  MultipleCtors.named(String prefix) : label = '$prefix-default';

  final String label;
}

// ---------------------------------------------------------------------------
// GOOD: Empty class with no fields — no lint
// ---------------------------------------------------------------------------

class EmptyClass {
  EmptyClass();
}

// ---------------------------------------------------------------------------
// GOOD: Class with a `late final` field — no lint (no primary-ctor
// equivalent for `late`; excluded even though the field is final)
// ---------------------------------------------------------------------------

class WithLateFinal {
  WithLateFinal(this.value);

  late final int value;
}

// ---------------------------------------------------------------------------
// GOOD: Class with an annotated field — no lint (no established placement
// for an annotation on a primary-constructor parameter yet)
// ---------------------------------------------------------------------------

class WithAnnotatedField {
  WithAnnotatedField(this.value);

  @deprecated
  final int value;
}
