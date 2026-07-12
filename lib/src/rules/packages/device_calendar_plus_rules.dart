// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// device_calendar_plus package lint rules.
///
/// device_calendar_plus is a from-scratch rewrite of device_calendar, not a
/// fork: `DeviceCalendar.instance` singleton (not `DeviceCalendarPlugin`),
/// exception-based errors (not `Result<T>`), no `timezone` package dependency
/// (not `TZDateTime`). Rules here target its actual API and must not be
/// merged with `device_calendar_rules.dart` — the two packages share no
/// method or class names.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../import_utils.dart';
import '../../saropa_lint_rule.dart';

/// device_calendar_plus operations that require calendar access.
const Set<String> _dataOps = <String>{
  'createEvent',
  'updateEvent',
  'updateRecurring',
  'deleteEvent',
  'deleteRecurring',
  'createCalendar',
  'updateCalendar',
  'deleteCalendar',
  'listCalendars',
  'listEvents',
  'listSources',
  'getEvent',
};

/// The two explicit permission gate methods on `DeviceCalendar`.
const Set<String> _permissionMethods = <String>{
  'hasPermissions',
  'requestPermissions',
};

/// Methods that accept a start/end date pair (or single `start`) plus an
/// `isAllDay` flag, keyed to the named date arguments each one exposes.
const Map<String, Set<String>> _dateArgsByMethod = <String, Set<String>>{
  'createEvent': {'startDate', 'endDate'},
  'updateEvent': {'startDate', 'endDate'},
  'showCreateEventModal': {'startDate', 'endDate'},
  'updateRecurring': {'start'},
};

/// `updateEvent` named arguments that represent an actual field change (every
/// named argument except `eventId`, the target selector).
const Set<String> _updateEventChangeArgs = <String>{
  'title',
  'startDate',
  'endDate',
  'description',
  'location',
  'url',
  'isAllDay',
  'timeZone',
  'availability',
  'reminders',
};

bool _isTestFilePath(String path) {
  final String normalized = path.replaceAll('\\', '/');
  return normalized.endsWith('_test.dart') || normalized.contains('/test/');
}

Expression? _namedArg(ArgumentList args, String name) {
  for (final Expression arg in args.arguments) {
    if (arg is NamedExpression && arg.name.label.name == name) {
      return arg.expression;
    }
  }
  return null;
}

/// The `DeviceCalendar` class name. Every data-op / permission-method /
/// autoPermissions match below requires the receiver to resolve to this
/// type — without it, an unrelated same-named method or field elsewhere in
/// the file (e.g. a hand-rolled `EventFactory.createEvent(...)`, or a local
/// `bool autoPermissions` flag) would count too.
const String _deviceCalendarType = 'DeviceCalendar';

/// True when [node]'s receiver resolves to the `DeviceCalendar` singleton
/// type — covers both `DeviceCalendar.instance.xxx()` and a variable holding
/// that instance (`final dc = DeviceCalendar.instance; dc.xxx()`).
bool _isDeviceCalendarCall(MethodInvocation node) {
  return node.realTarget?.staticType?.element?.name == _deviceCalendarType;
}

/// True when [expr] produces a UTC-normalized `DateTime`, which all-day
/// events must not use: `.toUtc()`, `DateTime.utc(...)`,
/// `DateTime.from{Milli,Micro}secondsSinceEpoch(..., isUtc: true)`, or
/// `DateTime.parse(...)` of a `Z`-suffixed (UTC) ISO-8601 string literal.
bool _isUtcTaintedExpression(Expression expr) {
  if (expr is MethodInvocation) {
    if (expr.methodName.name == 'toUtc') return true;
    final Expression? target = expr.realTarget;
    if (expr.methodName.name == 'parse' &&
        target is SimpleIdentifier &&
        target.name == 'DateTime') {
      final List<Expression> args = expr.argumentList.arguments;
      final Expression? first = args.isEmpty ? null : args.first;
      final String? value = first is StringLiteral
          ? first.stringValue
          : null;
      return value != null && value.trim().toUpperCase().endsWith('Z');
    }
    return false;
  }
  if (expr is InstanceCreationExpression &&
      expr.constructorName.type.name.lexeme == 'DateTime') {
    final String? ctorName = expr.constructorName.name?.name;
    if (ctorName == 'utc') return true;
    if (ctorName == 'fromMillisecondsSinceEpoch' ||
        ctorName == 'fromMicrosecondsSinceEpoch') {
      final Expression? isUtcValue = _namedArg(expr.argumentList, 'isUtc');
      return isUtcValue is BooleanLiteral && isUtcValue.value;
    }
  }
  return false;
}

