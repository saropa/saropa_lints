// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: depend_on_referenced_packages
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_import, unused_import
// ignore_for_file: avoid_unused_constructor_parameters_skip_private
// ignore_for_file: override_on_non_overriding_member
// ignore_for_file: annotate_overrides, duplicate_ignore
// ignore_for_file: non_abstract_class_inherits_abstract_member
// ignore_for_file: extends_non_class, mixin_of_non_class
// ignore_for_file: field_initializer_outside_constructor
// ignore_for_file: final_not_initialized
// ignore_for_file: super_in_invalid_context
// ignore_for_file: concrete_class_with_abstract_member
// ignore_for_file: type_argument_not_matching_bounds
// ignore_for_file: missing_required_argument
// ignore_for_file: undefined_named_parameter
// ignore_for_file: argument_type_not_assignable
// ignore_for_file: invalid_constructor_name
// ignore_for_file: super_formal_parameter_without_associated_named
// ignore_for_file: undefined_annotation, creation_with_non_type
// ignore_for_file: invalid_factory_name_not_a_class
// ignore_for_file: invalid_reference_to_this
// ignore_for_file: expected_class_member
// ignore_for_file: body_might_complete_normally
// ignore_for_file: not_initialized_non_nullable_instance_field
// ignore_for_file: unchecked_use_of_nullable_value
// ignore_for_file: return_of_invalid_type
// ignore_for_file: use_of_void_result
// ignore_for_file: missing_function_body
// ignore_for_file: extra_positional_arguments
// ignore_for_file: not_enough_positional_arguments
// ignore_for_file: unused_label
// ignore_for_file: unused_element_parameter
// ignore_for_file: non_type_as_type_argument
// ignore_for_file: expected_identifier_but_got_keyword
// ignore_for_file: expected_token, missing_identifier
// ignore_for_file: unexpected_token
// ignore_for_file: duplicate_definition
// ignore_for_file: extends_non_class
// ignore_for_file: no_default_super_constructor
// ignore_for_file: extra_positional_arguments_could_be_named
// ignore_for_file: missing_function_parameters
// ignore_for_file: invalid_annotation, invalid_assignment
// ignore_for_file: expected_executable
// ignore_for_file: named_parameter_outside_group
// ignore_for_file: obsolete_colon_for_default_value
// ignore_for_file: referenced_before_declaration
// ignore_for_file: await_in_wrong_context
// ignore_for_file: non_type_in_catch_clause
// ignore_for_file: could_not_infer
// ignore_for_file: uri_does_not_exist
// ignore_for_file: const_method
// ignore_for_file: redirect_to_non_class
// ignore_for_file: unused_catch_clause
// ignore_for_file: type_test_with_undefined_name
// ignore_for_file: undefined_identifier, undefined_function
// ignore_for_file: undefined_method, undefined_getter
// ignore_for_file: undefined_setter, undefined_class
// ignore_for_file: undefined_super_member
// ignore_for_file: extraneous_modifier
// ignore_for_file: experiment_not_enabled
// ignore_for_file: missing_const_final_var_or_type
// ignore_for_file: undefined_operator, dead_code
// ignore_for_file: invalid_override
// ignore_for_file: not_initialized_non_nullable_variable
// ignore_for_file: list_element_type_not_assignable
// ignore_for_file: assignment_to_final
// ignore_for_file: equal_elements_in_set
// ignore_for_file: prefix_shadowed_by_local_declaration
// ignore_for_file: const_initialized_with_non_constant_value
// ignore_for_file: non_constant_list_element
// ignore_for_file: missing_statement
// ignore_for_file: unnecessary_cast, unnecessary_null_comparison
// ignore_for_file: unnecessary_type_check
// ignore_for_file: invalid_super_formal_parameter_location
// ignore_for_file: assignment_to_type
// ignore_for_file: instance_member_access_from_factory
// ignore_for_file: field_initializer_not_assignable
// ignore_for_file: constant_pattern_with_non_constant_expression
// ignore_for_file: undefined_identifier_await, cast_to_non_type
// ignore_for_file: read_potentially_unassigned_final
// ignore_for_file: mixin_with_non_class_superclass
// ignore_for_file: instantiate_abstract_class
// ignore_for_file: dead_code_on_catch_subtype, unreachable_switch_case
// ignore_for_file: new_with_undefined_constructor
// ignore_for_file: assignment_to_final_local
// ignore_for_file: late_final_local_already_assigned
// ignore_for_file: missing_default_value_for_parameter
// ignore_for_file: non_bool_condition
// ignore_for_file: non_exhaustive_switch_expression
// ignore_for_file: illegal_async_return_type
// ignore_for_file: type_test_with_non_type
// ignore_for_file: invocation_of_non_function_expression
// ignore_for_file: return_of_invalid_type_from_closure
// ignore_for_file: wrong_number_of_type_arguments_constructor
// ignore_for_file: definitely_unassigned_late_local_variable
// ignore_for_file: static_access_to_instance_member
// ignore_for_file: const_with_undefined_constructor
// ignore_for_file: abstract_super_member_reference
// ignore_for_file: equal_keys_in_map, unused_catch_stack
// ignore_for_file: non_constant_default_value, not_a_type
// Test fixture for: never_discard_build_context
// Source: lib\src\rules\widget\never_discard_build_context_rules.dart
//
// NOTE: `never_discard_build_context` sets `requiresFlutterImport`, which
// gates on the literal substring `package:flutter/` appearing anywhere in
// the file content — the fixture package has no real Flutter dependency, so
// this comment (rather than a real import) satisfies that gate while the
// actual Widget/BuildContext/etc. types below still resolve against the
// local mocks: import 'package:flutter/widgets.dart';

