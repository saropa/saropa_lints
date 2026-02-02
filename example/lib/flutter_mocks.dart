// ignore_for_file: unused_element, avoid_unused_constructor_parameters
// ignore_for_file: avoid_context_in_static_methods
// Mock Flutter types for lint rule testing
// These mocks allow testing lint rules without requiring the Flutter SDK

// ============================================================================
// Core Flutter types
// ============================================================================

class BuildContext {
  bool get mounted => true;
}

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
  Widget build(BuildContext context);
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
  const ConstrainedBox(
      {super.key, required dynamic constraints, Widget? child});
}

class Column extends Widget {
  const Column({
    super.key,
    List<Widget>? children,
    MainAxisSize mainAxisSize = MainAxisSize.max,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    TextBaseline? textBaseline,
  });
}

class Row extends Widget {
  const Row({
    super.key,
    List<Widget>? children,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    TextBaseline? textBaseline,
  });
}

class Flex extends Widget {
  const Flex({
    super.key,
    List<Widget>? children,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    TextBaseline? textBaseline,
  });
}

class Expanded extends Widget {
  const Expanded({super.key, int flex = 1, required Widget child});
}

class Flexible extends Widget {
  const Flexible({super.key, int flex = 1, required Widget child});
}

class Spacer extends Widget {
  const Spacer({super.key, int flex = 1});
}

class Stack extends Widget {
  const Stack({super.key, List<Widget>? children});
}

class IndexedStack extends Widget {
  const IndexedStack({super.key, int? index, List<Widget>? children});
}

class Positioned extends Widget {
  const Positioned({
    super.key,
    double? left,
    double? top,
    double? right,
    double? bottom,
    required Widget child,
  });
}

class AnimatedPositioned extends Widget {
  const AnimatedPositioned({
    super.key,
    double? left,
    double? top,
    required Widget child,
    required Duration duration,
  });
}

class PositionedDirectional extends Widget {
  const PositionedDirectional({
    super.key,
    double? start,
    double? top,
    required Widget child,
  });
}

class Wrap extends Widget {
  const Wrap({super.key, List<Widget>? children, double spacing = 0.0});
}

class Table extends Widget {
  const Table({super.key, List<TableRow>? children});
}

class TableRow extends Widget {
  const TableRow({super.key, List<Widget>? children});
}

class TableCell extends Widget {
  const TableCell({super.key, required Widget child});
}

class IntrinsicHeight extends Widget {
  const IntrinsicHeight({super.key, Widget? child});
}

class IntrinsicWidth extends Widget {
  const IntrinsicWidth({super.key, Widget? child});
}

class GridView extends Widget {
  const GridView({super.key, List<Widget>? children, bool shrinkWrap = false});
  const GridView.builder({
    super.key,
    int? itemCount,
    Widget Function(BuildContext, int)? itemBuilder,
    required dynamic gridDelegate,
    bool shrinkWrap = false,
  });
}

class LimitedBox extends Widget {
  const LimitedBox(
      {super.key, double maxHeight = double.infinity, Widget? child});
}

enum MainAxisSize { min, max }

enum CrossAxisAlignment { start, end, center, stretch, baseline }

enum TextBaseline { alphabetic, ideographic }

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
  const TextField(
      {super.key,
      TextEditingController? controller,
      FocusNode? focusNode,
      bool autofocus = false});
}

class TextFormField extends Widget {
  const TextFormField({super.key});
}

// ============================================================================
// Scroll widgets
// ============================================================================

class ListView extends Widget {
  const ListView(
      {super.key,
      List<Widget>? children,
      dynamic physics,
      bool shrinkWrap = false});
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

class Theme {
  static ThemeData of(BuildContext context) => ThemeData();
}

class ThemeData {
  dynamic get primaryColor => null;
}

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
  const AlertDialog(
      {super.key, Widget? title, Widget? content, List<Widget>? actions});
}

class SimpleDialog extends Widget {
  const SimpleDialog({super.key, Widget? title, List<Widget>? children});
}

// ============================================================================
// Animation
// ============================================================================

class AnimationController {
  AnimationController({required dynamic vsync, Duration? duration});
  void dispose() {}
  double get value => 0.0;
}

abstract class Animation<T> {
  T get value;
}