/// Collects `DeviceCalendar`-receiver method invocations and
/// `DeviceCalendar`-receiver `autoPermissions` access, in one traversal, for
/// the file-wide permission scan.
class _InvocationAndAutoPermissionsScan extends RecursiveAstVisitor<void> {
  final List<MethodInvocation> invocations = <MethodInvocation>[];
  bool hasAutoPermissionsAccess = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    invocations.add(node);
    super.visitMethodInvocation(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (node.propertyName.name == 'autoPermissions' &&
        node.realTarget.staticType?.element?.name == _deviceCalendarType) {
      hasAutoPermissionsAccess = true;
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.identifier.name == 'autoPermissions' &&
        node.prefix.staticType?.element?.name == _deviceCalendarType) {
      hasAutoPermissionsAccess = true;
    }
    super.visitPrefixedIdentifier(node);
  }
}

// =============================================================================
// device_calendar_plus_missing_permission_check
// =============================================================================

/// Flags device_calendar_plus data operations in a file with no permission
/// check.
///
/// Since: Unreleased | Rule version: v1
///
/// Every create/update/delete/list operation requires calendar access. A
/// file that never calls `hasPermissions()` / `requestPermissions()` and
/// never configures `autoPermissions` has no pre-flight check, so a
/// first-run user with no calendar access sees the call fail with a
/// permission-denied `DeviceCalendarException` instead of a clear prompt.
///
/// **BAD:**
/// ```dart
/// await DeviceCalendar.instance.createEvent(title: 'x', startDate: a, endDate: b);
/// ```
///
/// **GOOD:**
/// ```dart
/// final status = await DeviceCalendar.instance.requestPermissions();
/// if (status == CalendarPermissionStatus.granted) {
///   await DeviceCalendar.instance.createEvent(title: 'x', startDate: a, endDate: b);
/// }
/// ```
class DeviceCalendarPlusMissingPermissionCheckRule extends SaropaLintRule {
  DeviceCalendarPlusMissingPermissionCheckRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => _dataOps;

  static const LintCode _code = LintCode(
    'device_calendar_plus_missing_permission_check',
    '[device_calendar_plus_missing_permission_check] This file calls device_calendar_plus data operations but never calls hasPermissions(), requestPermissions(), or configures autoPermissions. The plugin requires calendar access for every create/update/delete/list operation; without a permission check or auto-permission mode, a first-run user with no calendar access sees the call fail with a permission-denied DeviceCalendarException instead of a clear pre-flight prompt. Reported at INFO: the permission flow may legitimately live in a helper file. {v1}',
    correctionMessage:
        'Call hasPermissions() / requestPermissions() (or set DeviceCalendar.instance.autoPermissions) before create/update/delete/list operations.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCompilationUnit((CompilationUnit unit) {
      if (!fileImportsPackage(unit, PackageImports.deviceCalendarPlus)) {
        return;
      }
      if (_isTestFilePath(context.filePath)) return;

      final _InvocationAndAutoPermissionsScan scan =
          _InvocationAndAutoPermissionsScan();
      unit.accept(scan);

      final List<MethodInvocation> dataCalls = scan.invocations
          .where(
            (MethodInvocation inv) =>
                _dataOps.contains(inv.methodName.name) &&
                _isDeviceCalendarCall(inv),
          )
          .toList();
      if (dataCalls.isEmpty) return;

      final bool hasPermissionCall = scan.invocations.any(
        (MethodInvocation inv) =>
            _permissionMethods.contains(inv.methodName.name) &&
            _isDeviceCalendarCall(inv),
      );
      if (hasPermissionCall) return;

      // autoPermissions prompts automatically, so a file that configures it
      // needs no explicit hasPermissions/requestPermissions call.
      if (scan.hasAutoPermissionsAccess) return;

      // Report once, at the first data operation, to avoid file-wide noise.
      reporter.atNode(dataCalls.first.methodName);
    });
  }
}

// =============================================================================
// device_calendar_plus_all_day_event_utc_conversion
// =============================================================================

