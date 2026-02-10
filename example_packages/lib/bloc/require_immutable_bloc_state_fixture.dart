// ignore_for_file: unused_element, unused_field
// Test fixture for require_immutable_bloc_state rule

import 'package:saropa_lints_example/flutter_mocks.dart';

// ============================================================================
// Mock types needed for this fixture
// ============================================================================

// The file must contain a Bloc to be classified as FileType.bloc
class _TestBloc extends Bloc<Object, Object> {
  _TestBloc() : super(Object());
}

// Mock Equatable
abstract class Equatable {
  const Equatable();
  List<Object?> get props;
}

mixin EquatableMixin {
  List<Object?> get props;
}

// Mock @immutable annotation
const immutable = _Immutable();

class _Immutable {
  const _Immutable();
}

// Mock Flutter State subclasses
abstract class PopupMenuItemState<T, W extends StatefulWidget>
    extends State<W> {}

abstract class FormFieldState<T> extends State<StatefulWidget> {}

// ============================================================================
// BAD: Should trigger (actual BLoC state without immutability)
// ============================================================================

// expect_lint: require_immutable_bloc_state
class CounterState {
  int count;
  CounterState({this.count = 0});
}

// expect_lint: require_immutable_bloc_state
class AuthenticationState {
  final bool isLoggedIn;
  AuthenticationState({this.isLoggedIn = false});
}

// ============================================================================
// GOOD: Should NOT trigger (BLoC state with Equatable)
// ============================================================================

class GoodCounterState extends Equatable {
  final int count;
  const GoodCounterState({this.count = 0});
  @override
  List<Object?> get props => [count];
}

// ============================================================================
// GOOD: Should NOT trigger (BLoC state with @immutable)
// ============================================================================

@immutable
class ImmutableCounterState {
  final int count;
  const ImmutableCounterState({this.count = 0});
}

// ============================================================================
// GOOD: Should NOT trigger (BLoC state with EquatableMixin)
// ============================================================================

class MixinCounterState with EquatableMixin {
  final int count;
  MixinCounterState({this.count = 0});
  @override
  List<Object?> get props => [count];
}

// ============================================================================
// GOOD: Should NOT trigger (abstract class)
// ============================================================================

abstract class BaseState {}

// ============================================================================
// GOOD: Should NOT trigger (Flutter State subclass)
// ============================================================================

class _MyWidgetState extends State<StatefulWidget> {
  @override
  Widget build(BuildContext context) => Container();
}

// ============================================================================
// GOOD: Should NOT trigger (PopupMenuItemState — indirect State subclass)
// ============================================================================

class _MyPopupMenuState extends PopupMenuItemState<dynamic, StatefulWidget> {
  @override
  Widget build(BuildContext context) => Container();
}

// ============================================================================
// GOOD: Should NOT trigger (FormFieldState — indirect State subclass)
// ============================================================================

class _MyFormFieldState extends FormFieldState<String> {
  @override
  Widget build(BuildContext context) => Container();
}

// ============================================================================
// GOOD: Should NOT trigger (StatefulWidget whose name ends in "State")
// ============================================================================

class ButtonDeleteCountryState extends StatefulWidget {
  const ButtonDeleteCountryState({super.key});
  @override
  State<ButtonDeleteCountryState> createState() =>
      _ButtonDeleteCountryStateState();
}

class _ButtonDeleteCountryStateState extends State<ButtonDeleteCountryState> {
  @override
  Widget build(BuildContext context) => Container();
}

// ============================================================================
// GOOD: Should NOT trigger (StatelessWidget whose name ends in "State")
// ============================================================================

class DisplayOrderState extends StatelessWidget {
  const DisplayOrderState({super.key});
  @override
  Widget build(BuildContext context) => Container();
}
