import 'package:flutter/material.dart';

class DeliveryAcceptanceConfirmationDialog extends StatelessWidget {
  const DeliveryAcceptanceConfirmationDialog({
    super.key,
    required this.orderLabel,
    required this.pickupStoreCount,
  });

  final String orderLabel;
  final int pickupStoreCount;

  static Future<bool> show(
    BuildContext context, {
    required String orderLabel,
    required int pickupStoreCount,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0xA6000000),
      builder: (_) => DeliveryAcceptanceConfirmationDialog(
        orderLabel: orderLabel,
        pickupStoreCount: pickupStoreCount,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final storeLabel = pickupStoreCount == 1 ? 'store' : 'stores';

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        key: const ValueKey('delivery-acceptance-confirmation-card'),
        width: 300,
        child: Material(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0A8CFF),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.local_shipping_rounded,
                    color: Colors.white,
                    size: 27,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Accept Delivery',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Accept $orderLabel? You will pick up from '
                  '$pickupStoreCount $storeLabel.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF4A4A4A),
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: OutlinedButton(
                          key: const ValueKey(
                            'delivery-acceptance-cancel-button',
                          ),
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF4A4A4A),
                            side: const BorderSide(color: Color(0xFFD5D5D5)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: ElevatedButton(
                          key: const ValueKey(
                            'delivery-acceptance-accept-button',
                          ),
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: const Color(0xFF0A8CFF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          child: const Text(
                            'Accept',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
