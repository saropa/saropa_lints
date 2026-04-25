// ignore_for_file: unused_field

import '../flutter_mocks.dart';

/// Fixture for `prefer_nullable_over_late`.

class BadPlain {
  // LINT: late on non-State class risks LateInitializationError
  late String name;
}

class GoodPlain {
  String? name;
}

class MyScreen extends StatefulWidget {
  const MyScreen({super.key});
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  // OK: Flutter State — late is exempt (lifecycle assigns before use)
  late String _data;
}
