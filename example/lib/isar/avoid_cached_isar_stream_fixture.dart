// Example fixture for AvoidCachedIsarStreamRule
// BAD: Caching Isar stream in a variable
import 'package:isar/isar.dart';

final usersStream = Isar.open([UserSchema]).then((isar) => isar.users.where().watch());

// BAD: Caching Isar stream in a field
class UserRepo {
  final usersStream = Isar.open([UserSchema]).then((isar) => isar.users.where().watch());
}

// GOOD: Inline stream creation in StreamBuilder
Widget build(BuildContext context) {
  return StreamBuilder(
    stream: Isar.open([UserSchema]).then((isar) => isar.users.where().watch()),
    builder: (context, snapshot) => Container(),
  );
}
