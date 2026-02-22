// ignore_for_file: unused_element, avoid_unused_constructor_parameters
// ignore_for_file: avoid_context_in_static_methods
// ignore_for_file: prefer_explicit_type_arguments, avoid_double_for_money
// ignore_for_file: require_websocket_reconnection, require_immutable_bloc_state
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
  void didUpdateWidget(T oldWidget) {}
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

class IndexedStack extends Stack {
  const IndexedStack({super.key, int? index, super.children});
}

/// Mock for `package:indexed` Indexer widget which extends Stack.
class Indexer extends Stack {
  const Indexer({super.key, super.children});
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
  const Text(String data,
      {super.key,
      TextStyle? style,
      int? maxLines,
      dynamic overflow,
      dynamic textAlign,
      dynamic textScaleFactor,
      dynamic semanticsLabel});
  const Text.rich(dynamic textSpan,
      {Key? key, TextStyle? style, int? maxLines, dynamic overflow});
}

class Icon extends Widget {
  const Icon(dynamic icon,
      {super.key, double? size, dynamic color, String? semanticLabel});
}

class Semantics extends Widget {
  const Semantics(
      {super.key,
      String? label,
      Widget? child,
      bool? excludeSemantics,
      bool? button,
      bool? header,
      bool? image,
      bool? link,
      bool? enabled,
      bool? focused,
      bool? checked,
      bool? selected,
      bool? toggled,
      bool? hidden,
      String? hint,
      String? value,
      dynamic onTap,
      dynamic onLongPress,
      dynamic textDirection,
      bool? readOnly,
      bool? liveRegion,
      String? tooltip});
}

class MergeSemantics extends Widget {
  const MergeSemantics({super.key, Widget? child});
}

class ExcludeSemantics extends Widget {
  const ExcludeSemantics({super.key, Widget? child, bool excluding = true});
}

class BlockSemantics extends Widget {
  const BlockSemantics({super.key, Widget? child, bool blocking = true});
}

// ============================================================================
// Image widgets
// ============================================================================

