// ignore_for_file: unused_local_variable, unused_element, unused_field
// ignore_for_file: prefer_const_constructors
// Test fixture for forms rules added in v2.3.10

import '../flutter_mocks.dart';

// =========================================================================
// require_text_input_type
// =========================================================================
// Warns when TextField is missing keyboardType.

// BAD: TextField without keyboardType
class BadTextFieldNoKeyboardType extends StatelessWidget {
  const BadTextFieldNoKeyboardType({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // expect_lint: require_text_input_type
        TextField(
          controller: TextEditingController(),
        ),
        // expect_lint: require_text_input_type
        TextFormField(
          controller: TextEditingController(),
        ),
      ],
    );
  }
}

// GOOD: TextField with keyboardType
class GoodTextFieldWithKeyboardType extends StatelessWidget {
  const GoodTextFieldWithKeyboardType({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: TextEditingController(),
          keyboardType: TextInputType.emailAddress,
        ),
        TextFormField(
          controller: TextEditingController(),
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }
}

// =========================================================================
// prefer_text_input_action
// =========================================================================
// Warns when TextField is missing textInputAction.

// BAD: TextField without textInputAction
class BadTextFieldNoInputAction extends StatelessWidget {
  const BadTextFieldNoInputAction({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // expect_lint: prefer_text_input_action
        TextField(
          controller: TextEditingController(),
        ),
        // expect_lint: prefer_text_input_action
        TextFormField(
          controller: TextEditingController(),
        ),
      ],
    );
  }
}

// GOOD: TextField with textInputAction
class GoodTextFieldWithInputAction extends StatelessWidget {
  const GoodTextFieldWithInputAction({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: TextEditingController(),
          textInputAction: TextInputAction.next,
        ),
        TextFormField(
          controller: TextEditingController(),
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }
}

// =========================================================================
// require_form_key_in_stateful_widget
// =========================================================================
// Warns when GlobalKey<FormState> is created inside build().

// BAD: GlobalKey created in build method
class BadFormKeyInBuild extends StatefulWidget {
  const BadFormKeyInBuild({super.key});

  @override
  State<BadFormKeyInBuild> createState() => _BadFormKeyInBuildState();
}

class _BadFormKeyInBuildState extends State<BadFormKeyInBuild> {
  @override
  // expect_lint: require_form_key_in_stateful_widget
  Widget build(BuildContext context) {
    final formKey = GlobalKey<FormState>(); // New key every build!
    return Form(
      key: formKey,
      child: Container(),
    );
  }
}

// GOOD: GlobalKey as a field
class GoodFormKeyAsField extends StatefulWidget {
  const GoodFormKeyAsField({super.key});

  @override
  State<GoodFormKeyAsField> createState() => _GoodFormKeyAsFieldState();
}

class _GoodFormKeyAsFieldState extends State<GoodFormKeyAsField> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Container(),
    );
  }
}

// =========================================================================
// Helper mocks
// =========================================================================

class TextInputType {
  const TextInputType._();
  static const TextInputType text = TextInputType._();
  static const TextInputType emailAddress = TextInputType._();
  static const TextInputType number = TextInputType._();
  static const TextInputType phone = TextInputType._();
}

class TextInputAction {
  const TextInputAction._();
  static const TextInputAction next = TextInputAction._();
  static const TextInputAction done = TextInputAction._();
  static const TextInputAction search = TextInputAction._();
}

class TextField extends Widget {
  const TextField({
    super.key,
    this.controller,
    this.keyboardType,
    this.textInputAction,
  });
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
}

class TextFormField extends Widget {
  const TextFormField({
    super.key,
    this.controller,
    this.keyboardType,
    this.textInputAction,
  });
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
}

class TextEditingController {
  const TextEditingController();
}

class GlobalKey<T> extends Key {
  const GlobalKey();
}

class FormState {}

class Form extends Widget {
  const Form({super.key, this.child});
  final Widget? child;
}
