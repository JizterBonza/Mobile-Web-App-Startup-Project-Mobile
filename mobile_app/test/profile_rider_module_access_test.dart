import 'package:agriconnect/provider/address_provider.dart';
import 'package:agriconnect/screens/common/myOrderScreen.dart';
import 'package:agriconnect/screens/common/profileScreen.dart';
import 'package:agriconnect/screens/customer/shippingAddressScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const unavailableMessage = 'This module is not available for rider accounts.';

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'user_type': 'rider',
      'user_name': 'Test Rider',
    });
  });

  Future<void> pumpProfile(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AddressProvider(),
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('blocks riders from opening My Orders', (tester) async {
    await pumpProfile(tester);

    await tester.tap(find.text('My Orders'));
    await tester.pump();

    expect(find.text(unavailableMessage), findsOneWidget);
    expect(find.byType(MyOrderScreen), findsNothing);
  });

  testWidgets('blocks riders from opening Shipping Address', (tester) async {
    await pumpProfile(tester);

    await tester.tap(find.text('Shipping Address'));
    await tester.pump();

    expect(find.text(unavailableMessage), findsOneWidget);
    expect(find.byType(ShippingAddressScreen), findsNothing);
  });
}
