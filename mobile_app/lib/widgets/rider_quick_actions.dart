import 'package:flutter/material.dart';
import '../constants/constants.dart';
import 'quick_action_button.dart';

class RiderQuickActions extends StatelessWidget {
  final VoidCallback? onPickupMap;
  final VoidCallback? onDeliveryMap;
  final VoidCallback? onAllDeliveries;
  final VoidCallback? onEarnings;

  const RiderQuickActions({
    super.key,
    this.onPickupMap,
    this.onDeliveryMap,
    this.onAllDeliveries,
    this.onEarnings,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.grey[900],
          ),
        ),
        SizedBox(height: 12),
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
              ),
            SizedBox(width: 10),
            if (onDeliveryMap != null)
              Expanded(
                child: QuickActionButton(
                  label: 'For Delivery',
                  icon: Icons.delivery_dining,
                  color: Colors.indigo,
                  onTap: onDeliveryMap!,
                ),
              ),
          ],
        ),
        SizedBox(height: 10),
        Row(
          children: [
            if (onAllDeliveries != null)
              Expanded(
                child: QuickActionButton(
                  label: 'All Deliveries',
                  icon: Icons.list_alt_outlined,
                  color: Colors.blueGrey,
                  onTap: onAllDeliveries!,
                ),
              ),
            SizedBox(width: 10),
            if (onEarnings != null)
              Expanded(
                child: QuickActionButton(
                  label: 'Earnings',
                  icon: Icons.account_balance_wallet_outlined,
                  color: AppColors.mediumGreen,
                  onTap: onEarnings!,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