import 'package:saropa_lints_example/flutter_mocks.dart';

// BAD: the `Builder` callback declares `innerContext` but its body reads the
// outer `context` captured from `build()` instead — the InheritedWidget
// lookup (Theme.of) resolves against the WRONG scope.
class _BadBuilderState extends State<StatefulWidget> {
  @override
  Widget build(BuildContext context) {
    return Builder(
      // expect_lint: never_discard_build_context
      builder: (BuildContext innerContext) {
        return Text('${Theme.of(context)}');
      },
    );
  }
}

// GOOD: uses the builder-supplied context, so the InheritedWidget lookup
// resolves against the correct scope.
class _GoodBuilderState extends State<StatefulWidget> {
  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (BuildContext innerContext) {
        return Text('${Theme.of(innerContext)}');
      },
    );
  }
}

// BAD: LayoutBuilder — the second parameter (constraints) is used, but the
// first (context) is never read. Using an extra param does not excuse
// ignoring context.
class _BadLayoutBuilderState extends State<StatefulWidget> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      // expect_lint: never_discard_build_context
      builder: (BuildContext ctx, BoxConstraints constraints) {
        return SizedBox(width: constraints.maxWidth);
      },
    );
  }
}

// GOOD: LayoutBuilder reading its own context.
class _GoodLayoutBuilderState extends State<StatefulWidget> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints constraints) {
        return Text('${Theme.of(ctx)}', textDirection: TextDirection.ltr);
      },
    );
  }
}

// GOOD: parameter explicitly renamed to `_` to mark it as intentionally
// unused — the rule's documented escape hatch (proposal edge case 1).
class _UnderscoreEscapeHatchState extends State<StatefulWidget> {
  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (BuildContext _) {
        return const SizedBox();
      },
    );
  }
}

// GOOD near-miss: untyped `builder:` parameter (relying on inference) that
// IS read in the body — must not be flagged just because it lacks an
// explicit `BuildContext` type annotation.
class _UntypedUsedState extends State<StatefulWidget> {
  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (ctx) {
        return Text('${Theme.of(ctx)}');
      },
    );
  }
}

// BAD: untyped `builder:` parameter using a conventional context name
// (`ctx`) that is never read — the allow-list of untyped names still
// catches unused params without an explicit type annotation.
class _UntypedUnusedState extends State<StatefulWidget> {
  @override
  Widget build(BuildContext context) {
    return Builder(
      // expect_lint: never_discard_build_context
      builder: (ctx) {
        return Text('${Theme.of(context)}');
      },
    );
  }
}

// GOOD near-miss: FutureBuilder's `snapshot` parameter is unrelated to the
// context-discard check — only the FIRST parameter (context) is examined,
// so an unused `snapshot` must never trigger this rule.
class _GoodFutureBuilderState extends State<StatefulWidget> {
  Future<String>? _future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _future,
      builder: (BuildContext ctx, AsyncSnapshot<String> snapshot) {
        return Text('${Theme.of(ctx)}');
      },
    );
  }
}

// GOOD: the builder-scoped context is read inside a nested `onPressed`
// closure rather than directly in the builder body. This is one of the most
// common real-world uses of a builder context — deferring a
// Navigator/ScaffoldMessenger call to a button callback — and must not be
// flagged just because the read happens one closure deeper.
class _GoodNestedOnPressedState extends State<StatefulWidget> {
  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (BuildContext ctx) {
        return ElevatedButton(
          onPressed: () {
            Navigator.of(ctx).pop();
          },
          child: const Text('Close'),
        );
      },
    );
  }
}

// GOOD: the builder-scoped context is read inside a `Future.then` callback
// nested in the builder body — still a genuine use of the outer context.
class _GoodNestedThenState extends State<StatefulWidget> {
  Future<void>? _pending;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (BuildContext ctx) {
        _pending?.then((_) {
          Navigator.of(ctx).pop();
        });
        return const SizedBox();
      },
    );
  }
}

// GOOD: the builder-scoped context is read inside a locally-declared named
// function (a `FunctionDeclarationStatement`, not a closure literal) — the
// same "context used one level deeper" pattern via different syntax.
class _GoodNestedLocalFunctionState extends State<StatefulWidget> {
  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (BuildContext ctx) {
        void handleTap() {
          Navigator.of(ctx).pop();
        }

        return ElevatedButton(onPressed: handleTap, child: const Text('Go'));
      },
    );
  }
}
