import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/config/app_config.dart';
import 'app/config/env.dart';
import 'app/localization/app_localizations.dart';
import 'app/localization/locale_controller.dart';
import 'app/router/app_router.dart';
import 'app/theme/app_theme.dart';
import 'core/providers/core_providers.dart';

/// Shared startup path for every build flavor (`main.dart` /
/// `main_staging.dart` / `main_production.dart`). Each flavor entry point
/// just calls `bootstrap(AppEnvironment.x)` — keeping the actual wiring in
/// one place avoids the three files drifting apart.
Future<void> bootstrap(AppEnvironment environment) async {
  WidgetsFlutterBinding.ensureInitialized();

  // No async load step needed — `Env`'s values are `--dart-define-from-file`
  // compile-time constants now (see env.dart's header comment), already
  // baked into this build before it ever ran.
  final AppConfig config = AppConfig.fromEnv(environment);
  config.assertNotPlaceholderInProduction();

  // Firebase (Crashlytics/Analytics/Messaging) requires
  // `flutterfire configure` to generate `firebase_options.dart` plus the
  // platform config files (google-services.json / GoogleService-Info.plist)
  // before it can initialize — neither exists yet in this scaffold (spec
  // section 46 — those are per-app-store-listing artifacts). Guarded so
  // Phase 0/1 development isn't blocked on that setup step; wire the real
  // `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`
  // call here once configured, and let Crashlytics-uncaught-error hooks
  // replace this debugPrint.
  // ignore: avoid_print
  print(
    '[bootstrap] Firebase not yet configured — run `flutterfire configure` '
    'then wire Firebase.initializeApp() here before shipping.',
  );

  await Supabase.initialize(
    url: config.supabaseUrl,
    // `anonKey` was renamed `publishableKey` in a recent supabase_flutter
    // 2.x patch (Supabase's anon/publishable API key rename) — the value
    // itself is unchanged, still `config.supabaseAnonKey`.
    publishableKey: config.supabaseAnonKey,
  );

  final SharedPreferences prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const HuvaaltsApp(),
    ),
  );
}

class HuvaaltsApp extends ConsumerWidget {
  const HuvaaltsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final Locale locale = ref.watch(localeControllerProvider);

    return MaterialApp.router(
      title: 'ХУВААЛЦ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
