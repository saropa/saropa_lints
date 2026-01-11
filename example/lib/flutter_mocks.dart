// ignore_for_file: unused_element, avoid_unused_constructor_parameters
// Mock Flutter types for lint rule testing
// These mocks allow testing lint rules without requiring the Flutter SDK

// ============================================================================
// Core Flutter types
// ============================================================================

class BuildContext {}

abstract class Widget {
  const Widget({Key? key});
}

class Key {
  const Key(String value);
}

// ============================================================================
// StatelessWidget / StatefulWidget
// ============================================================================

abstract class StatelessWidget extends Widget {
  const StatelessWidget({super.key});
  Widget build(BuildContext context);
}

abstract class StatefulWidget extends Widget {
  const StatefulWidget({super.key});
  State createState();
}

abstract class State<T extends StatefulWidget> {
  T get widget => throw UnimplementedError();
  BuildContext get context => BuildContext();
  bool get mounted => true;
  void setState(void Function() fn) {}
  void dispose() {}
  void initState() {}
}

// ============================================================================
// Common widgets
// ============================================================================

class Container extends Widget {
  const Container({
    super.key,
    Widget? child,
    dynamic alignment,
    dynamic padding,
    dynamic margin,
    dynamic constraints,
    dynamic color,
    dynamic decoration,
    dynamic transform,
    double? width,
    double? height,
  });
}

class SizedBox extends Widget {
  const SizedBox({super.key, double? width, double? height, Widget? child});
  const SizedBox.square({super.key, double? dimension, Widget? child});
  const SizedBox.shrink({super.key, Widget? child});
  const SizedBox.expand({super.key, Widget? child});
}

class Padding extends Widget {
  const Padding({super.key, required dynamic padding, Widget? child});
}

class Align extends Widget {
  const Align({super.key, dynamic alignment, Widget? child});
}

class Center extends Widget {
  const Center({super.key, Widget? child});
}

class ConstrainedBox extends Widget {
  const ConstrainedBox({super.key, required dynamic constraints, Widget? child});
}

class Column extends Widget {
  const Column({super.key, List<Widget>? children});
}

class Row extends Widget {
  const Row({super.key, List<Widget>? children});
}

class Text extends Widget {
  const Text(String data, {super.key});
}

class Icon extends Widget {
  const Icon(dynamic icon, {super.key});
}

class Semantics extends Widget {
  const Semantics({super.key, String? label, Widget? child});
}

// ============================================================================
// Image widgets
// ============================================================================

class CircleAvatar extends Widget {
  const CircleAvatar({
    super.key,
    dynamic backgroundImage,
    String? semanticLabel,
    void Function(Object, StackTrace?)? onBackgroundImageError,
  });
}

class NetworkImage {
  const NetworkImage(String url);
}

class Badge extends Widget {
  const Badge({super.key, Widget? label, Widget? child});
}

// ============================================================================
// Form widgets
// ============================================================================

class TextField extends Widget {
  const TextField({super.key, TextEditingController? controller, FocusNode? focusNode, bool autofocus = false});
}

class TextFormField extends Widget {
  const TextFormField({super.key});
}

// ============================================================================
// Scroll widgets
// ============================================================================

class ListView extends Widget {
  const ListView({super.key, List<Widget>? children, dynamic physics, bool shrinkWrap = false});
  const ListView.builder({
    super.key,
    int? itemCount,
    Widget Function(BuildContext, int)? itemBuilder,
    dynamic physics,
    bool shrinkWrap = false,
  });
}

class SingleChildScrollView extends Widget {
  const SingleChildScrollView({super.key, Widget? child, dynamic physics});
}

class CustomScrollView extends Widget {
  const CustomScrollView({super.key, List<Widget>? slivers, dynamic physics});
}

// ============================================================================
// Material widgets
// ============================================================================

class Scaffold extends Widget {
  const Scaffold({super.key, Widget? body, Widget? appBar});
}

class AppBar extends Widget {
  const AppBar({super.key, Widget? title});
}

class SnackBar extends Widget {
  const SnackBar({super.key, required Widget content, Duration? duration});
}

class ScaffoldMessenger {
  static ScaffoldMessengerState of(BuildContext context) =>
      ScaffoldMessengerState();
}

class ScaffoldMessengerState {
  void showSnackBar(SnackBar snackBar) {}
  void clearSnackBars() {}
}

// ============================================================================
// Dialog
// ============================================================================

Future<T?> showDialog<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool barrierDismissible = true,
}) async {
  return null;
}

class AlertDialog extends Widget {
  const AlertDialog({super.key, Widget? title, Widget? content, List<Widget>? actions});
}

// ============================================================================
// Animation
// ============================================================================

class AnimationController {
  AnimationController({required dynamic vsync, Duration? duration});
  void dispose() {}
}

mixin SingleTickerProviderStateMixin<T extends StatefulWidget> on State<T> {}

// ============================================================================
// Timer / Stream
// ============================================================================

class Timer {
  Timer(Duration duration, void Function() callback);
  Timer.periodic(Duration duration, void Function(Timer) callback);
  void cancel() {}
}

class StreamSubscription<T> {
  Future<void> cancel() async {}
}

class StreamController<T> {
  Stream<T> get stream => Stream.empty();
  void close() {}
}

// ============================================================================
// Icons
// ============================================================================

