// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method, use_key_in_widget_constructors

import 'package:flutter/material.dart';

/// Fixture for `require_text_editing_controller_dispose` lint rule.

// --- BAD: no dispose at all ---
// expect_lint: require_text_editing_controller_dispose
class _NoDisposeState extends State<StatefulWidget> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) => TextField(controller: _ctrl);
}

// --- BAD: cascade WITHOUT dispose ---
// expect_lint: require_text_editing_controller_dispose
class _CascadeNoDisposeState extends State<StatefulWidget> {
  final TextEditingController _ctrl = TextEditingController();

  void _onChanged() {}

  @override
  void dispose() {
    _ctrl..removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(controller: _ctrl);
}

// --- GOOD: plain dispose ---
class _PlainDisposeState extends State<StatefulWidget> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(controller: _ctrl);
}

// --- GOOD: cascade WITH dispose ---
class _CascadeDisposeState extends State<StatefulWidget> {
  final TextEditingController _searchController = TextEditingController();

  void _onSearchChanged() {}

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      TextField(controller: _searchController);
}

// --- GOOD: null-aware dispose ---
class _NullAwareDisposeState extends State<StatefulWidget> {
  TextEditingController? _ctrl;

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      TextField(controller: _ctrl ?? TextEditingController());
}
