import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/app/theme/app_theme.dart';

/// `flutter create`'s default template drops a `test/widget_test.dart` that
/// pumps a `MyApp` counter widget — this project's root widget is
/// `HuvaaltsApp` (`lib/bootstrap.dart`), so that boilerplate never matched
/// anything here and only ever failed to compile.
///
/// `HuvaaltsApp` itself isn't pumped in a plain widget test: its
/// `routerProvider`/`authControllerProvider` chain expects Supabase to
/// already be initialized (see `bootstrap()`), which a widget test never
/// does — every other screen-level test in this suite (e.g.
/// `test/features/onboarding/onboarding_screen_test.dart`) works around
/// this the same way, by pumping just the screen under test inside a
/// minimal `MaterialApp`/`ProviderScope`, not the real app shell. This file
/// keeps to that same boundary: a smoke test for [AppTheme], the one
/// app-wide piece that's safe to exercise without booting Supabase/env.
void main() {
  testWidgets('AppTheme.light() builds a usable Material 3 theme', (tester) async {
    final ThemeData theme = AppTheme.light();
    expect(theme.useMaterial3, isTrue);
    expect(theme.brightness, Brightness.light);

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(body: Text('huvalts')),
      ),
    );

    expect(find.text('huvalts'), findsOneWidget);
  });

  testWidgets('AppTheme.dark() builds a usable Material 3 theme', (tester) async {
    final ThemeData theme = AppTheme.dark();
    expect(theme.useMaterial3, isTrue);
    expect(theme.brightness, Brightness.dark);
  });
}
