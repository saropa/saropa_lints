// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: depend_on_referenced_packages
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_import, unused_import
// ignore_for_file: avoid_unused_constructor_parameters
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
// ignore_for_file: override_on_non_overriding_member
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
// Test fixture for: prefer_value_listenable_builder
// Source: lib\src\rules\performance_rules.dart

import 'package:saropa_lints_example/flutter_mocks.dart';

dynamic builder;
dynamic child;
final context = BuildContext();
dynamic value;

// BAD: Should trigger prefer_value_listenable_builder
// expect_lint: prefer_value_listenable_builder
class _bad790__MyState extends State<MyWidget> {
  int _counter = 0;

  void _inc() => setState(() => _counter++);

  Widget build(BuildContext context) {
    return Text('$_counter');
  }
}

// GOOD: single Future field backing a FutureBuilder. setState invalidates the
// cache to re-fetch; ValueListenableBuilder cannot express this, so no lint.
class _good790FutureCacheState extends State<MyWidget> {
  Future<int>? _future;

  void _refresh() => setState(() => _future = null);

  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _future ??= _load(),
      builder: (context, snapshot) => Text('${snapshot.data}'),
    );
  }

  Future<int> _load() async => 0;
}

// GOOD: single Stream field backing a StreamBuilder. Same idiom as above.
class _good790StreamCacheState extends State<MyWidget> {
  Stream<int>? _stream;

  void _refresh() => setState(() => _stream = null);

  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _stream ??= _load(),
      builder: (context, snapshot) => Text('${snapshot.data}'),
    );
  }

  Stream<int> _load() async* {
    yield 0;
  }
}

// GOOD: one non-final field (_filtered) PLUS a `final` List mutated in place
// (_selected.add/remove) and republished via setState. That is two independent
// states; a single ValueListenableBuilder cannot express both, so no lint.
// See bugs/prefer_value_listenable_builder_false_positive_inplace_mutation_
// final_collection.md.
class _good790InPlaceListState extends State<MyWidget> {
  List<int> _filtered = <int>[];
  late final List<int> _selected = <int>[];

  void _onSearch() => setState(() => _filtered = <int>[1]);
  void _toggle(int v) => setState(() {
    _selected.contains(v) ? _selected.remove(v) : _selected.add(v);
  });

  Widget build(BuildContext context) {
    return Text('${_filtered.length}/${_selected.length}');
  }
}

// GOOD: one non-final field plus a `final` Map index-assigned (m[k] = v) inside
// setState — the map is a second state, so no lint.
class _good790IndexAssignMapState extends State<MyWidget> {
  int _counter = 0;
  final Map<int, int> _tally = <int, int>{};

  void _inc() => setState(() => _counter++);
  void _record(int k) => setState(() => _tally[k] = _counter);

  Widget build(BuildContext context) {
    return Text('$_counter/${_tally.length}');
  }
}

// BAD: one non-final field with two setState calls that only REASSIGN it (the
// `final` list is read, never mutated) — genuine single-value state, so it
// still fires. Confirms the new guard does not over-suppress.
// expect_lint: prefer_value_listenable_builder
class _bad790ReadOnlyFinalState extends State<MyWidget> {
  int _counter = 0;
  final List<int> _history = <int>[];

  void _inc() => setState(() => _counter = _history.length);
  void _reset() => setState(() => _counter = 0);

  Widget build(BuildContext context) {
    return Text('$_counter');
  }
}

// GOOD: cached Future + a non-Future cache-key companion field, with one
// setState that re-inits the futures via a tear-off. The key (_lastKeys) is
// mutated only in plain helpers, never via `setState(() => field = x)`, so it
// is not the synchronous display value the rule targets. ValueListenableBuilder
// cannot re-run an async fetch, so no lint. See bugs/prefer_value_listenable_
// builder_false_positive_future_cache_key_companion_field.md.
class _good790FutureCacheKeyState extends State<MyWidget> {
  late Future<List<int>?> _primaryFuture;
  Future<List<String>?>? _secondaryFuture;
  List<int>? _lastKeys;

  void _initFutures() {
    _primaryFuture = _fetchPrimary();
    _secondaryFuture = null;
    _lastKeys = null;
  }

  void refresh() {
    if (mounted) {
      setState(_initFutures);
    }
  }

  Future<List<String>?> _cachedSecondary(List<int>? keys) {
    final bool changed =
        _secondaryFuture == null || keys?.length != _lastKeys?.length;
    if (changed) {
      _lastKeys = keys;
      _secondaryFuture = _fetchSecondary(keys);
    }
    return _secondaryFuture!;
  }

  Future<List<int>?> _fetchPrimary() async => <int>[];
  Future<List<String>?> _fetchSecondary(List<int>? keys) async => <String>[];

  Widget build(BuildContext context) {
    return FutureBuilder<List<int>?>(
      future: _primaryFuture,
      builder: (context, snapshot) => const SizedBox(),
    );
  }
}

// GOOD: a single non-Future field mutated ONLY outside setState (no Future
// fields). Nothing drives a rebuild through it via setState, so it is not the
// single-value display state the rule targets — no lint.
class _good790OutsideSetStateState extends State<MyWidget> {
  int _cacheKey = 0;

  void _warm() => _cacheKey = 1;

  Widget build(BuildContext context) {
    return Text('$_cacheKey');
  }
}

// BAD: a single non-Future field reassigned inside setState and no Future
// fields — genuine single-value state, so it still fires. Confirms the
// reassigned-in-setState guard does not over-suppress.
// expect_lint: prefer_value_listenable_builder
class _bad790AssignedInSetStateState extends State<MyWidget> {
  int _value = 0;

  void _set(int v) => setState(() => _value = v);

  Widget build(BuildContext context) {
    return Text('$_value');
  }
}

// GOOD: one non-final field assigned in setState PLUS a `final`
// TextEditingController whose search state is republished by a BARE
// `setState(() {})` (no field assignment). The bare rebuild signals a second,
// controller-backed state a single ValueListenableBuilder cannot model, so no
// lint. See bugs/prefer_value_listenable_builder_false_positive_controller_
// backed_state_bare_setstate.md.
class _good790ControllerBackedBareSetStateState extends State<MyWidget> {
  final TextEditingController _textController = TextEditingController();
  int? _lastScanSummary;

  void _onScan(int s) => setState(() => _lastScanSummary = s);
  void _onSearch() => setState(() {});

  Widget build(BuildContext context) {
    return Text('$_lastScanSummary/${_textController.text}');
  }
}

// GOOD: same shape via the common safe-setState wrapper. The literal
// `setState(() => cb?.call())` assigns no field, so it is bare and bails the
// same way — covering the wrapper indirection from the bug's real-world file.
class _good790SafeSetStateWrapperState extends State<MyWidget> {
  final TextEditingController _textController = TextEditingController();
  int? _lastScanSummary;

  void _setStateSafe([void Function()? cb]) {
    if (mounted) setState(() => cb?.call());
  }

  void _onScan(int s) => _setStateSafe(() => _lastScanSummary = s);
  void _onSearch() => _setStateSafe();

  Widget build(BuildContext context) {
    return Text('$_lastScanSummary/${_textController.text}');
  }
}

// GOOD: Should NOT trigger prefer_value_listenable_builder
void _good790() {
  final _counter = ValueNotifier<int>(0);

  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _counter,
      builder: (context, value, child) => Text('$value'),
    );
  }
}
