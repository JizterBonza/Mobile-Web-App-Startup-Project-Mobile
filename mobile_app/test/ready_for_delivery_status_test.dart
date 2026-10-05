import 'package:agriconnect/constants/constants.dart';
import 'package:agriconnect/main.dart';
import 'package:agriconnect/utils/status_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('App color palette', () {
    test('uses the restored navy brand colors', () {
      expect(AppColors.brandPrimary, const Color(0xFF1A2A5C));
      expect(AppColors.brandPrimaryDark, const Color(0xFF0F1B40));
      expect(AppColors.brandPrimaryLight, const Color(0xFF2C3E80));
    });

    test('keeps success green and in-progress statuses blue', () {
      expect(AppColors.success, const Color(0xFF2E7D32));
      expect(AppColors.statusReadyForDelivery, AppColors.success);
      expect(AppColors.statusReadyForPickup, AppColors.success);
      expect(AppColors.statusDelivered, AppColors.success);
      expect(AppColors.statusProcessing, AppColors.brandPrimaryLight);
      expect(AppColors.statusInTransit, AppColors.brandPrimaryLight);
    });

    testWidgets('applies navy to the global Material theme', (tester) async {
      await tester.pumpWidget(const MyApp());

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.theme?.colorScheme.primary, AppColors.brandPrimary);
      expect(app.theme?.appBarTheme.backgroundColor, AppColors.brandPrimary);
      expect(
        app.theme?.bottomNavigationBarTheme.selectedItemColor,
        AppColors.brandPrimary,
      );
      expect(
        app.theme?.elevatedButtonTheme.style?.backgroundColor?.resolve(
          <WidgetState>{},
        ),
        AppColors.brandPrimary,
      );
    });
  });

  group('Ready for Delivery status', () {
    test('normalizes spaced and hyphenated API descriptions', () {
      expect(isReadyForDeliveryStatus('Ready for Delivery'), isTrue);
      expect(isReadyForDeliveryStatus('ready-for-delivery'), isTrue);
      expect(isReadyForDeliveryStatus('  READY  FOR  DELIVERY  '), isTrue);
    });

    test('does not treat obsolete or unrelated statuses as ready', () {
      expect(isReadyForDeliveryStatus('Ready for Pickup'), isFalse);
      expect(isReadyForDeliveryStatus('Pending'), isFalse);
      expect(isReadyForDeliveryStatus('Processing'), isFalse);
      expect(isReadyForDeliveryStatus('In Transit'), isFalse);
    });

    test('uses consistent formatting and status colors', () {
      expect(
        OrderStatusColors.formatStatus('ready-for-delivery'),
        'Ready for Delivery',
      );
      expect(
        OrderStatusColors.getColor('ready for delivery'),
        AppColors.statusReadyForDelivery,
      );
      expect(
        OrderStatusColors.getColor('ready-for-delivery'),
        AppColors.statusReadyForDelivery,
      );
    });
  });
}
