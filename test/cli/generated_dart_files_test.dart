/// Pins the shared codegen/locale predicate that the cross-file analyzers and the
/// health/size scanners all delegate to, so the single source of truth cannot drift
/// or silently narrow.
import 'package:saropa_lints/src/cli/generated_dart_files.dart';
import 'package:test/test.dart';

void main() {
  group('isGeneratedDartPath', () {
    test('matches every known codegen suffix', () {
      const generated = [
        'lib/model.g.dart',
        'lib/model.freezed.dart',
        'test/widget.mocks.dart',
        'lib/router.gr.dart',
        'lib/di.config.dart',
        'lib/api.chopper.dart',
        'lib/assets.gen.dart',
        'lib/database.drift.dart',
        'lib/proto/msg.pb.dart',
        'lib/proto/msg.pbenum.dart',
        'lib/proto/msg.pbgrpc.dart',
        'lib/proto/msg.pbjson.dart',
        'lib/proto/msg.pbserver.dart',
      ];
      for (final path in generated) {
        expect(isGeneratedDartPath(path), isTrue, reason: path);
      }
    });

    test('matches a `generated` path segment but not a mere substring', () {
      expect(isGeneratedDartPath('lib/generated/api.dart'), isTrue);
      expect(isGeneratedDartPath('lib/feature/generated/x.dart'), isTrue);
      // Whole-segment only: a hand-written file that merely contains the word is kept.
      expect(isGeneratedDartPath('lib/auto_generated_notes.dart'), isFalse);
    });

    test('matches gen-l10n tables under any l10n directory, incl. wrappers', () {
      expect(isGeneratedDartPath('lib/l10n/app_localizations.dart'), isTrue);
      expect(isGeneratedDartPath('lib/l10n/app_localizations_fr.dart'), isTrue);
      expect(isGeneratedDartPath('lib/l10n/intl_messages.dart'), isTrue);
      expect(
        isGeneratedDartPath('lib/service/l10n/remote_app_localizations.dart'),
        isTrue,
      );
    });

    test('keeps hand-written code and is case-insensitive', () {
      expect(isGeneratedDartPath('lib/widgets/button.dart'), isFalse);
      expect(isGeneratedDartPath('lib/main.dart'), isFalse);
      // An `app_localizations`-named helper OUTSIDE an l10n dir is not swept up.
      expect(isGeneratedDartPath('lib/utils/app_localizations_helper.dart'), isFalse);
      // Suffix match ignores case.
      expect(isGeneratedDartPath('lib/MODEL.G.DART'), isTrue);
    });
  });
}