class CircleAvatar extends Widget {
  const CircleAvatar({
    super.key,
    Widget? child,
    dynamic backgroundImage,
    double? radius,
    dynamic backgroundColor,
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
  const TextField({
    super.key,
    TextEditingController? controller,
    FocusNode? focusNode,
    bool autofocus = false,
    InputDecoration? decoration,
    dynamic keyboardType,
    dynamic textInputAction,
    dynamic style,
    dynamic onChanged,
    dynamic onSubmitted,
    dynamic validator,
    bool obscureText = false,
    int? maxLines = 1,
    int? minLines,
    bool? enabled,
    dynamic inputFormatters,
    dynamic autocorrect,
    dynamic autofillHints,
  });
}

class TextFormField extends Widget {
  const TextFormField({
    super.key,
    TextEditingController? controller,
    FocusNode? focusNode,
    InputDecoration? decoration,
    dynamic keyboardType,
    dynamic textInputAction,
    dynamic validator,
    dynamic onSaved,
    dynamic onChanged,
    dynamic onFieldSubmitted,
    bool obscureText = false,
    int? maxLines = 1,
    dynamic autovalidateMode,
    dynamic autofillHints,
    dynamic style,
  });
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
  const SingleChildScrollView({
    super.key,
    Widget? child,
    dynamic physics,
    Axis scrollDirection = Axis.vertical,
  });
}

class CustomScrollView extends Widget {
  const CustomScrollView({super.key, List<Widget>? slivers, dynamic physics});
}

// ============================================================================
// Material widgets
// ============================================================================

class Theme extends Widget {
  const Theme({super.key, required ThemeData data, required Widget child});
  static ThemeData of(BuildContext context) => ThemeData();
}

class Scaffold extends Widget {
  const Scaffold(
      {super.key,
      Widget? body,
      Widget? appBar,
      Widget? floatingActionButton,
      Widget? bottomNavigationBar,
      Widget? drawer,
      Widget? endDrawer,
      dynamic backgroundColor,
      dynamic resizeToAvoidBottomInset,
      dynamic bottomSheet});
}

class AppBar extends Widget {
  const AppBar(
      {super.key,
      Widget? title,
      List<Widget>? actions,
      Widget? leading,
      dynamic backgroundColor,
      dynamic elevation,
      bool? centerTitle,
      dynamic bottom});
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
  static const dynamic error = null;
  static const dynamic check = null;
  static const dynamic close = null;
  static const dynamic delete = null;
  static const dynamic edit = null;
  static const dynamic menu = null;
  static const dynamic more_vert = null;
  static const dynamic arrow_back = null;
  static const dynamic arrow_forward = null;
  static const dynamic info = null;
  static const dynamic warning = null;
  static const dynamic star_border = null;
  static const dynamic favorite = null;
  static const dynamic favorite_border = null;
  static const dynamic share = null;
  static const dynamic send = null;
  static const dynamic refresh = null;
  static const dynamic lock = null;
  static const dynamic visibility = null;
  static const dynamic visibility_off = null;
  static const dynamic camera = null;
  static const dynamic photo = null;
  static const dynamic play_arrow = null;
  static const dynamic pause = null;
  static const dynamic stop = null;
  static const dynamic volume_up = null;
  static const dynamic volume_off = null;
  static const dynamic download = null;
  static const dynamic upload = null;
  static const dynamic location_on = null;
  static const dynamic gps_fixed = null;
  static const dynamic bluetooth = null;
  static const dynamic wifi = null;
  static const dynamic phone = null;
  static const dynamic message = null;
  static const dynamic chat = null;
  static const dynamic calendar_today = null;
  static const dynamic access_time = null;
  static const dynamic alarm = null;
}

// ============================================================================
// Colors
// ============================================================================

class Colors {
  static const dynamic red = null;
  static const dynamic blue = null;
  static const dynamic black = null;
  static const dynamic white = null;
  static const dynamic green = null;
  static const dynamic grey = null;
  static const dynamic orange = null;
  static const dynamic yellow = null;
  static const dynamic purple = null;
  static const dynamic transparent = null;
  static const dynamic amber = null;
  static const dynamic cyan = null;
  static const dynamic pink = null;
  static const dynamic teal = null;
  static const dynamic indigo = null;
  static const dynamic brown = null;
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
  const Image(
      {super.key,
      dynamic image,
      double? width,
      double? height,
      dynamic fit,
      dynamic color,
      dynamic colorBlendMode,
      String? semanticLabel,
      bool excludeFromSemantics = false,
      dynamic errorBuilder,
      dynamic loadingBuilder,
      int? cacheWidth,
      int? cacheHeight});
  const Image.network(String url,
      {Key? key,
      double? width,
      double? height,
      dynamic fit,
      dynamic errorBuilder,
      dynamic loadingBuilder,
      int? cacheWidth,
      int? cacheHeight,
      String? semanticLabel,
      bool excludeFromSemantics = false});
  const Image.asset(String name,
      {Key? key,
      double? width,
      double? height,
      dynamic fit,
      String? semanticLabel,
      bool excludeFromSemantics = false,
      int? cacheWidth,
      int? cacheHeight});
  const Image.memory(dynamic bytes,
      {Key? key,
      double? width,
      double? height,
      dynamic fit,
      String? semanticLabel});
}

class AssetImage {
  const AssetImage(String assetName);
}

class DecorationImage {
  const DecorationImage(
      {required dynamic image, dynamic fit, dynamic colorFilter});
}

class ImageProvider {
  const ImageProvider();
}

class ImageStream {
  void addListener(dynamic listener) {}
  void removeListener(dynamic listener) {}
}

class ImageStreamListener {
  const ImageStreamListener(dynamic onImage, {dynamic onError});
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
    void Function()? onPop,
    void Function(T?)? onPopWithResult,
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
// Builder widgets (mock for builder-callback tests)
// ============================================================================

class Builder extends Widget {
  const Builder({super.key, required Widget Function(BuildContext) builder});
}

class StreamBuilder<T> extends Widget {
  const StreamBuilder({
    super.key,
    Stream<T>? stream,
    required Widget Function(BuildContext, AsyncSnapshot<T>) builder,
  });
}

class AsyncSnapshot<T> {
  const AsyncSnapshot();
  bool get hasData => false;
  bool get hasError => false;
  T? get data => null;
  dynamic get error => null;
  dynamic get connectionState => null;
}

class BlocBuilder<B, S> extends Widget {
  const BlocBuilder({
    super.key,
    required Widget Function(BuildContext, S) builder,
  });
}

class LayoutBuilder extends Widget {
  const LayoutBuilder({
    super.key,
    required Widget Function(BuildContext, BoxConstraints) builder,
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

// ============================================================================
// Collection comparison functions (from foundation.dart)
// ============================================================================

bool listEquals<T>(List<T>? a, List<T>? b) => a == b;
bool setEquals<T>(Set<T>? a, Set<T>? b) => a == b;
bool mapEquals<K, V>(Map<K, V>? a, Map<K, V>? b) => a == b;

// ============================================================================
// Additional widget types for test fixture generation
// ============================================================================

class ListTile extends Widget {
  const ListTile({
    super.key,
    Widget? title,
    Widget? subtitle,
    Widget? leading,
    Widget? trailing,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    bool enabled = true,
    bool selected = false,
  });
}

class TextStyle {
  const TextStyle({
    double? fontSize,
    dynamic fontWeight,
    dynamic color,
    dynamic decoration,
    String? fontFamily,
    double? letterSpacing,
    double? height,
  });
}

class MaterialApp extends Widget {
  const MaterialApp({
    super.key,
    Widget? home,
    String? title,
    dynamic theme,
    dynamic darkTheme,
    dynamic themeMode,
    dynamic onGenerateRoute,
  });
}

class GestureDetector extends Widget {
  const GestureDetector({
    super.key,
    Widget? child,
    VoidCallback? onTap,
    VoidCallback? onDoubleTap,
    VoidCallback? onLongPress,
    dynamic behavior,
  });
}

class InputDecoration {
  const InputDecoration({
    String? labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    dynamic border,
    String? errorText,
    Widget? label,
  });
}

class CircularProgressIndicator extends Widget {
  const CircularProgressIndicator(
      {super.key, double? value, dynamic color, double? strokeWidth});
}

class TextSpan {
  const TextSpan({
    String? text,
    TextStyle? style,
    List<TextSpan>? children,
    dynamic recognizer,
  });
}

class Form extends Widget {
  const Form(
      {super.key, Widget? child, dynamic autovalidateMode, dynamic onChanged});
}

class IconButton extends Widget {
  const IconButton({
    super.key,
    required VoidCallback? onPressed,
    required Widget icon,
    String? tooltip,
  });
}

class InkWell extends Widget {
  const InkWell({
    super.key,
    Widget? child,
    VoidCallback? onTap,
  });
}

class Hero extends Widget {
  const Hero({super.key, required dynamic tag, required Widget child});
}

class BoxDecoration {
  const BoxDecoration({
    dynamic color,
    dynamic gradient,
    dynamic border,
    dynamic borderRadius,
    dynamic boxShadow,
  });
}

class Opacity extends Widget {
  const Opacity({super.key, required double opacity, Widget? child});
}

class SafeArea extends Widget {
  const SafeArea({super.key, required Widget child});
}

class AnimatedList extends Widget {
  const AnimatedList({
    super.key,
    required dynamic itemBuilder,
    int initialItemCount = 0,
  });
}

class SliverAnimatedList extends Widget {
  const SliverAnimatedList({super.key, required dynamic itemBuilder});
}

class ValueKey<T> extends Key {
  const ValueKey(T value) : super('');
}

class GlobalKey<T extends State> extends Key {
  GlobalKey({String? debugLabel}) : super('');
}

class Color {
  const Color(int value);
  Color withOpacity(double opacity) => this;
}

class SliverList extends Widget {
  const SliverList({super.key, required dynamic delegate});
  const SliverList.builder({
    super.key,
    required dynamic itemBuilder,
    int? itemCount,
  });
}

class AnimatedContainer extends Widget {
  const AnimatedContainer({
    super.key,
    required Duration duration,
    Widget? child,
    dynamic color,
    double? width,
    double? height,
  });
}

class SelectableText extends Widget {
  const SelectableText(String data, {super.key, TextStyle? style});
}

class Tooltip extends Widget {
  const Tooltip({super.key, String? message, Widget? child});
}

class Card extends Widget {
  const Card({super.key, Widget? child, dynamic elevation});
}

class FloatingActionButton extends Widget {
  const FloatingActionButton({
    super.key,
    VoidCallback? onPressed,
    Widget? child,
    String? tooltip,
  });
}

class Switch extends Widget {
  const Switch({super.key, required bool value, dynamic onChanged});
}

class Checkbox extends Widget {
  const Checkbox({super.key, required bool? value, dynamic onChanged});
}

class RefreshIndicator extends Widget {
  const RefreshIndicator({
    super.key,
    required Widget child,
    required dynamic onRefresh,
  });
}

class RepaintBoundary extends Widget {
  const RepaintBoundary({super.key, Widget? child});
}

class FittedBox extends Widget {
  const FittedBox({super.key, Widget? child, dynamic fit});
}

class Chip extends Widget {
  const Chip({super.key, required Widget label, Widget? avatar});
}

class Draggable<T> extends Widget {
  const Draggable({
    super.key,
    required Widget child,
    required Widget feedback,
    T? data,
  });
}

class Dismissible extends Widget {
  const Dismissible({
    super.key,
    required Widget child,
    dynamic onDismissed,
    dynamic background,
    dynamic direction,
  });
}

class FutureBuilder<T> extends Widget {
  const FutureBuilder({
    super.key,
    required Future<T>? future,
    required dynamic builder,
  });
}

class AbsorbPointer extends Widget {
  const AbsorbPointer({super.key, bool absorbing = true, Widget? child});
}

class IgnorePointer extends Widget {
  const IgnorePointer({super.key, bool ignoring = true, Widget? child});
}

class Visibility extends Widget {
  const Visibility({super.key, required Widget child, bool visible = true});
}

class PopupMenuButton<T> extends Widget {
  const PopupMenuButton({super.key, required dynamic itemBuilder});
}

class DropdownButton<T> extends Widget {
  const DropdownButton({
    super.key,
    required T? value,
    required dynamic onChanged,
    required List<dynamic> items,
  });
}

class DropdownButtonFormField<T> extends Widget {
  const DropdownButtonFormField({
    super.key,
    T? value,
    T? initialValue,
    required dynamic onChanged,
    required List<dynamic> items,
  });
}

class DefaultTextStyle extends Widget {
  const DefaultTextStyle({
    super.key,
    required TextStyle style,
    required Widget child,
  });
}

// ============================================================================
// Test framework stubs
// ============================================================================

void test(String description, dynamic Function() body) {}
void testWidgets(String description, dynamic Function(dynamic) callback) {}
void expect(dynamic actual, dynamic matcher) {}
void group(String description, dynamic Function() body) {}
void setUp(dynamic Function() body) {}
void tearDown(dynamic Function() body) {}
void when(dynamic obj) {}
void verify(dynamic obj) {}
dynamic find = _FindStub();
dynamic findsOneWidget = true;
dynamic findsNothing = true;

class _FindStub {
  dynamic byKey(dynamic key) => null;
  dynamic byType(dynamic type) => null;
  dynamic text(String text) => null;
  dynamic noSuchMethod(Invocation i) => null;
}

// ============================================================================
// Common utility stubs
// ============================================================================

void runApp(Widget app) {}
dynamic jsonDecode(String source) => {};
String jsonEncode(dynamic object) => '';
Future<T> compute<T, U>(T Function(U) callback, U message) async =>
    callback(message);
void log(String message, {String? name, int? level}) {}
void setState(void Function() fn) {}
void doSomething() {}
dynamic fetchData() => null;
dynamic fetchUser() => null;
dynamic showError(dynamic msg) => null;
dynamic saveData(dynamic data) => null;
dynamic showNotification(dynamic n) => null;

class Platform {
  static bool get isIOS => false;
  static bool get isAndroid => false;
  static bool get isMacOS => false;
  static bool get isWindows => false;
  static bool get isLinux => false;
  static Map<String, String> get environment => {};
}

class MediaQuery {
  static dynamic of(BuildContext context) => _MediaQueryData();
  static dynamic maybeOf(BuildContext context) => null;
}

class _MediaQueryData {
  dynamic get size => null;
  double get textScaleFactor => 1.0;
  dynamic get padding => null;
  dynamic get viewInsets => null;
}

class Focus extends Widget {
  const Focus({super.key, Widget? child, dynamic onFocusChange});
}

class FocusTraversalGroup extends Widget {
  const FocusTraversalGroup({super.key, Widget? child, dynamic policy});
}

class ValueListenableBuilder<T> extends Widget {
  const ValueListenableBuilder({
    super.key,
    required dynamic valueListenable,
    required dynamic builder,
  });
}

class OrientationBuilder extends Widget {
  const OrientationBuilder({super.key, required dynamic builder});
}

class CupertinoButton extends Widget {
  const CupertinoButton({
    super.key,
    required VoidCallback? onPressed,
    required Widget child,
  });
}

class ScrollController {
  ScrollController({double initialScrollOffset = 0.0});
  void dispose() {}
  void addListener(VoidCallback listener) {}
  void removeListener(VoidCallback listener) {}
  double get offset => 0.0;
}

class File {
  File(String path);
  String readAsStringSync() => '';
  Future<String> readAsString() async => '';
  bool existsSync() => false;
}

class Uri {
  static Uri parse(String uriString) => Uri._();
  const Uri._();
  String get scheme => '';
  String get host => '';
}

class DateFormat {
  DateFormat(String pattern, [String? locale]);
  String format(dynamic date) => '';
  dynamic parse(String input) => null;
}

class GoRouter {
  GoRouter({required List<dynamic> routes, String? initialLocation});
  void go(String path) {}
  void push(String path) {}
}

class GoRoute {
  const GoRoute({
    required String path,
    dynamic builder,
    List<dynamic>? routes,
    String? name,
  });
}

class CachedNetworkImage extends Widget {
  const CachedNetworkImage({
    super.key,
    required String imageUrl,
    Widget? placeholder,
    Widget? errorWidget,
  });
}

class WebView extends Widget {
  const WebView({
    super.key,
    String? initialUrl,
    dynamic onPageFinished,
  });
}

class InAppWebView extends Widget {
  const InAppWebView({super.key, dynamic initialUrlRequest});
}

class ImagePicker {
  Future<dynamic> pickImage({required dynamic source}) async => null;
}

class ImageSource {
  static const camera = ImageSource._();
  static const gallery = ImageSource._();
  const ImageSource._();
}

class VideoPlayer {
  VideoPlayer({bool autoPlay = false});
  void dispose() {}
}

class AudioPlayer {
  AudioPlayer({bool autoPlay = false});
  void dispose() {}
}

class FlutterSecureStorage {
  const FlutterSecureStorage();
  Future<void> write({required String key, required String? value}) async {}
  Future<String?> read({required String key}) async => null;
}

class Dio {
  Dio([dynamic baseOptions]);
  Future<dynamic> get(String path) async => null;
  Future<dynamic> post(String path, {dynamic data}) async => null;
}

class HttpClient {
  Future<dynamic> getUrl(Uri url) async => null;
}

class StateProvider<T> {
  StateProvider(T Function(dynamic) create);
}

class ConsumerWidget extends Widget {
  const ConsumerWidget({super.key});
}

class MethodChannel {
  const MethodChannel(String name);
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) async => null;
}

class EventChannel {
  const EventChannel(String name);
  Stream<dynamic> receiveBroadcastStream() => Stream.empty();
}

class NotificationDetails {
  const NotificationDetails({dynamic android, dynamic iOS});
}

class BlendMode {
  static const modulate = BlendMode._();
  const BlendMode._();
}

class FontWeight {
  static const bold = FontWeight._();
  static const normal = FontWeight._();
  static const w400 = FontWeight._();
  static const w700 = FontWeight._();
  const FontWeight._();
}

class BorderRadius {
  static dynamic circular(double radius) => null;
}

class ClipRRect extends Widget {
  const ClipRRect({super.key, dynamic borderRadius, Widget? child});
}

class BackdropFilter extends Widget {
  const BackdropFilter({super.key, required dynamic filter, Widget? child});
}

class ThemeMode {
  static const system = ThemeMode._();
  static const light = ThemeMode._();
  static const dark = ThemeMode._();
  const ThemeMode._();
}

class Brightness {
  static const light = Brightness._();
  static const dark = Brightness._();
  const Brightness._();
}

// Placeholder classes for DartDoc examples
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => Container();
}

class MyWidget extends StatelessWidget {
  const MyWidget({super.key});
  @override
  Widget build(BuildContext context) => Container();
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});
  @override
  Widget build(BuildContext context) => Container();
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) => Container();
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) => Container();
}

