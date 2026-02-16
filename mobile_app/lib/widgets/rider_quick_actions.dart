import 'package:flutter/material.dart';
import 'quick_action_button.dart';

class RiderQuickActions extends StatelessWidget {
  final VoidCallback? onPickupMap;
  final VoidCallback? onDeliveryMap;

  const RiderQuickActions({
    super.key,
    this.onPickupMap,
    this.onDeliveryMap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[900],
          ),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            if (onPickupMap != null)
              Expanded(
                child: QuickActionButton(
                  label: 'For Pickup',
                  icon: Icons.store_mall_directory_outlined,
                  color: Colors.teal,
                  onTap: onPickupMap!,
                ),
              )
            else
              Expanded(child: SizedBox()),
            SizedBox(width: 12),
            if (onDeliveryMap != null)
              Expanded(
                child: QuickActionButton(
                  label: 'For Delivery',
                  icon: Icons.delivery_dining,
                  color: Colors.indigo,
                  onTap: onDeliveryMap!,
                ),
              )
            else
              Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }
}
