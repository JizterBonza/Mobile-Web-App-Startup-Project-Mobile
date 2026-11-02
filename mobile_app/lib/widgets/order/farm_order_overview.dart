import 'package:flutter/material.dart';

import '../../constants/constants.dart';
import '../../models/customer_order_entry.dart';
import '../../models/farm_checkout.dart';
import '../../utils/status_utils.dart';
import 'farm_order_widgets.dart';

class FarmOrderOverview extends StatelessWidget {
  const FarmOrderOverview({super.key, required this.order});

  final FarmOrder order;

  @override
  Widget build(BuildContext context) {
    final view = FarmOrderView(order);
    final status = normalizeOrderStatus(view.status);
    final statusColor = getStatusColor(status);
    final paymentColor = order.closed && !order.depositPaid
        ? AppColors.textSecondary
        : order.depositPaid
            ? AppColors.success
            : AppColors.warning;
    final orderedAt = order.data['ordered_at'] ?? order.data['created_at'];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.brandPrimary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.agriculture_outlined,
                  color: AppColors.brandPrimary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Farm info',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(view.farmName.isEmpty ? 'Farm order' : view.farmName,
                      style: const TextStyle(
                          fontSize: 18,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status.isEmpty
                    ? 'Status unavailable'
                    : '${status[0].toUpperCase()}${status.substring(1)}',
                style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: statusColor),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Order number',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(order.code,
              style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          if (orderedAt != null) ...[
            const SizedBox(height: 12),
            const Text('Placed on',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(farmDate(orderedAt),
                style: const TextStyle(
                    fontSize: 13, height: 1.5, color: AppColors.textPrimary)),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderDefault),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Payment info',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 10),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(
                    order.closed && !order.depositPaid
                        ? Icons.lock_outline_rounded
                        : order.depositPaid
                            ? Icons.check_circle_outline_rounded
                            : Icons.schedule_rounded,
                    color: paymentColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(view.paymentLabel,
                        style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: paymentColor)),
                  ),
                ]),
                if (order.data['deposit_due'] != null ||
                    order.data['amount_paid'] != null) ...[
                  const Divider(height: 24),
                  if (order.data['deposit_due'] != null)
                    FarmOrderAmountRow('Required deposit',
                        farmMoney(order.data['deposit_due'])),
                  if (order.data['amount_paid'] != null)
                    FarmOrderAmountRow(
                        'Paid so far', farmMoney(order.data['amount_paid'])),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
