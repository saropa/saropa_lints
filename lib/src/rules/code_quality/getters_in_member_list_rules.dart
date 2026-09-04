// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';

import '../../analyzer_compat.dart';
import '../../saropa_lint_rule.dart';

// ============================================================================
// GETTER MEMBER-ORDERING RULE
// ============================================================================
//
// A class/mixin/extension/enum/extension-type body implicitly splits into a
// "what does this object look like" section (fields, getters, setters) and a
// "what does it do" section (constructors, methods). When a getter is
// declared after a regular method, a reader scanning for the object's data
// shape has to re-scan the whole body instead of stopping at the first
// method. This rule flags that specific case: a getter that trails at least
// one method, when there was an earlier field/getter/setter it could have
// been grouped with instead.
// ============================================================================

/// Flags a getter (`Type get name => ...`) declared after a regular method
/// in the same class, mixin, extension, enum, or extension-type body, when
/// the body already has an earlier field, getter, or setter the getter
/// could have been grouped with instead.
///
/// Since: v15.4.0 | Updated: v15.4.0 | Rule version: v2
///
/// Only plain (non-`@override`) getters are flagged. Overriding getters are
/// exempt: they are frequently kept next to other overridden members for
/// interface-conformance readability rather than grouped with the class's
/// own fields, and flagging them would fight that equally valid convention.
/// A getter with nothing earlier to group with (no prior field, getter, or
/// setter in the body) is never flagged — there is nothing to reorder
/// against. Constructors are not treated as a "behavior member" that trips
/// this rule: their position relative to getters is a separate convention
/// this rule does not enforce.
///
/// `static` members are ignored entirely — neither flagged nor counted as
/// the earlier property member or the preceding behavior member. The rule's
/// rationale is about an *instance's* "data shape vs behavior" reading
/// order; a static-only utility holder (`static double get piSquared` after
/// `static double square(...)`) has no instance data shape to scan for, so
/// applying the ordering convention there was a false positive.
///
/// **BAD:**
/// ```dart
/// class Order {
///   final List<Item> items;
///
///   Order(this.items);
///
///   void addItem(Item item) {
///     items.add(item);
///   }
///
///   double get total => items.fold(0, (sum, i) => sum + i.price);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class Order {
///   final List<Item> items;
///
///   double get total => items.fold(0, (sum, i) => sum + i.price);
///
///   Order(this.items);
///
///   void addItem(Item item) {
///     items.add(item);
///   }
/// }
/// ```
class GettersInMemberListRule extends SaropaLintRule {
  GettersInMemberListRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'convention', 'readability'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  String get exampleBad =>
      'void addItem() {}\n\ndouble get total => 0; // after a method';

  @override
  String get exampleGood => 'double get total => 0;\n\nvoid addItem() {}';

  static const LintCode _code = LintCode(
    'getters_in_member_list',
    '[getters_in_member_list] This getter is declared after at least one '
        'regular method, even though the class already has an earlier '
        'field, getter, or setter it could have been grouped with instead. '
        'Scattering getters among unrelated methods forces a reader who '
        'wants to know "what does this object look like" to scan the whole '
        'class body instead of stopping at the first method; keeping '
        'getters grouped with fields near the top keeps the data contract '
        'scannable independent of when each member was added. {v2}',
    correctionMessage:
        'Move this getter up next to the class\'s field declarations and '
        'other getters/setters, before the first method.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // `.bodyMembers` (lib/src/analyzer_compat.dart) rather than `.members`
    // directly — ClassDeclaration/MixinDeclaration/ExtensionDeclaration no
    // longer expose `.members` in analyzer 12 (members moved under
    // `.body`), and older pinned analyzer versions have their own quirks
    // the shim absorbs.
    context.addClassDeclaration(
      (ClassDeclaration node) => _checkMembers(reporter, node.bodyMembers),
    );
    context.addMixinDeclaration(
      (MixinDeclaration node) => _checkMembers(reporter, node.bodyMembers),
    );
    context.addExtensionDeclaration(
      (ExtensionDeclaration node) => _checkMembers(reporter, node.bodyMembers),
    );
    // Enhanced enums (Dart 2.17+) can declare fields, getters, setters, and
    // methods exactly like a class body, so a getter scattered among enum
    // methods is just as much a readability gap as in a class. `bodyMembers`
    // is the same analyzer-12-compat shim used above (analyzer_compat.dart).
    context.addEnumDeclaration(
      (EnumDeclaration node) => _checkMembers(reporter, node.bodyMembers),
    );
    // Extension types share the same member-list shape as classes/enums, so
    // the same grouping convention applies to their bodies too.
    context.addExtensionTypeDeclaration(
      (ExtensionTypeDeclaration node) =>
          _checkMembers(reporter, node.bodyMembers),
    );
  }

