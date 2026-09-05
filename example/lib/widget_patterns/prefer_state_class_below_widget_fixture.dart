// ignore_for_file: unused_element, unused_field
// ignore_for_file: non_abstract_class_inherits_abstract_member
// ignore_for_file: extends_non_class, mixin_of_non_class
// ignore_for_file: body_might_complete_normally
// ignore_for_file: missing_required_argument

import 'package:saropa_lints_example/flutter_mocks.dart';

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