class Icons {
  static const dynamic notifications = null;
  static const dynamic mail = null;
  static const dynamic star = null;
  static const dynamic home = null;
  static const dynamic search = null;
  static const dynamic add = null;
  static const dynamic person = null;
  static const dynamic settings = null;
  static const dynamic help = null;
}

// ============================================================================
// Colors
// ============================================================================

class Colors {
  static const dynamic red = null;
  static const dynamic blue = null;
  static const dynamic black = null;
}

// ============================================================================
// Alignment
// ============================================================================

class Alignment {
  static const Alignment topLeft = Alignment._();
  static const Alignment center = Alignment._();
  static const Alignment bottomRight = Alignment._();
  const Alignment._();
}

// ============================================================================
// EdgeInsets
// ============================================================================

class EdgeInsets {
  const EdgeInsets.all(double value);
  const EdgeInsets.symmetric({double? horizontal, double? vertical});
}

// ============================================================================
// BoxConstraints
// ============================================================================

class BoxConstraints {
  const BoxConstraints({double? maxWidth, double? minWidth});
  const BoxConstraints.tightFor({double? width, double? height});
}

// ============================================================================
// Duration
// ============================================================================

class Duration {
  const Duration({int seconds = 0, int milliseconds = 0});
}

// ============================================================================
// Physics
// ============================================================================

class NeverScrollableScrollPhysics {
  const NeverScrollableScrollPhysics();
}

class AlwaysScrollableScrollPhysics {
  const AlwaysScrollableScrollPhysics();
}

// ============================================================================
// VoidCallback
// ============================================================================

typedef VoidCallback = void Function();

// ============================================================================
// Image widget
// ============================================================================

class Image extends Widget {
  const Image({super.key});
  const Image.network(String url, {Key? key});
  const Image.asset(String name, {Key? key});
}

// ============================================================================
// Controllers
// ============================================================================

class TextEditingController {
  TextEditingController({String? text});
  void dispose() {}
}

class TabController {
  TabController({required int length, required dynamic vsync});
  void dispose() {}
}

class PageController {
  PageController({int initialPage = 0});
  void dispose() {}
}

class FocusNode {
  FocusNode();
  void dispose() {}
}

// ============================================================================
// Tab widgets
// ============================================================================

class TabBar extends Widget {
  const TabBar({super.key, TabController? controller, List<Tab>? tabs});
}

class Tab extends Widget {
  const Tab({super.key, String? text, Widget? icon});
}

// ============================================================================
// PageView
// ============================================================================

class PageView extends Widget {
  const PageView({super.key, PageController? controller, List<Widget>? children});
}

// ============================================================================
// Buttons
// ============================================================================

class ElevatedButton extends Widget {
  const ElevatedButton({super.key, VoidCallback? onPressed, Widget? child});
}

class TextButton extends Widget {
  const TextButton({super.key, VoidCallback? onPressed, Widget? child});
}

// ============================================================================
// Navigation
// ============================================================================

class Navigator {
  static void pop<T>(BuildContext context, [T? result]) {}
}

class BottomNavigationBar extends Widget {
  const BottomNavigationBar({super.key, List<BottomNavigationBarItem>? items});
}

class BottomNavigationBarItem {
  const BottomNavigationBarItem({required Widget icon, String? label});
}

// ============================================================================
// Icons (more)
// ============================================================================

// ============================================================================
// Autocomplete
// ============================================================================

class Autocomplete<T extends Object> extends Widget {
  const Autocomplete({
    super.key,
    required Iterable<T> Function(TextEditingValue) optionsBuilder,
    Widget Function(BuildContext, TextEditingController, FocusNode, VoidCallback)?
        fieldViewBuilder,
  });
}

class TextEditingValue {
  const TextEditingValue({String text = ''});
}

// ============================================================================
// ValueNotifier
// ============================================================================

class ValueNotifier<T> {
  ValueNotifier(T value);
  void dispose() {}
}

class ChangeNotifier {
  void dispose() {}
}

// ============================================================================
// Provider (mock)
// ============================================================================

class Provider<T> extends Widget {
  const Provider({
    super.key,
    required T Function(BuildContext) create,
    void Function(BuildContext, T)? dispose,
    Widget? child,
  });
  const Provider.value({
    super.key,
    required T value,
    Widget? child,
  });
}

class MultiProvider extends Widget {
  const MultiProvider({
    super.key,
    required List<Widget> providers,
    Widget? child,
  });
}

class ChangeNotifierProvider<T extends ChangeNotifier> extends Widget {
  const ChangeNotifierProvider({
    super.key,
    required T Function(BuildContext) create,
    Widget? child,
  });
}

// ============================================================================
// BLoC (mock)
// ============================================================================

abstract class Bloc<Event, State> {
  Bloc(State initialState);
}

class BlocProvider<T extends Bloc<Object, Object>> extends Widget {
  const BlocProvider({
    super.key,
    required T Function(BuildContext) create,
    Widget? child,
  });
  const BlocProvider.value({
    super.key,
    required T value,
    Widget? child,
  });
}

class MultiBlocProvider extends Widget {
  const MultiBlocProvider({
    super.key,
    required List<Widget> providers,
    Widget? child,
  });
}

extension ReadContext on BuildContext {
  T read<T>() => throw UnimplementedError();
}
