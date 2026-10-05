import 'package:agriconnect/constants/constants.dart';
import 'package:agriconnect/provider/badge_provider.dart';
import 'package:agriconnect/utils/customer_nav.dart';
import 'package:agriconnect/widgets/notification_bell_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  Future<void> pumpBell(
    WidgetTester tester, {
    String? badgeCount,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: NotificationBellIcon(
              color: Colors.grey,
              badgeCount: badgeCount,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows the customer bell dimensions without an empty badge',
      (tester) async {
    await pumpBell(tester);

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('notification-bell'))),
      const Size(24, 24),
    );
    expect(
      find.byKey(const ValueKey('notification-count-badge')),
      findsNothing,
    );
  });

  testWidgets('shows the amber rounded customer count badge', (tester) async {
    await pumpBell(tester, badgeCount: '12');

    expect(
      tester.getSize(
        find.byKey(const ValueKey('notification-bell-with-badge')),
      ),
      const Size(32, 28),
    );
    expect(find.text('12'), findsOneWidget);

    final badge = tester.widget<Container>(
      find.byKey(const ValueKey('notification-count-badge')),
    );
    final decoration = badge.decoration! as BoxDecoration;
    expect(decoration.color, AppColors.accentAmber);
    expect(decoration.borderRadius, BorderRadius.circular(4));

    final text = tester.widget<Text>(find.text('12'));
    expect(text.style?.color, Colors.black);
    expect(text.style?.fontSize, 10);
    expect(text.style?.fontWeight, FontWeight.bold);
  });

  testWidgets('uses navy for the active customer navigation item',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => BadgeProvider(),
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              bottomNavigationBar: buildCustomerBottomNavigationBar(
                context: context,
                currentIndex: CustomerNavIndex.home,
                isGuest: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final navigation = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    expect(navigation.selectedItemColor, AppColors.brandPrimary);
    expect(navigation.currentIndex, CustomerNavIndex.home);
  });
}
