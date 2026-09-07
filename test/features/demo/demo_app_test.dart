import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/features/demo/demo_app.dart';

void main() {
  testWidgets('offline entry, search and favorites work without backend setup', (tester) async {
    await tester.pumpWidget(const DemoApp());
    await tester.ensureVisible(find.byKey(const Key('enter-demo')));
    await tester.tap(find.byKey(const Key('enter-demo')));
    await tester.pumpAndSettle();
    expect(find.text('Canon EOS R6 камер'), findsOneWidget);
    await tester.tap(find.byKey(const Key('save-1')));
    await tester.enterText(find.byKey(const Key('demo-search')), 'байхгүй-зүйл');
    await tester.pumpAndSettle();
    expect(find.text('Canon EOS R6 камер'), findsNothing);
    expect(find.text('Тохирох зар олдсонгүй. Өөр үгээр хайгаарай.'), findsOneWidget);
    await tester.tap(find.text('Хадгалсан'));
    await tester.pumpAndSettle();
    expect(find.text('Canon EOS R6 камер'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('demo booking calculates total, cancels and resets on exit', (tester) async {
    await tester.pumpWidget(const DemoApp());
    await tester.ensureVisible(find.byKey(const Key('enter-demo')));
    await tester.tap(find.byKey(const Key('enter-demo')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Canon EOS R6 камер'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -450));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('days-plus')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('days-plus')));
    await tester.pump();
    expect(find.text('Нийт: 170,000 ₮'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('demo-book')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('demo-book')));
    await tester.pumpAndSettle();
    expect(find.text('2 хоног • 170,000 ₮'), findsOneWidget);
    await tester.tap(find.text('Демо захиалга цуцлах'));
    await tester.pumpAndSettle();
    expect(find.text('Одоогоор захиалга алга. Нүүр хэсгээс зар сонгон туршиж үзээрэй.'), findsOneWidget);
    await tester.tap(find.text('Гарах'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('enter-demo')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
