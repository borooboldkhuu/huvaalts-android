import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/app/localization/app_localizations.dart';

void main() {
  group('AppLocalizations', () {
    test('mn locale returns Mongolian copy', () {
      final l10n = AppLocalizations(const Locale('mn'));
      expect(l10n.onboardingCta, 'Эхлэх');
      expect(l10n.languageMongolian, 'Монгол');
    });

    test('en locale returns English copy', () {
      final l10n = AppLocalizations(const Locale('en'));
      expect(l10n.onboardingCta, 'Get started');
      expect(l10n.languageEnglish, 'English');
    });

    test('a locale other than mn falls back to English rather than crashing', () {
      // In practice the framework only ever constructs this for a locale
      // that passed `delegate.isSupported` (mn or en), but the class itself
      // should degrade gracefully rather than throw for anything else.
      final l10n = AppLocalizations(const Locale('fr'));
      expect(l10n.onboardingCta, 'Get started');
    });

    test('parameterized strings interpolate correctly in both locales', () {
      final mn = AppLocalizations(const Locale('mn'));
      final en = AppLocalizations(const Locale('en'));
      expect(mn.authOtpSubtitle('+97699112233'), contains('+97699112233'));
      expect(en.authOtpSubtitle('+97699112233'), contains('+97699112233'));
      expect(mn.authOtpResendIn(45), contains('45'));
      expect(en.authOtpResendIn(45), contains('45'));
    });

    test('delegate reports mn and en as supported, others as not', () {
      expect(AppLocalizations.delegate.isSupported(const Locale('mn')), isTrue);
      expect(AppLocalizations.delegate.isSupported(const Locale('en')), isTrue);
      expect(AppLocalizations.delegate.isSupported(const Locale('fr')), isFalse);
    });
  });
}
