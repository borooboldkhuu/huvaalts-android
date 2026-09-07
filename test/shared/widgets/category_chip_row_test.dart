import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/app/localization/app_localizations.dart';
import 'package:huvalts/core/constants/asset_categories.dart';
import 'package:huvalts/shared/widgets/category_chip_row.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      locale: const Locale('mn'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    );
  }

  testWidgets('renders one chip per AssetCategory including "Бүгд"', (tester) async {
    await tester.pumpWidget(wrap(CategoryChipRow(selected: null, onSelected: (_) {})));
    await tester.pumpAndSettle();

    expect(find.text('Бүгд'), findsOneWidget);
    expect(find.text('Камер'), findsOneWidget);
    expect(find.text('Дрон'), findsOneWidget);
    expect(find.byType(CategoryAvatar), findsNWidgets(AssetCategory.values.length));
  });

  testWidgets('tapping a category chip reports that category, tapping "Бүгд" reports null', (tester) async {
    AssetCategory? reported = AssetCategory.tools;
    bool tapped = false;

    await tester.pumpWidget(
      wrap(
        CategoryChipRow(
          selected: null,
          onSelected: (category) {
            reported = category;
            tapped = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Камер'));
    expect(tapped, isTrue);
    expect(reported, AssetCategory.camera);

    await tester.tap(find.text('Бүгд'));
    expect(reported, isNull);
  });
}
