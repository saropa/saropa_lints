// ignore_for_file: unused_local_variable, unused_element, unused_field
// ignore_for_file: depend_on_referenced_packages, prefer_const_constructors
// ignore_for_file: undefined_class, undefined_identifier, undefined_getter
// ignore_for_file: undefined_method, undefined_named_parameter
// ignore_for_file: non_type_as_type_argument, annotate_overrides
// ignore_for_file: body_might_complete_normally, missing_required_argument
// ignore_for_file: argument_type_not_assignable, return_of_invalid_type
// ignore_for_file: avoid_unused_constructor_parameters
// ignore_for_file: non_constant_identifier_names, constant_identifier_names

/// Fixture for `prefer_static_final_for_session_constant`.
///
/// LINT cases: compound arithmetic in build() whose every operand is
/// session-constant (token getter + literal, token getter + static const,
/// two token getters). NO-lint cases: anything that depends on a volatile
/// input (context, widget.*, parameter, local), a bare single getter, or an
/// expression already evaluated once (static field initializer / initState).
import 'package:saropa_lints_example/flutter_mocks.dart';

// Mock design-token enum: `ThemeCommonSpace.Footer.size` is a runtime getter
// (a static-final cache resolved once per session), NOT a compile-time const.
enum ThemeCommonSpace {
  Small,
  Medium,
  Footer;

  double get size => 8;
}

enum ThemeCommonSize {
  Small,
  Large;

  double get size => 16;
}

// Top-level const (Flutter k-convention) used in a LINT case.
const double kBottomNavigationBarHeight = 56;

class _BadState extends State {
  // static const field — session-constant.
  static const double _kCard = 198;

  @override
  Widget build(BuildContext context) {
    // LINT — token getter * literal, fully session-constant.
    // expect_lint: prefer_static_final_for_session_constant
    final double pad = ThemeCommonSpace.Footer.size * 2;

    // LINT — static const field + token getter.
    // expect_lint: prefer_static_final_for_session_constant
    final double h = _kCard + ThemeCommonSpace.Medium.size * 2;

    // LINT — two token getters combined.
    // expect_lint: prefer_static_final_for_session_constant
    final double box = ThemeCommonSize.Small.size + ThemeCommonSpace.Small.size;

    // LINT — top-level const + token getter.
    // expect_lint: prefer_static_final_for_session_constant
    final double bar =
        kBottomNavigationBarHeight + ThemeCommonSpace.Medium.size;

    return SizedBox(height: h + box + pad + bar);
  }
}

class _DuplicateState extends State {
  @override
  Widget build(BuildContext context) {
    // LINT — same session-constant expression computed twice in one class.
    // expect_lint: prefer_static_final_for_session_constant
    final double a = ThemeCommonSize.Small.size + ThemeCommonSpace.Small.size;
    // expect_lint: prefer_static_final_for_session_constant
    final double b = ThemeCommonSize.Small.size + ThemeCommonSpace.Small.size;
    return SizedBox(height: a + b);
  }
}

class _GoodState extends State {
  // OK — already computed once in a static initializer.
  static final double _bottom = ThemeCommonSpace.Footer.size * 2;

  @override
  void initState() {
    // OK — initState runs once, not per rebuild.
    final double once = ThemeCommonSpace.Footer.size * 2;
  }

  @override
  Widget build(BuildContext context) {
    // OK — depends on context (MediaQuery); changes with viewport.
    final double safe = MediaQuery.viewPaddingOf(context).bottom + 20;

    // OK — depends on widget.* (volatile across rebuilds).
    final double w = widget.gap + ThemeCommonSpace.Small.size;

    // OK — depends on a method parameter / local, not session-constant.
    final double scaled = widget.sizeCommon.size * 1.4;

    // OK — single bare token getter, no arithmetic (criterion 2).
    final double m = ThemeCommonSpace.Medium.size;

    // OK — uses the hoisted static field.
    return SizedBox(height: _bottom + safe + w + scaled + m);
  }
}
