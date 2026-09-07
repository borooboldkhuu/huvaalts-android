import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/app/localization/app_localizations.dart';
import 'package:huvalts/app/localization/locale_controller.dart';
import 'package:huvalts/core/providers/core_providers.dart';
import 'package:huvalts/features/settings/presentation/screens/language_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    // LocalCacheService reads through SharedPreferences — use the
    // in-memory test implementation rather than a real device.
    SharedPreferences.setMockInitialValues({});
  });

  Future<ProviderContainer> buildContainer() async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  Widget wrap(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('mn'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const LanguageSettingsScreen(),
      ),
    );
  }

  testWidgets('defaults to Mongolian selected, shows both language options', (tester) async {
    final container = await buildContainer();
    await tester.pumpWidget(wrap(container));
    await tester.pumpAndSettle();

    expect(find.text('Монгол'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(container.read(localeControllerProvider).languageCode, 'mn');
  });

  testWidgets('tapping English switches the locale and persists it', (tester) async {
    final container = await buildContainer();
    await tester.pumpWidget(wrap(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(container.read(localeControllerProvider).languageCode, 'en');
    expect(container.read(localCacheProvider).locale, 'en');
  });
}
