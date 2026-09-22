import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agriconnect/widgets/delivery_accepted_dialog.dart';

void main() {
  testWidgets('matches the delivery accepted confirmation mockup', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DeliveryAcceptedDialog()),
      ),
    );

    expect(find.text('Delivery Accepted'), findsOneWidget);
    expect(
      find.text(
        'You\u2019ve accepted this delivery. Please proceed to the pickup point.',
      ),
      findsOneWidget,
    );

    final check = tester.widget<Icon>(find.byIcon(Icons.check_rounded));
    expect(check.color, Colors.white);
    expect(check.size, 30);

    final circleFinder = find
        .ancestor(
          of: find.byIcon(Icons.check_rounded),
          matching: find.byType(Container),
        )
        .first;
    final circle = tester.widget<Container>(circleFinder);
    final decoration = circle.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xFF27A867));
    expect(decoration.shape, BoxShape.circle);

    expect(tester.getSize(circleFinder), const Size(48, 48));
  });

  testWidgets('show helper presents a dismissible dark-overlay dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => DeliveryAcceptedDialog.show(context),
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();

    expect(find.text('Delivery Accepted'), findsOneWidget);
    final barrier = tester.widget<ModalBarrier>(find.byType(ModalBarrier).last);
    expect(barrier.dismissible, isTrue);
    expect(barrier.color, const Color(0xA6000000));

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.text('Delivery Accepted'), findsNothing);
  });

  testWidgets('automatically dismisses after two seconds', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => DeliveryAcceptedDialog.show(context),
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();
    expect(find.text('Delivery Accepted'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Delivery Accepted'), findsNothing);
  });
}