/// Flags an `isAllDay: true` event whose date argument is UTC-converted.
///
/// Since: Unreleased | Rule version: v1
///
/// The package docs distinguish timed events (safe to convert to UTC freely)
/// from all-day events, which float as calendar dates: a birthday on
/// January 15 must stay January 15 in every time zone. Converting the date
/// to UTC first can shift it across the day boundary for users west of UTC,
/// silently moving the event to the wrong day.
///
/// **BAD:**
/// ```dart
/// DeviceCalendar.instance.createEvent(
///   title: 'Birthday',
///   isAllDay: true,
///   startDate: DateTime(2026, 1, 15).toUtc(),
///   endDate: DateTime(2026, 1, 16).toUtc(),
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// DeviceCalendar.instance.createEvent(
///   title: 'Birthday',
///   isAllDay: true,
///   startDate: DateTime(2026, 1, 15),
///   endDate: DateTime(2026, 1, 16),
/// );
/// ```
class DeviceCalendarPlusAllDayEventUtcConversionRule extends SaropaLintRule {
  DeviceCalendarPlusAllDayEventUtcConversionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'isAllDay'};

  static const LintCode _code = LintCode(
    'device_calendar_plus_all_day_event_utc_conversion',
    '[device_calendar_plus_all_day_event_utc_conversion] An all-day device_calendar_plus event (isAllDay: true) is given a UTC-converted date via DateTime.utc(...) or .toUtc(). The package docs distinguish timed events (safe to convert to UTC) from all-day events, which float as calendar dates rather than instants; converting the date to UTC first can shift it across the day boundary for users west of UTC, silently moving the event to the wrong day. {v1}',
    correctionMessage:
        "Pass the local wall-clock DateTime (no .toUtc() / DateTime.utc(...)) for an all-day event's date fields; only convert to UTC for timed events.",
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    if (_isTestFilePath(context.filePath)) return;

    context.addMethodInvocation((MethodInvocation node) {
      final Set<String>? dateArgs = _dateArgsByMethod[node.methodName.name];
      if (dateArgs == null) return;
      if (!fileImportsPackage(node, PackageImports.deviceCalendarPlus)) {
        return;
      }
      if (!_isDeviceCalendarCall(node)) return;

      final Expression? isAllDayValue = _namedArg(
        node.argumentList,
        'isAllDay',
      );
      if (isAllDayValue is! BooleanLiteral || !isAllDayValue.value) return;

      for (final String argName in dateArgs) {
        final Expression? value = _namedArg(node.argumentList, argName);
        if (value != null && _isUtcTaintedExpression(value)) {
          reporter.atNode(value);
        }
      }
    });
  }
}

// =============================================================================
// device_calendar_plus_empty_update_event
// =============================================================================

/// Flags an `updateEvent(eventId: ...)` call with no field to change.
///
/// Since: Unreleased | Rule version: v1
///
/// The package documents this shape as a harmless no-op rather than a
/// thrown error, so nothing on the calendar changes and nothing warns the
/// caller. The most likely explanation is a forgotten field, not an
/// intentional call.
///
/// **BAD:**
/// ```dart
/// await DeviceCalendar.instance.updateEvent(eventId: id); // nothing to change
/// ```
///
/// **GOOD:**
/// ```dart
/// await DeviceCalendar.instance.updateEvent(eventId: id, title: 'New title');
/// ```
class DeviceCalendarPlusEmptyUpdateEventRule extends SaropaLintRule {
  DeviceCalendarPlusEmptyUpdateEventRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'updateEvent'};

  static const LintCode _code = LintCode(
    'device_calendar_plus_empty_update_event',
    '[device_calendar_plus_empty_update_event] updateEvent is called with only eventId and no field to change. The package documents this shape as a harmless no-op rather than a thrown error, so nothing on the calendar changes and nothing warns the caller — the likely explanation is a forgotten field, not an intentional call. {v1}',
    correctionMessage:
        'Pass at least one field to change (title, startDate/endDate, description, location, url, isAllDay, timeZone, availability, or reminders), or remove the call.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    if (_isTestFilePath(context.filePath)) return;

    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'updateEvent') return;
      if (!fileImportsPackage(node, PackageImports.deviceCalendarPlus)) {
        return;
      }
      if (!_isDeviceCalendarCall(node)) return;

      bool hasEventId = false;
      bool hasChange = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is! NamedExpression) continue;
        final String name = arg.name.label.name;
        if (name == 'eventId') {
          hasEventId = true;
        } else if (_updateEventChangeArgs.contains(name)) {
          hasChange = true;
        }
      }
      if (!hasEventId || hasChange) return;

      reporter.atNode(node);
    });
  }
}
