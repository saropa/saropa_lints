// Example fixture for false positive test: IsarStreamController.initialize()
// Should NOT trigger require_camera_permission_check

import 'package:isar/isar.dart';
import 'package:flutter/widgets.dart';

class ContactModel {}

class DatabaseContactIO {
  static Query<ContactModel> get dbContactQueryVisible =>
      throw UnimplementedError();
}

class HomeTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // This is NOT a CameraController
    final content = IsarStreamBuilder<ContactModel>(
      queryBuilder: DatabaseContactIO.dbContactQueryVisible,
      debounce: const Duration(milliseconds: 300),
      builder:
          (BuildContext context, AsyncSnapshot<List<ContactModel>?> snapshot) {
        return Container();
      },
    );
    return content;
  }
}

class IsarStreamBuilder<T> extends StatelessWidget {
  final Query<T> queryBuilder;
  final Duration debounce;
  final AsyncWidgetBuilder<List<T>?> builder;
  const IsarStreamBuilder({
    required this.queryBuilder,
    required this.debounce,
    required this.builder,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => Container();
}