  /// Walks one class/mixin/extension/enum/extension-type body's member list
  /// in source order, flagging any plain getter that appears after a
  /// regular method AND has an earlier field/getter/setter it could have
  /// been grouped with.
  ///
  /// `static` members are skipped outright (see the class doc): they are
  /// neither reported nor allowed to set either tracking flag, so a
  /// static-only utility holder is silent and a static helper sitting in the
  /// middle of an instance body cannot manufacture a violation for the
  /// instance getter that follows it.
  void _checkMembers(
    SaropaDiagnosticReporter reporter,
    List<ClassMember> members,
  ) {
    // True once a field, getter, or setter has been seen — the "data shape"
    // section a later getter could have joined instead of trailing a
    // method.
    var hasEarlierPropertyMember = false;
    // True once a regular (non-getter/setter) method has been seen — the
    // "behavior" section that should come after the data shape section.
    var sawBehaviorMember = false;

    for (final member in members) {
      if (member is FieldDeclaration) {
        // A `static` field is class-level storage, not part of the
        // instance's data shape, so it must not seed
        // `hasEarlierPropertyMember` — otherwise a lone `static const`
        // (the only kind of field an `extension` can even declare) would
        // make every later getter reportable.
        if (member.isStatic) continue;
        hasEarlierPropertyMember = true;
        continue;
      }

      // Constructors are deliberately NOT treated as a "behavior member"
      // here. Policy: a constructor is construction/init plumbing, not
      // "what does this object do" behavior — it is idiomatic Dart to put
      // the constructor first (before fields/getters) or immediately after
      // fields, and either placement is orthogonal to whether getters stay
      // grouped with fields. Only a *method* declaration marks the start of
      // the behavior section that this rule checks getters against.
      if (member is ConstructorDeclaration) continue;

      if (member is! MethodDeclaration) continue;

      // Static methods/getters/setters are outside the instance data-shape
      // vs behavior split this rule enforces. Skipping them before any flag
      // is read or written means an idiomatic static-only utility class
      // (`static double get piSquared` trailing `static double square(...)`)
      // is never flagged — the previously documented false positive.
      if (member.isStatic) continue;

      if (member.isGetter) {
        // Overriding getters are exempt (edge case: they are often kept
        // near other overrides rather than the field block). This is a
        // syntactic name check, not a resolved-element check against
        // `dart:core`'s `@override` — intentional: this rule never resolves
        // types (it's a pure member-ordering walk), and no one defines a
        // competing annotation literally named `override`.
        final isOverride = member.metadata.any(
          (Annotation a) => a.name.name == 'override',
        );
        if (sawBehaviorMember && hasEarlierPropertyMember && !isOverride) {
          reporter.atNode(member);
        }
        hasEarlierPropertyMember = true;
        continue;
      }

      if (member.isSetter) {
        hasEarlierPropertyMember = true;
        continue;
      }

      // Any other method declaration (regular method or operator) marks
      // the start/continuation of the behavior section.
      sawBehaviorMember = true;
    }
  }
}
