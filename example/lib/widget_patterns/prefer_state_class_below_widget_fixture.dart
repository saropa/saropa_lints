// ignore_for_file: unused_element, unused_field
// ignore_for_file: non_abstract_class_inherits_abstract_member
// ignore_for_file: extends_non_class, mixin_of_non_class
// ignore_for_file: body_might_complete_normally
// ignore_for_file: missing_required_argument

import 'package:saropa_lints_example/flutter_mocks.dart';

/// Minimal local mock for Riverpod's `ConsumerState<T>`. `flutter_mocks.dart`
/// already provides `ConsumerStatefulWidget`, but not its paired `State<T>`
/// subclass, so it is declared here rather than in the shared mocks file
/// (kept local since only this fixture exercises the third-party pairing).
abstract class ConsumerState<T extends StatefulWidget> extends State<T> {}

/// Fixture for `prefer_state_class_below_widget` lint rule.

// BAD: State class declared ABOVE its StatefulWidget — inverted reading order.
// expect_lint: prefer_state_class_below_widget
class _BadCounterState extends State<BadCounter> {
  int _count = 0;

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

class BadCounter extends StatefulWidget {
  const BadCounter({super.key});

  @override
  State<BadCounter> createState() => _BadCounterState();
}

// GOOD: StatefulWidget declared first, State below — correct reading order.
class GoodCounter extends StatefulWidget {
  const GoodCounter({super.key});

  @override
  State<GoodCounter> createState() => _GoodCounterState();
}

class _GoodCounterState extends State<GoodCounter> {
  int _count = 0;

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

// GOOD: Multiple widget/state pairs, each correctly ordered and interleaved.
class GoodWidgetA extends StatefulWidget {
  const GoodWidgetA({super.key});

  @override
  State<GoodWidgetA> createState() => _GoodWidgetAState();
}

class _GoodWidgetAState extends State<GoodWidgetA> {
  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

class GoodWidgetB extends StatefulWidget {
  const GoodWidgetB({super.key});

  @override
  State<GoodWidgetB> createState() => _GoodWidgetBState();
}

class _GoodWidgetBState extends State<GoodWidgetB> {
  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

// GOOD: Bare `State` with no type argument — no widget name to correlate,
// so no ordering constraint applies.
class _BareState extends State {
  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

// BAD: third-party pair — ConsumerState declared ABOVE its
// ConsumerStatefulWidget, same inverted-order violation as core Flutter's
// State/StatefulWidget.
// expect_lint: prefer_state_class_below_widget
class _BadConsumerCounterState extends ConsumerState<BadConsumerCounter> {
  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

class BadConsumerCounter extends ConsumerStatefulWidget {
  const BadConsumerCounter({super.key});

  @override
  ConsumerState<BadConsumerCounter> createState() => _BadConsumerCounterState();
}

// GOOD: third-party pair — ConsumerStatefulWidget declared first, its
// ConsumerState below — correct reading order.
class GoodConsumerCounter extends ConsumerStatefulWidget {
  const GoodConsumerCounter({super.key});

  @override
  ConsumerState<GoodConsumerCounter> createState() =>
      _GoodConsumerCounterState();
}

class _GoodConsumerCounterState extends ConsumerState<GoodConsumerCounter> {
  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}