class User {
  String name = '';
  String email = '';
  int id = 0;
}

class MyService {
  void dispose() {}
}

class UserService {
  Future<User> getUser() async => User();
}

class MyNotifier {
  void dispose() {}
}

// Note: AsyncSnapshot<T> is already defined above in the Builder widgets section

class ConnectionState {
  static const none = ConnectionState._();
  static const waiting = ConnectionState._();
  static const active = ConnectionState._();
  static const done = ConnectionState._();
  const ConnectionState._();
}

class Geolocator {
  static Future<dynamic> getCurrentPosition() async => null;
  static Future<bool> isLocationServiceEnabled() async => false;
}

class LocationSettings {
  const LocationSettings({dynamic accuracy, int? distanceFilter});
}

// ============================================================================
// Additional types for generated test fixtures
// ============================================================================

// ── Layout & Container Widgets ──────────────────────────────────────────

class SliverAppBar extends Widget {
  const SliverAppBar(
      {super.key,
      Widget? title,
      bool? floating,
      bool? pinned,
      dynamic expandedHeight,
      Widget? flexibleSpace});
}

class SliverToBoxAdapter extends Widget {
  const SliverToBoxAdapter({super.key, Widget? child});
}

class SliverGrid extends Widget {
  const SliverGrid(
      {super.key, required dynamic delegate, required dynamic gridDelegate});
}

