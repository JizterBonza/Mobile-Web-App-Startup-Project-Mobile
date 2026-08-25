import 'package:agriconnect/widgets/rider_statistics_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpGrid(
    WidgetTester tester, {
    required double width,
    VoidCallback? onEarningsTap,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: RiderStatisticsGrid(
              stats: const {
                'active': 2,
                'pending': 3,
                'incoming': 7,
                'completed': 4,
                'earnings': 160,
              },
              onEarningsTap: onEarningsTap,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders the mockup labels, values, and SVG assets',
      (tester) async {
    await pumpGrid(tester, width: 390);

    expect(find.text('Today’s Summary'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Incoming'), findsOneWidget);
    expect(find.text('Complete'), findsOneWidget);
    expect(find.text('Earnings'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.byType(SvgPicture), findsNWidgets(4));

    for (final asset in const [
      'assets/icons/motor.svg',
      'assets/icons/incoming.svg',
      'assets/icons/complete.svg',
      'assets/icons/earn.svg',
    ]) {
      expect(find.byKey(ValueKey(asset)), findsOneWidget);
    }
  });

  testWidgets('keeps 100 pixel cards without overflow on phone widths',
      (tester) async {
    for (final width in const [320.0, 390.0]) {
      await pumpGrid(tester, width: width);

      for (final label in const [
        'Active',
        'Incoming',
        'Complete',
        'Earnings',
      ]) {
        final size = tester.getSize(
          find.byKey(ValueKey('summary-card-$label')),
        );
        expect(size.height, 100);
      }

      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('opens earnings when its card is tapped', (tester) async {
    var tapped = false;
    await pumpGrid(
      tester,
      width: 390,
      onEarningsTap: () => tapped = true,
    );

    await tester.tap(find.byKey(const ValueKey('summary-card-Earnings')));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