class CurvedAnimation implements Animation<double> {
  CurvedAnimation({required Animation<double> parent, required dynamic curve});
  @override
  double get value => 0.0;
}

/// Axis enum for SizeTransition
enum Axis { horizontal, vertical }

/// Curves for animations
class Curves {
  static const dynamic easeIn = null;
  static const dynamic easeOut = null;
  static const dynamic linear = null;
}

/// Transition widgets for animation rules testing
class ScaleTransition extends Widget {
  const ScaleTransition({
    super.key,
    required Animation<double> scale,
    Widget? child,
  });
}

class FadeTransition extends Widget {
  const FadeTransition({
    super.key,
    required Animation<double> opacity,
    Widget? child,
  });
}

class SlideTransition extends Widget {
  const SlideTransition({
    super.key,
    required Animation<dynamic> position,
    Widget? child,
  });
}

class RotationTransition extends Widget {
  const RotationTransition({
    super.key,
    required Animation<double> turns,
    Widget? child,
  });
}

class SizeTransition extends Widget {
  const SizeTransition({
    super.key,
    required Animation<double> sizeFactor,
    Axis axis = Axis.vertical,
    double axisAlignment = 0.0,
    Widget? child,
  });
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
// Debug printing
// ============================================================================

void debugPrint(String? message, {int? wrapWidth}) {}

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
  const PageView(
      {super.key, PageController? controller, List<Widget>? children});
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
  static NavigatorState of(BuildContext context) => NavigatorState();
}

class NavigatorState {
  void pop<T>([T? result]) {}
  Future<T?> pushNamed<T>(String routeName, {Object? arguments}) async => null;
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
    Widget Function(
            BuildContext, TextEditingController, FocusNode, VoidCallback)?
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

// ============================================================================
// Cubit (mock for v4.1.4 rules)
// ============================================================================

abstract class Cubit<State> {
  Cubit(State initialState);
  State get state => throw UnimplementedError();
  void emit(State state) {}
}

class UserBloc extends Bloc<Object, Object> {
  UserBloc() : super(Object());
}

// ============================================================================
// GetX (mock for v4.1.4 rules)
// ============================================================================

abstract class GetxController {
  void onInit() {}
  void onClose() {}
}

class Get {
  static void put<T>(T instance) {}
  static void lazyPut<T>(T Function() builder) {}
  static void snackbar(String title, String message) {}
}

// ============================================================================
// Hive (mock for v4.1.4 rules)
// ============================================================================

class Box<T> {}

class LazyBox<T> {}

class HiveType {
  const HiveType({required int typeId});
}

class Hive {
  static Future<Box<T>> openBox<T>(String name) async => Box<T>();
  static Future<LazyBox<T>> openLazyBox<T>(String name) async => LazyBox<T>();
}

class Uint8List {
  Uint8List(int length);
}

// ============================================================================
// SharedPreferences (mock for v4.1.4 rules)
// ============================================================================

class SharedPreferences {
  static Future<SharedPreferences> getInstance() async => SharedPreferences();
  static void setPrefix(String prefix) {}
}

class SendPort {}

// ============================================================================
// Intl (mock for v4.1.4 rules)
// ============================================================================

class Intl {
  static String message(String message, {List<Object>? args}) => message;
}

// ============================================================================
// Navigation (mock for v4.1.4 rules)
// ============================================================================

class MaterialPageRoute<T> {
  MaterialPageRoute({
    required Widget Function(BuildContext) builder,
    RouteSettings? settings,
  });
}

class RouteSettings {
  const RouteSettings({String? name});
}

// ============================================================================
// ChangeNotifierProxyProvider (mock for v4.1.4 rules)
// ============================================================================

class ChangeNotifierProxyProvider<T, R extends ChangeNotifier> extends Widget {
  const ChangeNotifierProxyProvider({
    super.key,
    required R Function(BuildContext) create,
    required R Function(BuildContext, T, R?) update,
    Widget? child,
  });
}

// ============================================================================
// freezed annotation (mock for v4.1.4 rules)
// ============================================================================

const freezed = _Freezed();

class _Freezed {
  const _Freezed();
}

// ============================================================================
// WidgetsBinding (mock for v4.1.4 rules)
// ============================================================================

class WidgetsBinding {
  static WidgetsBinding get instance => WidgetsBinding();
  void addPostFrameCallback(void Function(Duration) callback) {}
}
