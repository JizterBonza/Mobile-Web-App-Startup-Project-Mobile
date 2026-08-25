import 'package:agriconnect/constants/constants.dart';
import 'package:agriconnect/utils/status_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