class SliverChildBuilderDelegate {
  const SliverChildBuilderDelegate(dynamic builder, {int? childCount});
}

class SliverGridDelegateWithFixedCrossAxisCount {
  const SliverGridDelegateWithFixedCrossAxisCount(
      {required int crossAxisCount,
      double? mainAxisSpacing,
      double? crossAxisSpacing});
}

class AnimatedWidget extends Widget {
  const AnimatedWidget({super.key, required dynamic listenable});
}

class AnimatedBuilder extends Widget {
  const AnimatedBuilder(
      {super.key,
      required dynamic animation,
      required dynamic builder,
      Widget? child});
}

class Tween<T> {
  Tween({T? begin, T? end});
  dynamic animate(dynamic parent) => null;
}

class TweenSequenceItem<T> {
  const TweenSequenceItem({required dynamic tween, required double weight});
}

class ColorTween extends Tween<dynamic> {
  ColorTween({dynamic begin, dynamic end});
}

// ── Text & Styling ──────────────────────────────────────────────────────

class TextAlign {
  static const center = TextAlign._();
  static const left = TextAlign._();
  static const right = TextAlign._();
  static const start = TextAlign._();
  static const end = TextAlign._();
  static const justify = TextAlign._();
  const TextAlign._();
}

class TextOverflow {
  static const ellipsis = TextOverflow._();
  static const clip = TextOverflow._();
  static const fade = TextOverflow._();
  static const visible = TextOverflow._();
  const TextOverflow._();
}

class TextDecoration {
  static const none = TextDecoration._();
  static const underline = TextDecoration._();
  static const lineThrough = TextDecoration._();
  const TextDecoration._();
}

class RichText extends Widget {
  const RichText(
      {super.key, required dynamic text, int? maxLines, dynamic overflow});
}

// ── Navigation extras ──────────────────────────────────────────────────

class FocusTraversalOrder extends Widget {
  const FocusTraversalOrder(
      {super.key, required dynamic order, required Widget child});
}

class NumericFocusOrder {
  const NumericFocusOrder(double order);
}

class ShellRoute {
  const ShellRoute(
      {dynamic builder, List<dynamic>? routes, dynamic navigatorKey});
}

class StatefulShellRoute {
  const StatefulShellRoute({dynamic builder, List<dynamic>? branches});
  const StatefulShellRoute.indexedStack(
      {dynamic builder, List<dynamic>? branches});
}

class StatefulShellBranch {
  const StatefulShellBranch({List<dynamic>? routes, dynamic navigatorKey});
}

// ── Form & Input ────────────────────────────────────────────────────────

class AutovalidateMode {
  static const disabled = AutovalidateMode._();
  static const always = AutovalidateMode._();
  static const onUserInteraction = AutovalidateMode._();
  const AutovalidateMode._();
}

class TextInputType {
  static const text = TextInputType._();
  static const number = TextInputType._();
  static const emailAddress = TextInputType._();
  static const phone = TextInputType._();
  static const url = TextInputType._();
  static const multiline = TextInputType._();
  static const visiblePassword = TextInputType._();
  const TextInputType._();
}

class TextInputAction {
  static const done = TextInputAction._();
  static const next = TextInputAction._();
  static const search = TextInputAction._();
  static const send = TextInputAction._();
  static const go = TextInputAction._();
  const TextInputAction._();
}

class FormState {
  bool validate() => true;
  void save() {}
  void reset() {}
}

class GlobalObjectKey<T> extends Key {
  const GlobalObjectKey(dynamic value) : super('');
}

// ── Dialogs & Bottom Sheets ─────────────────────────────────────────────

Future<T?> showModalBottomSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool isDismissible = true,
}) async =>
    null;

