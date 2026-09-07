import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/shared/widgets/primary_button.dart';

void main() {
  testWidgets('PrimaryButton shows label and calls onPressed when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrimaryButton(
            label: 'Эхлэх',
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Эхлэх'), findsOneWidget);
    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('PrimaryButton shows a spinner instead of the label while loading', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrimaryButton(
            label: 'Эхлэх',
            isLoading: true,
            onPressed: () {},
          ),
        ),
      ),
    );

    expect(find.text('Эхлэх'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('PrimaryButton is disabled and unresponsive when onPressed is null', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PrimaryButton(label: 'Эхлэх', onPressed: null),
        ),
      ),
    );

    final ElevatedButton button = tester.widget(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });
}
