import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:huvalts/app/localization/app_localizations.dart';
import 'package:huvalts/app/router/route_paths.dart';
import 'package:huvalts/features/onboarding/presentation/screens/onboarding_screen.dart';

/// This widget test only exercises the onboarding slide UI itself (paging,
/// copy, CTA label change on the last slide) against a minimal router
/// shell — it does not boot Supabase/env, which real navigation past
/// onboarding requires. Full navigation is covered by the (not yet
/// written) integration test planned for Phase 12.
void main() {
  Widget buildTestApp() {
    final router = GoRouter(
      initialLocation: RoutePaths.onboarding,
      routes: [
        GoRoute(
          path: RoutePaths.onboarding,
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: RoutePaths.authPhone,
          builder: (context, state) => const Scaffold(body: Text('phone entry')),
        ),
      ],
    );
    return ProviderScope(
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('mn'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );
  }

  testWidgets('shows the first onboarding slide and an Үргэлжлүүлэх CTA', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('Хэрэгтэй зүйлээ түрээслэ.'), findsOneWidget);
    expect(find.text('Үргэлжлүүлэх'), findsOneWidget);
  });

  testWidgets('the last slide shows Эхлэх instead of Үргэлжлүүлэх', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    // Advance through all three slides.
    await tester.tap(find.text('Үргэлжлүүлэх'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Үргэлжлүүлэх'));
    await tester.pumpAndSettle();

    expect(find.text('Баталгаатай хүмүүсээс найдвартай түрээслэ.'), findsOneWidget);
    expect(find.text('Эхлэх'), findsOneWidget);
  });
}