Future<T?> showDatePicker<T>({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) async =>
    null;

Future<dynamic> showTimePicker({
  required BuildContext context,
  required dynamic initialTime,
}) async =>
    null;

// ── Platform & System ───────────────────────────────────────────────────

class AppLifecycleState {
  static const resumed = AppLifecycleState._();
  static const inactive = AppLifecycleState._();
  static const paused = AppLifecycleState._();
  static const detached = AppLifecycleState._();
  static const hidden = AppLifecycleState._();
  const AppLifecycleState._();
}

class Clipboard {
  static Future<void> setData(dynamic data) async {}
  static Future<dynamic> getData(String format) async => null;
}

class ClipboardData {
  const ClipboardData({String? text});
  final String? text = null;
}

const bool kIsWeb = false;
const bool kDebugMode = true;
const bool kReleaseMode = false;
const bool kProfileMode = false;

class WidgetsFlutterBinding {
  static dynamic ensureInitialized() => null;
}

class SystemChrome {
  static void setPreferredOrientations(List<dynamic> orientations) {}
  static void setSystemUIOverlayStyle(dynamic style) {}
  static void setEnabledSystemUIMode(dynamic mode) {}
}

class DeviceOrientation {
  static const portraitUp = DeviceOrientation._();
  static const landscapeLeft = DeviceOrientation._();
  const DeviceOrientation._();
}

// ── Networking & HTTP ───────────────────────────────────────────────────

class WebSocketChannel {
  static WebSocketChannel connect(dynamic url) => WebSocketChannel();
  Stream<dynamic> get stream => Stream.empty();
  dynamic get sink => null;
  void close() {}
}

class WebSocket {
  static Future<WebSocket> connect(String url) async => WebSocket();
  void close() {}
  Stream<dynamic> get stream => Stream.empty();
}

class Socket {
  static Future<Socket> connect(dynamic host, int port) async => Socket();
  void close() {}
  void destroy() {}
}

Future<bool> canLaunchUrl(dynamic url) async => true;
Future<bool> launchUrl(dynamic url, {dynamic mode}) async => true;

class ConnectivityResult {
  static const none = ConnectivityResult._();
  static const wifi = ConnectivityResult._();
  static const mobile = ConnectivityResult._();
  static const ethernet = ConnectivityResult._();
  const ConnectivityResult._();
}

class Connectivity {
  Future<ConnectivityResult> checkConnectivity() async =>
      ConnectivityResult.wifi;
  Stream<ConnectivityResult> get onConnectivityChanged => Stream.empty();
}

// ── Firebase ────────────────────────────────────────────────────────────

class FirebaseFirestore {
  static FirebaseFirestore get instance => FirebaseFirestore();
  dynamic collection(String path) => null;
  dynamic doc(String path) => null;
}

class FirebaseDatabase {
  static FirebaseDatabase get instance => FirebaseDatabase();
  DatabaseReference ref([String? path]) => DatabaseReference();
}

class DatabaseReference {
  DatabaseReference child(String path) => DatabaseReference();
  DatabaseReference orderByChild(String key) => DatabaseReference();
  DatabaseReference orderByKey() => DatabaseReference();
  DatabaseReference orderByValue() => DatabaseReference();
  DatabaseReference equalTo(dynamic value) => DatabaseReference();
  DatabaseReference startAt(dynamic value) => DatabaseReference();
  DatabaseReference endAt(dynamic value) => DatabaseReference();
  DatabaseReference startAfter(dynamic value) => DatabaseReference();
  DatabaseReference endBefore(dynamic value) => DatabaseReference();
  DatabaseReference limitToFirst(int limit) => DatabaseReference();
  DatabaseReference limitToLast(int limit) => DatabaseReference();
  Future<dynamic> once() async => null;
  Future<dynamic> get() async => null;
  Stream<dynamic> get onValue => const Stream.empty();
  Stream<dynamic> get onChildAdded => const Stream.empty();
  Stream<dynamic> get onChildChanged => const Stream.empty();
  Stream<dynamic> get onChildRemoved => const Stream.empty();
}

class FirebaseAuth {
  static FirebaseAuth get instance => FirebaseAuth();
  dynamic get currentUser => null;
  Future<dynamic> signInWithEmailAndPassword(
          {required String email, required String password}) async =>
      null;
  Future<void> signOut() async {}
}

class FirebaseMessaging {
  static FirebaseMessaging get instance => FirebaseMessaging();
  Future<String?> getToken() async => null;
  Future<dynamic> requestPermission() async => null;
}

class RemoteMessage {
  dynamic get notification => null;
  Map<String, dynamic> get data => {};
}

class RemoteConfig {
  static RemoteConfig get instance => RemoteConfig();
  Future<void> fetchAndActivate() async {}
  String getString(String key) => '';
  bool getBool(String key) => false;
  int getInt(String key) => 0;
}

// ── Camera & Media ──────────────────────────────────────────────────────

class CameraController {
  CameraController(dynamic camera, dynamic resolutionPreset);
  Future<void> initialize() async {}
  Future<dynamic> takePicture() async => null;
  void dispose() {}
}

class ResolutionPreset {
  static const low = ResolutionPreset._();
  static const medium = ResolutionPreset._();
  static const high = ResolutionPreset._();
  static const veryHigh = ResolutionPreset._();
  const ResolutionPreset._();
}

class VideoPlayerController {
  VideoPlayerController.network(String url);
  VideoPlayerController.asset(String path);
  Future<void> initialize() async {}
  Future<void> play() async {}
  Future<void> pause() async {}
  void dispose() {}
  dynamic get value => null;
}

class MobileScanner extends Widget {
  const MobileScanner({super.key, dynamic onDetect, dynamic controller});
}

// ── Location ────────────────────────────────────────────────────────────

class LocationAccuracy {
  static const low = LocationAccuracy._();
  static const medium = LocationAccuracy._();
  static const high = LocationAccuracy._();
  static const best = LocationAccuracy._();
  const LocationAccuracy._();
}

class Position {
  double get latitude => 0.0;
  double get longitude => 0.0;
}

// ── Permissions ─────────────────────────────────────────────────────────

class Permission {
  static const camera = Permission._();
  static const storage = Permission._();
  static const location = Permission._();
  static const microphone = Permission._();
  static const contacts = Permission._();
  static const notification = Permission._();
  static const photos = Permission._();
  static const locationWhenInUse = Permission._();
  static const locationAlways = Permission._();
  const Permission._();
  Future<PermissionStatus> request() async => PermissionStatus.granted;
  Future<PermissionStatus> get status async => PermissionStatus.granted;
}

class PermissionStatus {
  static const granted = PermissionStatus._();
  static const denied = PermissionStatus._();
  static const permanentlyDenied = PermissionStatus._();
  static const restricted = PermissionStatus._();
  const PermissionStatus._();
  bool get isGranted => true;
  bool get isDenied => false;
}

// ── GetIt / DI ──────────────────────────────────────────────────────────

class GetIt {
  static final GetIt instance = GetIt._();
  static final GetIt I = GetIt._();
  GetIt._();
  T call<T extends Object>() => throw UnimplementedError();
  void registerSingleton<T extends Object>(T instance) {}
  void registerLazySingleton<T extends Object>(T Function() factory) {}
  void registerFactory<T extends Object>(T Function() factory) {}
  T get<T extends Object>() => throw UnimplementedError();
}

// ── Isar ────────────────────────────────────────────────────────────────

class Isar {
  static Future<Isar> open(List<dynamic> schemas) async => Isar._();
  Isar._();
  Future<void> close() async {}
  dynamic collection<T>() => null;
  Future<void> writeTxn(Future<void> Function() callback) async {}
}

class IsarCollection<T> {
  Future<T?> get(int id) async => null;
  Future<int> put(T object) async => 0;
  Future<bool> delete(int id) async => false;
}

class Id {
  const Id();
}

// ── Notifications ───────────────────────────────────────────────────────

class FlutterLocalNotificationsPlugin {
  Future<void> show(
      int id, String? title, String? body, dynamic details) async {}
  Future<bool?> initialize(dynamic initializationSettings) async => true;
}

class AndroidNotificationDetails {
  const AndroidNotificationDetails(String channelId, String channelName,
      {String? channelDescription, dynamic importance, dynamic priority});
}

class DarwinNotificationDetails {
  const DarwinNotificationDetails();
}

class InitializationSettings {
  const InitializationSettings({dynamic android, dynamic iOS, dynamic macOS});
}

class AndroidInitializationSettings {
  const AndroidInitializationSettings(String defaultIcon);
}

class DarwinInitializationSettings {
  const DarwinInitializationSettings();
}

// ── Workmanager ─────────────────────────────────────────────────────────

class Workmanager {
  static Workmanager get instance => Workmanager();
  void initialize(dynamic callbackDispatcher) {}
  void registerPeriodicTask(String uniqueName, String taskName,
      {Duration? frequency}) {}
  void registerOneOffTask(String uniqueName, String taskName) {}
}

// ── WebView (InAppWebView) ──────────────────────────────────────────────

class URLRequest {
  const URLRequest({required dynamic url});
}

class InAppWebViewSettings {
  InAppWebViewSettings(
      {bool? javaScriptEnabled, bool? useShouldOverrideUrlLoading});
}

// ── Database ────────────────────────────────────────────────────────────

Future<dynamic> openDatabase(String path,
        {int? version, dynamic onCreate, dynamic onUpgrade}) async =>
    null;

class Database {
  Future<List<Map<String, dynamic>>> query(String table) async => [];
  Future<int> insert(String table, Map<String, dynamic> values) async => 0;
  Future<int> delete(String table,
          {String? where, List<dynamic>? whereArgs}) async =>
      0;
  Future<void> close() async {}
  Future<List<Map<String, dynamic>>> rawQuery(String sql) async => [];
}

// ── Crypto ──────────────────────────────────────────────────────────────

class HiveAesCipher {
  HiveAesCipher(dynamic key);
}

// ── ProxyProvider ───────────────────────────────────────────────────────

class ProxyProvider<T, R> extends Widget {
  const ProxyProvider(
      {super.key, required dynamic update, Widget? child, dynamic create});
}

class ProxyProvider2<T, T2, R> extends Widget {
  const ProxyProvider2({super.key, required dynamic update, Widget? child});
}

class Selector<T, S> extends Widget {
  const Selector(
      {super.key, required dynamic selector, required dynamic builder});
}

class Consumer<T> extends Widget {
  const Consumer({super.key, required dynamic builder});
}

class Consumer2<T, T2> extends Widget {
  const Consumer2({super.key, required dynamic builder});
}

// ── Riverpod ────────────────────────────────────────────────────────────

class WidgetRef {
  T watch<T>(dynamic provider) => throw UnimplementedError();
  T read<T>(dynamic provider) => throw UnimplementedError();
  void listen<T>(dynamic provider, void Function(T?, T) listener) {}
  void invalidate(dynamic provider) {}
}

class ProviderScope extends Widget {
  const ProviderScope(
      {super.key, required Widget child, List<dynamic>? overrides});
}

class ConsumerStatefulWidget extends StatefulWidget {
  const ConsumerStatefulWidget({super.key});
  @override
  State createState() => throw UnimplementedError();
}

class AsyncValue<T> {
  bool get isLoading => false;
  bool get hasValue => true;
  bool get hasError => false;
  T? get value => null;
  dynamic get error => null;
  dynamic when(
          {required dynamic data,
          required dynamic error,
          required dynamic loading}) =>
      null;
}

class NotifierProvider<T, S> {
  const NotifierProvider(dynamic create);
}

class AsyncNotifierProvider<T, S> {
  const AsyncNotifierProvider(dynamic create);
}

class FutureProvider<T> {
  const FutureProvider(dynamic create);
  const FutureProvider.autoDispose(dynamic create);
  const FutureProvider.family(dynamic create);
}

class StreamProvider<T> {
  const StreamProvider(dynamic create);
}

class Ref {
  T watch<T>(dynamic provider) => throw UnimplementedError();
  T read<T>(dynamic provider) => throw UnimplementedError();
}

// ── BLoC extras ─────────────────────────────────────────────────────────

class Emitter<T> {
  void call(T state) {}
}

class BlocObserver {
  void onChange(dynamic bloc, dynamic change) {}
  void onError(dynamic bloc, Object error, StackTrace stackTrace) {}
  void onTransition(dynamic bloc, dynamic transition) {}
  void onEvent(dynamic bloc, dynamic event) {}
}

class BlocListener<B, S> extends Widget {
  const BlocListener(
      {super.key,
      required dynamic listener,
      Widget? child,
      dynamic bloc,
      dynamic listenWhen});
}

class BlocSelector<B, S, T> extends Widget {
  const BlocSelector(
      {super.key, required dynamic selector, required dynamic builder});
}

class BlocConsumer<B, S> extends Widget {
  const BlocConsumer(
      {super.key,
      required dynamic builder,
      required dynamic listener,
      dynamic buildWhen,
      dynamic listenWhen});
}

class RepositoryProvider<T> extends Widget {
  const RepositoryProvider({super.key, required dynamic create, Widget? child});
}

class MultiRepositoryProvider extends Widget {
  const MultiRepositoryProvider(
      {super.key, required List<Widget> providers, required Widget child});
}

// ── GetX extras ─────────────────────────────────────────────────────────

class Obx extends Widget {
  const Obx(Widget Function() builder, {super.key});
}

class GetBuilder<T> extends Widget {
  const GetBuilder({super.key, required dynamic builder, dynamic init});
}

class GetView<T> extends Widget {
  const GetView({super.key});
}

class RxBool {
  RxBool(bool initial);
  bool get value => false;
  set value(bool v) {}
}

class RxString {
  RxString(String initial);
  String get value => '';
  set value(String v) {}
}

class RxInt {
  RxInt(int initial);
  int get value => 0;
  set value(int v) {}
}

class RxList<T> {
  RxList(List<T> initial);
  List<T> get value => [];
}

extension BoolExtension on bool {
  RxBool get obs => RxBool(this);
}

extension StringExtension on String {
  RxString get obs => RxString(this);
}

extension IntExtension on int {
  RxInt get obs => RxInt(this);
}

// ── Misc Widgets ────────────────────────────────────────────────────────

class Material extends Widget {
  const Material(
      {super.key,
      Widget? child,
      dynamic color,
      dynamic elevation,
      dynamic type,
      dynamic borderRadius});
}

class MaterialBanner extends Widget {
  const MaterialBanner(
      {super.key, required Widget content, required List<Widget> actions});
}

class Drawer extends Widget {
  const Drawer({super.key, Widget? child});
}

class TabBarView extends Widget {
  const TabBarView(
      {super.key, required List<Widget> children, TabController? controller});
}

class PreferredSize extends Widget {
  const PreferredSize(
      {super.key, required dynamic preferredSize, required Widget child});
}

class BottomSheet extends Widget {
  const BottomSheet(
      {super.key, required dynamic onClosing, required dynamic builder});
}

class Slider extends Widget {
  const Slider(
      {super.key,
      required double value,
      required dynamic onChanged,
      double? min,
      double? max});
}

class Radio<T> extends Widget {
  const Radio(
      {super.key,
      required T value,
      required T? groupValue,
      required dynamic onChanged});
}

class Stepper extends Widget {
  const Stepper(
      {super.key,
      required List<dynamic> steps,
      int currentStep = 0,
      dynamic onStepContinue,
      dynamic onStepCancel,
      dynamic onStepTapped});
}

class Step {
  const Step(
      {required Widget title,
      required Widget content,
      dynamic state,
      bool isActive = false});
}

class ExpansionTile extends Widget {
  const ExpansionTile(
      {super.key,
      required Widget title,
      List<Widget>? children,
      bool? initiallyExpanded});
}

class DataTable extends Widget {
  const DataTable(
      {super.key, required List<dynamic> columns, required List<dynamic> rows});
}

class DataColumn {
  const DataColumn({required Widget label, dynamic onSort});
}

class DataRow {
  const DataRow(
      {required List<dynamic> cells,
      bool selected = false,
      dynamic onSelectChanged});
}

class DataCell {
  const DataCell(Widget child);
}

class WillPopScope extends Widget {
  const WillPopScope(
      {super.key, required Widget child, required dynamic onWillPop});
}

class PopScope extends Widget {
  const PopScope(
      {super.key,
      required Widget child,
      bool canPop = true,
      dynamic onPopInvoked});
}

class AnimatedOpacity extends Widget {
  const AnimatedOpacity(
      {super.key,
      required double opacity,
      required Duration duration,
      Widget? child,
      dynamic curve});
}

class AnimatedSwitcher extends Widget {
  const AnimatedSwitcher(
      {super.key,
      required Duration duration,
      Widget? child,
      dynamic transitionBuilder});
}

class AnimatedCrossFade extends Widget {
  const AnimatedCrossFade(
      {super.key,
      required Widget firstChild,
      required Widget secondChild,
      required dynamic crossFadeState,
      required Duration duration});
}

class CrossFadeState {
  static const showFirst = CrossFadeState._();
  static const showSecond = CrossFadeState._();
  const CrossFadeState._();
}

class TweenAnimationBuilder<T> extends Widget {
  const TweenAnimationBuilder(
      {super.key,
      required dynamic tween,
      required Duration duration,
      required dynamic builder,
      Widget? child});
}

class NotificationListener<T> extends Widget {
  const NotificationListener(
      {super.key, required Widget child, dynamic onNotification});
}

class MediaQueryData {
  dynamic get size => Size(0, 0);
  double get textScaleFactor => 1.0;
  dynamic get padding => null;
  dynamic get viewInsets => null;
  dynamic get platformBrightness => null;
  bool get accessibleNavigation => false;
  bool get boldText => false;
  double get devicePixelRatio => 1.0;
}

class Size {
  const Size(double width, double height);
  double get width => 0;
  double get height => 0;
}

class Offset {
  const Offset(double dx, double dy);
  static const zero = Offset(0, 0);
}

class Rect {
  const Rect.fromLTWH(double left, double top, double width, double height);
  static const zero = Rect.fromLTWH(0, 0, 0, 0);
}

class Point<T extends num> {
  const Point(T x, T y);
}

class Canvas {
  void drawLine(dynamic p1, dynamic p2, dynamic paint) {}
  void drawRect(dynamic rect, dynamic paint) {}
  void drawCircle(dynamic center, double radius, dynamic paint) {}
  void save() {}
  void restore() {}
}

class Paint {
  dynamic color;
  double strokeWidth = 1.0;
  dynamic style;
}

class RenderObject {
  void markNeedsPaint() {}
  void markNeedsLayout() {}
}

class CustomPainter {
  void paint(Canvas canvas, Size size) {}
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CustomPaint extends Widget {
  const CustomPaint(
      {super.key,
      dynamic painter,
      dynamic foregroundPainter,
      Widget? child,
      dynamic size});
}

// ── Accessibility extras ────────────────────────────────────────────────

class SemanticsProperties {
  const SemanticsProperties(
      {String? label,
      String? hint,
      String? value,
      bool? button,
      bool? header,
      bool? image});
}

// ── Isolate & Compute ───────────────────────────────────────────────────

class Isolate {
  static Future<Isolate> spawn(
          void Function(dynamic) entryPoint, dynamic message) async =>
      Isolate._();
  Isolate._();
  void kill() {}
}

class ReceivePort {
  ReceivePort();
  Stream<dynamic> get stream => Stream.empty();
  dynamic get sendPort => null;
  void close() {}
}

// ── Random & Security ───────────────────────────────────────────────────

class Random {
  Random([int? seed]);
  Random.secure();
  int nextInt(int max) => 0;
  double nextDouble() => 0.0;
  bool nextBool() => false;
}

// ── NumberFormat ─────────────────────────────────────────────────────────

class NumberFormat {
  NumberFormat([String? newPattern, String? locale]);
  NumberFormat.currency(
      {String? locale, String? symbol, int? decimalDigits, String? name});
  NumberFormat.compact({String? locale});
  String format(dynamic number) => '';
}

// ── Encoding ────────────────────────────────────────────────────────────

class Encoding {
  static const utf8 = Utf8Codec();
}

class Utf8Codec {
  const Utf8Codec();
  dynamic encode(String input) => null;
  String decode(dynamic bytes) => '';
}

final utf8 = const Utf8Codec();

// ── Google Maps ─────────────────────────────────────────────────────────

class GoogleMap extends Widget {
  const GoogleMap(
      {super.key,
      required dynamic initialCameraPosition,
      dynamic onMapCreated,
      dynamic markers,
      dynamic polylines});
}

class LatLng {
  const LatLng(double latitude, double longitude);
}

class CameraPosition {
  const CameraPosition({required LatLng target, double zoom = 0});
}

// ── Misc types that appear in DartDoc examples ──────────────────────────

typedef StringCallback = void Function(String);
typedef ErrorCallback = void Function(Object error, StackTrace stackTrace);

class Logger {
  Logger([String? name]);
  void info(String message) {}
  void warning(String message) {}
  void severe(String message, [Object? error, StackTrace? stackTrace]) {}
  void fine(String message) {}
}

class Ticker {
  Ticker(dynamic onTick);
  void dispose() {}
}

class UserRepository {
  Future<dynamic> getUser(dynamic id) async => null;
  Future<List<dynamic>> getUsers() async => [];
  Future<void> saveUser(dynamic user) async {}
}

class ApiClient {
  Future<dynamic> get(String path) async => null;
  Future<dynamic> post(String path, {dynamic body}) async => null;
}

class Request {
  String get url => '';
  String get method => '';
  Map<String, String> get headers => {};
  dynamic get body => null;
}

class Response {
  int get statusCode => 200;
  String get body => '';
  Map<String, String> get headers => {};
  dynamic get data => null;
}

class Query {
  Query(String table);
  Query where(String field,
          {dynamic isEqualTo, dynamic isGreaterThan, dynamic isLessThan}) =>
      this;
  Future<List<dynamic>> get() async => [];
}

class Event {
  dynamic get data => null;
  String get type => '';
}

class Address {
  String street = '';
  String city = '';
  String zip = '';
}

class Order {
  int id = 0;
  double total = 0;
  String status = '';
  List<dynamic> items = [];
}

class OrderResult {
  bool get success => true;
  dynamic get error => null;
}

class PaymentDetails {
  String cardNumber = '';
  String cvv = '';
  String expiry = '';
}

class KeyboardVisibilityController {
  Stream<bool> get onChange => Stream.empty();
}

class RealtimeChannel {
  RealtimeChannel on(String event, dynamic callback) => this;
  void subscribe() {}
}

class Food {
  String name = '';
  int calories = 0;
}

class FutureOr<T> {}

// ── More common functions ───────────────────────────────────────────────

dynamic getApplicationDocumentsDirectory() => null;
void showTooltip(String message) {}
void showContextMenu(dynamic context) {}
void handleError(dynamic error) {}
dynamic processData(dynamic data) => data;
dynamic calculateTotal(dynamic items) => 0;
void submitForm(dynamic form) {}
void selectItem(dynamic item) {}
dynamic searchApi(String query) => null;
dynamic getValue(String key) => null;
dynamic equals(dynamic a, dynamic b) => a == b;
void process(dynamic item) {}
dynamic foo() => null;
dynamic bar() => null;
dynamic baz() => null;
dynamic fetchUsers() async => [];
dynamic fetchProducts() async => [];
dynamic fetchOrders() async => [];
dynamic fetchPosts() async => [];
dynamic expectLater(dynamic actual, dynamic matcher) => null;
dynamic hasLength(int length) => null;

// ── Named constructor/class stubs for DartDoc ───────────────────────────

class Item {
  Item({dynamic name, dynamic price, dynamic id});
  String name = '';
  double price = 0;
  int id = 0;
}

class ItemWidget extends Widget {
  const ItemWidget({super.key, dynamic item});
}

class ExpensiveWidget extends Widget {
  const ExpensiveWidget({super.key, dynamic data});
}

class DataWidget extends Widget {
  const DataWidget({super.key, dynamic data, dynamic builder});
}

class MyButton extends Widget {
  const MyButton(
      {super.key, VoidCallback? onPressed, Widget? child, String? label});
}

class UserPage extends Widget {
  const UserPage({super.key, dynamic user, dynamic userId});
}

class A {}

class B {}

class C {}

class D {}

class Counter {
  int value = 0;
  void increment() => value++;
  void decrement() => value--;
}

class LoadedState {
  const LoadedState(dynamic data);
}

class SecurityException implements Exception {
  SecurityException(String message);
}

class Config {
  Config();
  String get apiUrl => '';
  String get apiKey => '';
  bool get debugMode => false;
}

class Worker {
  Worker();
  void start() {}
  void stop() {}
}

class FetchEvent {
  dynamic get request => null;
}

// ── Supabase ────────────────────────────────────────────────────────────

class Supabase {
  static SupabaseClient get instance => SupabaseClient();
  static Future<void> initialize(
      {required String url, required String anonKey}) async {}
}

class SupabaseClient {
  dynamic from(String table) => null;
  dynamic get auth => null;
  RealtimeChannel channel(String name) => RealtimeChannel();
}

// ── Curves extras ───────────────────────────────────────────────────────

class CurvesExtended {
  static const dynamic easeInOut = null;
  static const dynamic bounceOut = null;
  static const dynamic bounceIn = null;
  static const dynamic elasticIn = null;
  static const dynamic elasticOut = null;
  static const dynamic decelerate = null;
  static const dynamic fastOutSlowIn = null;
}

// ── Additional widget types ─────────────────────────────────────────────

class ColoredBox extends Widget {
  const ColoredBox({super.key, required dynamic color, Widget? child});
}

class DecoratedBox extends Widget {
  const DecoratedBox({super.key, required dynamic decoration, Widget? child});
}

class Divider extends Widget {
  const Divider({super.key, double? height, double? thickness, dynamic color});
}

class LinearProgressIndicator extends Widget {
  const LinearProgressIndicator(
      {super.key, double? value, dynamic color, dynamic backgroundColor});
}

class OverflowBar extends Widget {
  const OverflowBar({super.key, List<Widget>? children, double? spacing});
}

class BackButton extends Widget {
  const BackButton({super.key, VoidCallback? onPressed});
}

class CloseButton extends Widget {
  const CloseButton({super.key, VoidCallback? onPressed});
}

class Placeholder extends Widget {
  const Placeholder(
      {super.key,
      dynamic color,
      double? strokeWidth,
      double? fallbackWidth,
      double? fallbackHeight});
}

class InteractiveViewer extends Widget {
  const InteractiveViewer(
      {super.key,
      required Widget child,
      double? minScale,
      double? maxScale,
      bool? panEnabled,
      bool? scaleEnabled});
}

// ── ThemeData extras ────────────────────────────────────────────────────

class ThemeData {
  ThemeData({
    dynamic primarySwatch,
    dynamic primaryColor,
    dynamic colorScheme,
    dynamic textTheme,
    dynamic brightness,
    dynamic scaffoldBackgroundColor,
    dynamic appBarTheme,
    dynamic elevatedButtonTheme,
    dynamic inputDecorationTheme,
    dynamic useMaterial3,
  });
  dynamic get colorScheme => _ColorScheme();
  dynamic get textTheme => _TextTheme();
  dynamic get primaryColor => null;
  dynamic get scaffoldBackgroundColor => null;
  dynamic get brightness => null;
}

class _ColorScheme {
  dynamic get primary => null;
  dynamic get secondary => null;
  dynamic get surface => null;
  dynamic get error => null;
  dynamic get onPrimary => null;
  dynamic get onSecondary => null;
  dynamic get onSurface => null;
  dynamic get onError => null;
  dynamic get background => null;
}

class _TextTheme {
  dynamic get displayLarge => null;
  dynamic get displayMedium => null;
  dynamic get displaySmall => null;
  dynamic get headlineLarge => null;
  dynamic get headlineMedium => null;
  dynamic get headlineSmall => null;
  dynamic get titleLarge => null;
  dynamic get titleMedium => null;
  dynamic get titleSmall => null;
  dynamic get bodyLarge => null;
  dynamic get bodyMedium => null;
  dynamic get bodySmall => null;
  dynamic get labelLarge => null;
  dynamic get labelMedium => null;
  dynamic get labelSmall => null;
}

class ColorScheme {
  const ColorScheme({
    required dynamic primary,
    required dynamic secondary,
    required dynamic surface,
    required dynamic error,
    required dynamic onPrimary,
    required dynamic onSecondary,
    required dynamic onSurface,
    required dynamic onError,
    required dynamic brightness,
  });
  const ColorScheme.dark({dynamic primary, dynamic secondary});
  const ColorScheme.light({dynamic primary, dynamic secondary});
  dynamic get primary => null;
  dynamic get secondary => null;
  dynamic get surface => null;
  dynamic get error => null;
}

// ── Completer ───────────────────────────────────────────────────────────

class Completer<T> {
  Completer();
  Future<T> get future => throw UnimplementedError();
  void complete([T? value]) {}
  void completeError(Object error, [StackTrace? stackTrace]) {}
  bool get isCompleted => false;
}

// ── Additional common stubs ─────────────────────────────────────────────

dynamic riskyOperation() => null;
void loadData() {}
void updateUI() {}
void navigateTo(String route) {}
void showSuccess(String message) {}
void showLoading() {}
void hideLoading() {}
void emit(dynamic state) {}
void on<T>(dynamic handler) {}
void ever(dynamic obs, dynamic callback) {}
dynamic initFlutter() => null;

class OrderService {
  Future<Order> getOrder(int id) async => Order();
}

class IUserService {
  Future<dynamic> getUser(dynamic id) async => null;
}

class UserViewModel {
  dynamic get user => null;
  void loadUser(dynamic id) {}
}

class ServiceA {
  void doWork() {}
}

class DataProvider {
  dynamic getData() => null;
}

class Product {
  String name = '';
  double price = 0;
  int quantity = 0;
}

class Chat {
  String message = '';
  String sender = '';
  DateTime timestamp = DateTime.now();
}

class Circle {
  Circle({double? radius});
  double get radius => 0;
  double get area => 0;
}

class Success<T> {
  Success(T data);
  T get data => throw UnimplementedError();
}

class CountryEnum {
  static const us = CountryEnum._();
  static const uk = CountryEnum._();
  static const ca = CountryEnum._();
  const CountryEnum._();
}

class RandomAccessFile {
  Future<void> close() async {}
  Future<List<int>> read(int count) async => [];
  Future<RandomAccessFile> writeFrom(List<int> buffer) async => this;
}

// ── Widget layout extras ────────────────────────────────────────────────

class Offstage extends Widget {
  const Offstage({super.key, bool offstage = true, Widget? child});
}

class SizedOverflowBox extends Widget {
  const SizedOverflowBox({super.key, required dynamic size, Widget? child});
}

class OverflowBox extends Widget {
  const OverflowBox(
      {super.key, double? maxWidth, double? maxHeight, Widget? child});
}

class AspectRatio extends Widget {
  const AspectRatio({super.key, required double aspectRatio, Widget? child});
}

class FractionallySizedBox extends Widget {
  const FractionallySizedBox(
      {super.key, double? widthFactor, double? heightFactor, Widget? child});
}

class Transform extends Widget {
  const Transform({super.key, required dynamic transform, Widget? child});
  const Transform.rotate({super.key, required double angle, Widget? child});
  const Transform.scale({super.key, required double scale, Widget? child});
  const Transform.translate(
      {super.key, required dynamic offset, Widget? child});
}

class WidgetSpan {
  const WidgetSpan({required Widget child});
}

// ── More missing classes from error analysis ────────────────────────────

class AuthBloc extends Bloc<Object, Object> {
  AuthBloc() : super(Object());
}

class AuthState {}

class MyBloc extends Bloc<Object, Object> {
  MyBloc() : super(Object());
}

class MyState {}

class MyEvent {}

class MyInitial {}

class MyController extends GetxController {}

class MyPage extends StatelessWidget {
  const MyPage({super.key});
  @override
  Widget build(BuildContext context) => Container();
}

class UserNotifier extends ChangeNotifier {}

class AuthService {
  Future<void> login(String email, String password) async {}
  Future<void> logout() async {}
  bool get isAuthenticated => false;
}

class Clock {
  DateTime now() => DateTime.now();
}

class FileReader {
  Future<String> readAsString(String path) async => '';
}

class Search {
  Future<List<dynamic>> search(String query) async => [];
}

class VideoPage extends StatelessWidget {
  const VideoPage({super.key});
  @override
  Widget build(BuildContext context) => Container();
}

class MyForm extends StatelessWidget {
  const MyForm({super.key});
  @override
  Widget build(BuildContext context) => Container();
}

class Gallery extends StatelessWidget {
  const Gallery({super.key});
  @override
  Widget build(BuildContext context) => Container();
}

class Data {
  dynamic value;
  Data([this.value]);
}

class MyRenderObject extends RenderObject {}

class SettingsState {}

class UpdateEvent {}

class OrderState {}

class OrderNotifier {}

class OrderProcessor {}

class PostgresUserRepository extends UserRepository {}

class CancelToken {
  void cancel([String? reason]) {}
  bool get isCancelled => false;
}

// ============================================================================
// Asset loading
// ============================================================================

class AssetBundle {
  Future<String> loadString(String key) async => '';
}

final AssetBundle rootBundle = AssetBundle();
